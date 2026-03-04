function Test-IntuneDeviceConfigurationPolicy {
<#
.SYNOPSIS
Checks if Intune Device Configuration Policies exist in the tenant.
.DESCRIPTION
This function checks if Intune Device Configuration Policies exist in the tenant by comparing them with JSON files in a specified folder.
.PARAMETER InputFilePath
Mandatory. The path to the input JSON file.
.NOTES
Requires:
- Microsoft.Graph PowerShell SDK (e.g., Invoke-MgGraphRequest, Get-MgContext)
- Microsoft.Graph.DeviceManagement permissions to read and write configuration policies.
.EXAMPLE
Test-IntuneDeviceConfigurationPolicy -InputFilePath "C:\temp\IntunePolicy.json"
Checks if Intune Device Configuration Policies exist in the tenant.
.LINK
 https://learn.microsoft.com/en-us/powershell/microsoftgraph/overview
    #> 
    Param(
        [Parameter(Mandatory = $false)]
        [string]$inputfilePath
        
    )

    # Microsoft Graph Connection check
    if ($null -eq (Get-MgContext)) {
        Write-Error "Authentication needed. Please connect to Microsoft Graph."
        return
    }

    # Initialize
    $graphApiVersion = "beta"
    $results = @()

    # Check folder
    if (-not (Test-Path -Path $inputfilePath)) {
        Write-Warning "File path not found: $inputfilePath"
        return
    }

    $jsonFiles = Get-ChildItem -Path $inputfilePath -Filter *.json
    if ($jsonFiles.Count -eq 0) {
        Write-Warning "No JSON files found in path: $inputfilePath"
        return
    }

    # Loop through JSON files
    foreach ($file in $jsonFiles) {
        $policyData = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json | Select-Object -Property Name, id

        if (-not $policyData.id) {
            Write-Warning "No ID found in $($file.Name), skipping."
            continue
        }

        $uri = "https://graph.microsoft.com/$graphApiVersion/deviceManagement/configurationPolicies/$($policyData.id)"

        try {
            $policyResponse = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
        }
        catch {
            Write-Host "Policy $($policyData.Name) - $($policyData.id) not found in tenant."
            continue
        }

        if ($policyResponse) {
            $results += [PSCustomObject]@{
                PolicyName = $policyResponse.Name
                PolicyId   = $policyResponse.id
            }
        }
    }

    if ($results.Count -gt 0) {
        Write-Host "Policies found in tenant matching JSON file(s):"
        return $results
    }
    else {
        Write-Host "No policies found in tenant matching JSON file(s)."
        return $null
    }

}
