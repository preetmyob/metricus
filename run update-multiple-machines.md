# Metricus Multi-Machine Update Deployment

## Overview
Metricus service update deployment across multiple EC2 instances in ap-southeast-2 region with remote update script execution and status monitoring for development hosting infrastructure.

## Deployment Summary
* **Total Instances**: 6 EC2 instances (1 initial + 5 additional)
* **Version Upgrade**: 0.5.0 → 1.1.0
* **Region**: ap-southeast-2
* **Instance Type**: All t3.medium instances in running state
* **Success Rate**: 100% (all instances updated successfully)

## Commands Executed

### Initial Update
```bash
./scripts/update-metricus-remote.sh i-021ef46178a035ed0
```
* Command ID: ad0c663c-5847-48e8-8d60-633a2b460369
* Status: Success

### Status Monitoring
```bash
./scripts/check-update-status.sh
```
* Monitored progress: InProgress → Success status transitions

### Instance Discovery
```bash
aws ec2 describe-instances --region ap-southeast-2 --filters "Name=tag:Name,Values=*development-hosting*" "Name=instance-state-name,Values=running"
```
* Found 5 additional instances for batch deployment

### Batch Updates
Deployed to 5 instances with command IDs:
* c1554017-5c4e-41f0-a419-bde6f07ad96b
* 1ce82530-ffe3-44e5-9371-b258e0ed8d7e
* 58f90e90-7a23-49cd-a40d-251c1a029e16
* 8024492b-8a30-4faa-9177-b6c6987acf0d
* 15c64a44-0ae7-463c-9a0d-6b8c06c71994

## Scripts Used

### update-metricus-remote.sh
Remote deployment script that uses AWS SSM to execute PowerShell commands on EC2 instances.

**Purpose**: Sends update commands to multiple EC2 instances via SSM
**Location**: `/scripts/update-metricus-remote.sh`
**Usage**: `./update-metricus-remote.sh <instance-id1> [instance-id2] ...`

**Key Features**:
* Downloads update script and Metricus 1.1.0 zip from S3 bucket `development-enterprise-site-management`
* Executes PowerShell update script remotely via SSM
* Cleans up temporary files after execution
* Returns command ID for status monitoring
* Supports multiple instance IDs in single command

**S3 Dependencies**:
* `Update-metricus.ps1` - PowerShell update script
* `metricus-1.1.0.zip` - New version package

### check-update-status.sh
Status monitoring script for SSM command execution.

**Purpose**: Monitor progress and results of remote update commands
**Location**: `/scripts/check-update-status.sh`
**Usage**: `./check-update-status.sh <command-id> <instance-id>`

**Output Information**:
* Status (InProgress/Success/Failed)
* Response Code (0 = success)
* Start/End timestamps
* Execution duration
* Standard output content
* Error messages (if any)

### update-metricus.ps1
PowerShell script executed on target instances (downloaded from S3).

**Purpose**: Performs actual Metricus service update on Windows instances
**Key Operations**:
1. Service shutdown
2. Backup creation (service files and config)
3. Version extraction from zip
4. Configuration migration
5. Service restart
6. Verification

## Technical Details

### Update Process
1. Service shutdown
2. Backup creation
3. Version extraction
4. Configuration migration
5. Service restart

### Backup Files Created
* `backup-metricus-0.5.0-[timestamp].zip`
* `config-backup-metricus-0.5.0-[timestamp].zip`

### Performance Metrics
* **Update Duration**: 59 seconds to 1 minute 36 seconds
* **Response Code**: 0 (success) for all instances
* **Completion**: Staggered timing but consistent success

## Key Insights
* All 6 EC2 instances successfully updated without errors
* Automated backup and rollback capability maintained during updates
* Regional deployment coordination required specifying ap-southeast-2 instead of default us-east-1
* Batch deployment monitoring showed staggered completion times but consistent success rates
* Service continuity maintained through proper shutdown/startup procedures during updates

## Date
Generated: 2025-09-01T04:30:24.439Z
