function Import-IntuneDeviceHealthScript {
<#
.SYNOPSIS
Imports Intune Device Health Scripts from subfolders, creating new scripts only.
.DESCRIPTION
Reads subfolders from a specified path. Each subfolder should contain a JSON metadata
file and a detection PowerShell script. A remediation script is optional. If a script
 with the same displayName already exists, the folder is skipped and a warning is emitted.

The JSON file's detectionScriptContent and remediationScriptContent fields are
overwritten with the Base64-encoded contents of the .ps1 files if present.

Supports -WhatIf for dry-run validation without hitting the Graph API.
.PARAMETER FolderPath
Mandatory. The path to the folder containing subfolders of Intune Device Health Scripts.
.NOTES
Requires:
- Microsoft.Graph PowerShell SDK (Invoke-MgGraphRequest, Get-MgContext)
- DeviceManagementConfiguration.ReadWrite.All
.EXAMPLE
Import-IntuneDeviceHealthScript -FolderPath "C:\temp\HealthScripts"
.EXAMPLE
Import-IntuneDeviceHealthScript -FolderPath "C:\temp\HealthScripts" -WhatIf
.LINK
https://learn.microsoft.com/en-us/powershell/microsoftgraph/overview
#>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FolderPath
    )

    # Ensure Graph connection exists
    if (-not (Get-MgContext)) {
        Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
        return
    }

    if (-not (Test-Path $FolderPath)) {
        Write-Error "Folder path '$FolderPath' does not exist."
        return
    }

    $SubFolders = Get-ChildItem -Path $FolderPath -Directory

    if (-not $SubFolders) {
        Write-Error "No subfolders found in folder: $FolderPath"
        return
    }

    # Top-level properties that are tenant-specific and must be stripped before import
    $PropertiesToRemove = @(
        "id",
        "createdDateTime",
        "lastModifiedDateTime",
        "version",
        "supportsScopeTags",
        "supportedScopeTags",
        "highestAvailableVersion",
        "isGlobalScript"
    )

    $Results = @()

    foreach ($SubFolder in $SubFolders) {

        Write-Host "Processing: $($SubFolder.Name)"

        # Find JSON metadata file
        $JsonFile = Get-ChildItem -Path $SubFolder.FullName -Filter *.json -File | Select-Object -First 1

        if (-not $JsonFile) {
            Write-Warning "No JSON file found in '$($SubFolder.Name)'. Skipping."
            continue
        }

        # Parse JSON — strip @odata.context and @odata.nextLink from raw string first
        try {
            $RawJson = Get-Content -Path $JsonFile.FullName -Raw
            $RawJson = $RawJson -replace '"[^"]*@odata\.context"\s*:\s*"[^"]*",?\s*', ''
            $RawJson = $RawJson -replace '"[^"]*@odata\.nextLink"\s*:\s*"[^"]*",?\s*', ''
            $JsonObject = $RawJson | ConvertFrom-Json
        }
        catch {
            Write-Warning "Could not parse '$($JsonFile.Name)' as JSON. Skipping."
            continue
        }

        # Strip read-only / tenant-specific top-level properties
        foreach ($Prop in $PropertiesToRemove) {
            $JsonObject.PSObject.Properties.Remove($Prop)
        }

        $DisplayName = $JsonObject.displayName

        if (-not $DisplayName) {
            Write-Warning "JSON file '$($JsonFile.Name)' does not contain a 'displayName' property. Skipping."
            continue
        }

        # Find detection script — mandatory
        $DetectionScript = Get-ChildItem -Path $SubFolder.FullName -Filter "DetectionScript.ps1" -File | Select-Object -First 1

        if (-not $DetectionScript) {
            Write-Warning "No 'DetectionScript.ps1' found in '$($SubFolder.Name)'. Skipping."
            continue
        }

        # Encode detection script as Base64
        $DetectionBytes = [System.IO.File]::ReadAllBytes($DetectionScript.FullName)
        $DetectionBase64 = [Convert]::ToBase64String($DetectionBytes)
        $JsonObject.detectionScriptContent = $DetectionBase64

        # Find remediation script — optional
        $RemediationScript = Get-ChildItem -Path $SubFolder.FullName -Filter "RemediationScript.ps1" -File | Select-Object -First 1

        if ($RemediationScript) {
            $RemediationBytes = [System.IO.File]::ReadAllBytes($RemediationScript.FullName)
            $RemediationBase64 = [Convert]::ToBase64String($RemediationBytes)
            $JsonObject.remediationScriptContent = $RemediationBase64
        }
        else {
            $JsonObject.remediationScriptContent = ""
        }

        # Check whether the script already exists (skip rather than overwrite)
        try {
            $FilterUri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts?`$filter=displayName eq '$DisplayName'"
            $Existing = Invoke-MgGraphRequest -Method GET -Uri $FilterUri -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to query existing scripts for '$DisplayName'. Skipping. Error: $_"
            continue
        }

        if ($Existing.value.Count -gt 0) {
            Write-Warning "Script '$DisplayName' already exists in tenant. Skipping."
            continue
        }

        $Body = $JsonObject | ConvertTo-Json -Depth 20

        if ($PSCmdlet.ShouldProcess($DisplayName, "Create Intune Device Health Script")) {

            try {
                $Created = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts" -Body $Body -ContentType "application/json" -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to create script '$DisplayName'. Skipping. Error: $_"
                continue
            }

            $ScriptId = $Created.id

            if (-not $ScriptId) {
                Write-Warning "Script '$DisplayName' was submitted but no ID was returned. Skipping."
                continue
            }

            Write-Host "Script created: $DisplayName [$ScriptId]"

            $Results += [PSCustomObject]@{
                Name         = $DisplayName
                Id           = $ScriptId
                SourceFolder = $SubFolder.Name
            }
        }
        else {
            # -WhatIf path — report what would happen without calling the API
            Write-Host "WhatIf: Would create script '$DisplayName' from '$($SubFolder.Name)'"
        }
    }

    return $Results
}