function Set-IntuneDeviceConfigurationPolicyAssignment {
<#
.SYNOPSIS
Configures Intune Device Configuration Policy assignments from a JSON file.
.DESCRIPTION
This function applies assignments to an Intune Device Configuration Policy using a JSON file.
.PARAMETER InputFilePath
Mandatory. The path to the input JSON file containing assignments.
.NOTES
Requires:
- Microsoft.Graph PowerShell SDK (e.g., Invoke-MgGraphRequest, Get-MgContext)
- Microsoft.Graph.DeviceManagement permissions to read and write configuration policies.
.EXAMPLE
Set-IntuneDeviceConfigurationPolicyAssignment -InputFilePath "C:\temp\IntuneAssignments.json"
Applies assignments from the specified JSON file to an Intune Device Configuration Policy.
.LINK
 https://learn.microsoft.com/en-us/powershell/microsoftgraph/overview
    #> 

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$InputFilePath
    )

    # Check Graph connection
    if ($null -eq (Get-MgContext)) {
        Write-Error "Authentication needed. Please connect to Microsoft Graph."
        return
    }

    $graphApiVersion = "beta"

    if (-not (Test-Path $InputFilePath)) {
        Write-Error "File not found: $InputFilePath"
        return
    }

    try {
        # Load JSON
        $jsonContent = Get-Content $InputFilePath -Raw | ConvertFrom-Json

        if (-not $jsonContent.value) {
            Write-Error "JSON file does not contain a value."
            break
        }

        # Get unique sourceId
        $policyIds = @($jsonContent.value | Select-Object -ExpandProperty sourceId -Unique)

        if ($policyIds.Count -eq 0) {
            Write-Error "No sourceId found in assignments."
            break
        }

        if ($policyIds.Count -gt 1) {
            Write-Error "Multiple sourceIds found in JSON. Only one PolicyId per file is supported."
            break
        }

        $PolicyId = $policyIds[0]

        # Build body
        $body = @{
            assignments = $jsonContent.value
        } | ConvertTo-Json -Depth 10

        $uri = "https://graph.microsoft.com/$graphApiVersion/deviceManagement/configurationPolicies/$PolicyId/assign"

        Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -ContentType "application/json"
        Write-Host "Successfully applied assignments for PolicyId $PolicyId"
    }
    catch {
        Write-Error "Error applying assignments: $_"
    }
}