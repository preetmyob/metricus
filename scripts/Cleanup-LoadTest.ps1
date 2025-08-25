#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Cleanup helper for Metricus load test resources.

.DESCRIPTION
    Simple script to clean up resources left by Run-MetricusLoadTest.ps1
    Compatible with PowerShell 5.1 and PowerShell 7.x

.PARAMETER SiteName
    Name of the test website to remove. Default: MetricusLoadTest

.PARAMETER Port
    Port of the test website. Default: 8080

.EXAMPLE
    .\Cleanup-LoadTest.ps1
    
.EXAMPLE
    .\Cleanup-LoadTest.ps1 -SiteName "MyTestSite" -Port 9090

.NOTES
    Compatible with PowerShell 5.1+ and PowerShell 7.x
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SiteName = "MetricusLoadTest",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 8080
)

# Just call the main script with cleanup-only parameters
& "$PSScriptRoot\Run-MetricusLoadTest.ps1" -SiteName $SiteName -Port $Port -LoadDurationMinutes 0 -Force
