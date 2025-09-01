#!/bin/bash

# Check SSM command status
COMMAND_ID=${1:-""}
INSTANCE_ID=${2:-""}
REGION="ap-southeast-2"

if [ -z "$COMMAND_ID" ] || [ -z "$INSTANCE_ID" ]; then
    echo "Usage: $0 <command-id> <instance-id>"
    echo "Example: $0 f11a47ef-1368-4bf9-9209-25ceb31e9a32 i-021ef46178a035ed0"
    exit 1
fi

echo "Checking status for command: $COMMAND_ID"
echo "Instance: $INSTANCE_ID"
echo "----------------------------------------"

aws ssm get-command-invocation \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --region "$REGION" \
  --query '{
    Status: Status,
    ResponseCode: ResponseCode,
    StartTime: ExecutionStartDateTime,
    EndTime: ExecutionEndDateTime,
    Duration: ExecutionElapsedTime,
    Output: StandardOutputContent,
    Error: StandardErrorContent
  }' \
  --output table
