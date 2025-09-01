# Metricus Update Script - Implementation Checklist

## Rules
- Don't implement any step without confirmation of manual test and instruction to proceed
- Don't run the code locally as we're on a mac and the testing has to be done, manually, on windows
- support only powershell 5
- make the script command be verbose and log steps well so the manual testing is easy to verify
- have try catches to ensure that we always end up in same safe state
- the existing implementation must be preserved and not removed 

## Steps

### Step 1: Verify Metricus service exists and get current version path
- [ ] Find running Metricus service
- [ ] Extract current version path from service startup path
- [ ] Validate current version folder exists

### Step 2: Validate local zip file exists and is accessible
- [ ] Check zip file exists at specified path
- [ ] Verify file is readable
- [ ] Basic zip integrity check

### Step 3: Check admin privileges for service operations
- [ ] Verify script is running as administrator
- [ ] Confirm service management permissions

### Step 4: Ensure install path is writable
- [ ] Test write permissions to install directory
- [ ] Verify sufficient disk space

### Step 5: Stop service gracefully with timeout
- [ ] Stop Metricus service with proper timeout
- [ ] Verify service has stopped completely

### Step 6: Uninstall service using current executable but keep the code
- [ ] Run uninstall command from current metricus.exe
- [ ] Verify service is removed from system
- [ ] Confirm current installation files remain intact

### Step 7: Verify service is fully removed from system but the current software is still there
- [ ] Check service no longer exists in service manager
- [ ] Confirm current version folder and files are preserved

### Step 8: Create timestamped backup of current version folder
- [ ] Create backup directory with timestamp
- [ ] Copy current version folder to backup location
- [ ] Zip the backup directory and remove the backup directory


### Step 9: Preserve configs separately for rollback capability
- [ ] Create separate config backup
- [ ] Verify all config.json files are backed up
- [ ] Zip the backup directory and remove the backup directory

### Step 10: Verify zip integrity and extract to final location
- [ ] Extract zip to temporary location for validation
- [ ] Verify expected metricus folder structure exists
- [ ] Check for required files (metricus.exe, plugins, etc.)
- [ ] Clean up temporary validation extraction
- [ ] Extract zip to "c:\metricus\<name of extracted folder>" location
- [ ] Verify extraction completed successfully in final location

### Step 12-13: Validate new executable exists and is functional
- [ ] Confirm metricus.exe exists in new version that was copied over
- [ ] Find all config.json files in current version
- [ ] Copy each config to corresponding location in new version
- [ ] Maintain directory structure exactly

### Step 14-15: Preserve directory structure exactly and Validate configs copied successfully
- [ ] Verify all plugin directories exist in new version
- [ ] Confirm all config files were copied
- [ ] Verify file contents match original

### Step 16-17: Install new service from new executable and start
- [ ] Run install command from new metricus.exe
- [ ] Verify service is registered in system
- [ ] Start the new Metricus service
- [ ] Confirm service status is "Running"

### Step 18-19: Remove temp files on success
- [ ] Clean up temporary extraction directories
- [ ] Remove any temporary files created during process

### Step 20: On failure: restore backup, reinstall old service
- [ ] Restore original version from backup
- [ ] Reinstall original service
- [ ] Verify rollback completed successfully

### Step 21: Log all operations for troubleshooting
- [ ] Comprehensive logging throughout process
- [ ] Clear timestamps and operation details

### Step 22: Provide clear success/failure status
- [ ] Final status message with version information
- [ ] Exit codes for automation integration with SSM execute powershell documents
