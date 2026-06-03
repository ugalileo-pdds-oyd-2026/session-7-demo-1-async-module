import json
import os
import time
from datetime import datetime, timezone, timedelta

import boto3


def handler(event, context):
    if 'requestContext' in event and 'http' in event.get('requestContext', {}):
        return handle_http(event)
    if event.get('Records') and event['Records'][0].get('eventSource') == 'aws:sqs':
        handle_sqs(event)
        return
    handle_scheduler()


def handle_http(event):
    method = event['requestContext']['http']['method']
    path = event.get('rawPath', '')

    if method == 'GET' and path == '/health':
        return _resp(200, {'status': 'ok', 'compute': 'lambda'})
    if method != 'POST' or path != '/jobs':
        return _resp(404, {'error': 'not found'})

    try:
        body = json.loads(event.get('body') or '{}')
    except (json.JSONDecodeError, TypeError):
        return _resp(400, {'error': 'invalid JSON body'})

    filename = body.get('filename')
    if not filename:
        return _resp(400, {'error': 'body must include filename'})

    job_id = f"job-{int(time.time() * 1000)}"
    queue_url = os.environ.get('QUEUE_URL', '')

    if not queue_url:
        print(f"QUEUE_URL not set — processing {filename} synchronously")
        _write_result(job_id, filename, 'processed-sync')
        return _resp(200, {'job_id': job_id, 'status': 'completed', 'message': 'processed synchronously'})

    boto3.client('sqs').send_message(
        QueueUrl=queue_url,
        MessageBody=json.dumps({'job_id': job_id, 'filename': filename}),
    )
    return _resp(202, {'job_id': job_id, 'status': 'queued', 'message': 'job accepted for processing'})


def handle_sqs(event):
    for record in event['Records']:
        msg = json.loads(record['body'])
        job_id, filename = msg['job_id'], msg['filename']
        print(f"processing job {job_id} (file: {filename})")
        _write_result(job_id, filename, 'processed')
        print(f"job {job_id} complete")


def handle_scheduler():
    bucket = os.environ.get('RESULTS_BUCKET', '')
    if not bucket:
        print('RESULTS_BUCKET not set — skipping cleanup')
        return

    days = int(os.environ.get('CLEANUP_DAYS', '7'))
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    print(f"cleanup: removing results older than {cutoff.date()} ({days} days)")

    s3 = boto3.client('s3')
    paginator = s3.get_paginator('list_objects_v2')
    deleted = 0

    for page in paginator.paginate(Bucket=bucket, Prefix='results/'):
        to_delete = [
            {'Key': obj['Key']}
            for obj in page.get('Contents', [])
            if obj['LastModified'] < cutoff
        ]
        if to_delete:
            s3.delete_objects(Bucket=bucket, Delete={'Objects': to_delete})
            deleted += len(to_delete)

    print(f"cleanup complete: deleted {deleted} objects")


def _write_result(job_id, filename, status):
    bucket = os.environ.get('RESULTS_BUCKET')
    if not bucket:
        raise ValueError('RESULTS_BUCKET not set')
    boto3.client('s3').put_object(
        Bucket=bucket,
        Key=f'results/{job_id}.json',
        Body=json.dumps({
            'job_id': job_id,
            'filename': filename,
            'status': status,
            'done_at': datetime.now(timezone.utc).isoformat(),
        }).encode(),
        ContentType='application/json',
    )


def _resp(code, body):
    return {
        'statusCode': code,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps(body),
    }
