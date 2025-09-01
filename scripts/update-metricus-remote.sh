#!/bin/bash

# Update Metricus service via SSM
REGION="ap-southeast-2"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <instance-id1> [instance-id2] [instance-id3] ..."
    echo "Example: $0 i-021ef46178a035ed0 i-0123456789abcdef0"
    exit 1
fi

INSTANCE_IDS="$*"
echo "Sending Metricus update command to instances: $INSTANCE_IDS"

COMMAND_ID=$(aws ssm send-command \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=[
    "Import-Module AWSPowerShell",
    "$scriptPath = \"$env:TEMP\\update-metricus.ps1\"",
    "$zipPath = \"$env:TEMP\\metricus-1.1.0.zip\"",
    "Copy-S3Object -BucketName development-enterprise-site-management -Key Update-metricus.ps1 -LocalFile $scriptPath",
    "Copy-S3Object -BucketName development-enterprise-site-management -Key metricus-1.1.0.zip -LocalFile $zipPath",
    "& $scriptPath -ZipPath $zipPath",
    "Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue",
    "Remove-Item $zipPath -Force -ErrorAction SilentlyContinue"
  ]' \
  --timeout-seconds 3600 \
  --comment "Update Metricus service with PowerShell S3 download" \
  --instance-ids $INSTANCE_IDS \
  --region "$REGION" \
  --query 'Command.CommandId' \
  --output text)

echo "Command sent with ID: $COMMAND_ID"
echo "Use ./check-update-status.sh $COMMAND_ID <instance-id> to monitor progress"
