# PowerShell 5.1 and 7.x Compatibility

## Overview

The Metricus load test scripts have been enhanced for full compatibility with both PowerShell 5.1 (Windows PowerShell) and PowerShell 7.x (PowerShell Core).

## Key Compatibility Improvements

### 1. **PowerShell Version Detection**
```powershell
$psVersion = $PSVersionTable.PSVersion
Write-Info "PowerShell version: $($psVersion.Major).$($psVersion.Minor)"
```

### 2. **IIS Detection**
- **PowerShell 5.1**: Uses `Get-WindowsOptionalFeature` (Windows-specific)
- **PowerShell 7+**: Uses `Get-Service -Name W3SVC` (cross-platform compatible)

### 3. **WebAdministration Module Loading**
- **PowerShell 5.1**: Standard import with `-SkipEditionCheck`
- **PowerShell 7+**: Uses Windows PowerShell compatibility session with enhanced error handling

### 4. **IIS Drive Provider**
- **Issue**: PowerShell 7 may not properly map the `IIS:` drive through compatibility session
- **Solution**: Fallback to `Set-WebConfigurationProperty` cmdlets when `IIS:` drive access fails

### 5. **HTTP Client Compatibility**
```powershell
function Invoke-CompatibleWebRequest {
    # Handles SSL/TLS differences between versions
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    return Invoke-WebRequest @requestParams
}
```

### 6. **Port Availability Checking**
- **PowerShell 5.1**: Uses `Get-NetTCPConnection`
- **PowerShell 7+**: Tries `Get-NetTCPConnection`, falls back to `netstat` if needed

### 7. **Automatic Port Selection**
- If the default port (8080) is in use, automatically finds the next available port
- Prevents test failures due to port conflicts

## Batch File Enhancements

The batch files now automatically detect and use the best available PowerShell version:

```batch
REM Try PowerShell 7 first (pwsh), then fall back to PowerShell 5.1 (powershell)
where pwsh >nul 2>nul
if %ERRORLEVEL% == 0 (
    echo Using PowerShell 7...
    pwsh.exe -ExecutionPolicy Bypass -File "%~dp0Run-MetricusLoadTest.ps1"
) else (
    echo Using PowerShell 5.1...
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0Run-MetricusLoadTest.ps1"
)
```

## Error Handling Improvements

### WebAdministration Module Issues
```powershell
# Enhanced error handling for PowerShell 7 compatibility session
try {
    Import-Module WebAdministration -Force -ErrorAction Stop
    # Verify IIS drive is available
    if (-not (Get-PSDrive -Name IIS -ErrorAction SilentlyContinue)) {
        # Force re-import to establish the drive
        Remove-Module WebAdministration -Force -ErrorAction SilentlyContinue
        Import-Module WebAdministration -Force -ErrorAction Stop
    }
}
```

### IIS Configuration Fallback
```powershell
try {
    # Try standard IIS: drive approach
    Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "managedRuntimeVersion" -Value "v4.0"
}
catch {
    # Fallback to Set-WebConfigurationProperty for PowerShell 7
    Set-WebConfigurationProperty -Filter "/system.applicationHost/applicationPools/add[@name='$AppPoolName']" -Name "managedRuntimeVersion" -Value "v4.0"
}
```

## Testing Results

### PowerShell 5.1 (Windows PowerShell)
- ✅ Full native support
- ✅ All Windows-specific cmdlets work directly
- ✅ IIS: drive provider works natively

### PowerShell 7.x (PowerShell Core)
- ✅ WebAdministration module loads via compatibility session
- ✅ Automatic fallback for IIS configuration when drive provider fails
- ✅ Enhanced HTTP client with proper SSL/TLS handling
- ✅ Cross-platform port checking with netstat fallback

## Known Limitations

1. **WebAdministration Warning**: PowerShell 7 shows a warning about using WinPSCompatSession - this is expected and harmless
2. **Performance**: PowerShell 7 compatibility session may be slightly slower for IIS operations
3. **Drive Provider**: Some advanced IIS: drive operations may require fallback methods in PowerShell 7

## Recommendations

### For Development/Testing
- Use PowerShell 7 for modern features and cross-platform compatibility
- The scripts handle all compatibility issues automatically

### For Production Deployment
- Either PowerShell version works reliably
- PowerShell 5.1 may have slightly better performance for IIS operations
- PowerShell 7 provides better error handling and modern features

## Troubleshooting

### "Cannot find drive. A drive with the name 'IIS' does not exist"
- **Cause**: PowerShell 7 compatibility session issue
- **Solution**: Script automatically falls back to `Set-WebConfigurationProperty` cmdlets
- **Status**: Fixed in current version

### "Module WebAdministration is loaded in Windows PowerShell using WinPSCompatSession"
- **Cause**: Expected behavior in PowerShell 7
- **Solution**: This is a warning, not an error - functionality works correctly
- **Status**: Normal operation

### Port Conflicts
- **Cause**: Default port 8080 already in use
- **Solution**: Script automatically finds next available port
- **Status**: Auto-resolved

## Version Requirements

- **Minimum**: PowerShell 5.1
- **Recommended**: PowerShell 7.4+
- **Tested**: PowerShell 5.1.19041+ and PowerShell 7.4+
- **Platform**: Windows only (due to IIS dependency)
