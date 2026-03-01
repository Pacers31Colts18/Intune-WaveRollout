function Export-IntuneDeviceConfigurationPolicyAssignments {
<#
.SYNOPSIS
Exports Microsoft Intune Device Configuration Policy assignment details to a JSON file.
.DESCRIPTION
This function connects to Microsoft Graph and retrieves details about a specified Intune Device Configuration Policy and its assignment configurations. It includes policy metadata, group targeting, filter usage, and assignment intent.
.PARAMETER policyId
Mandatory. The ID of the Intune Device Configuration Policy to export assignments for.
.PARAMETER outputFolder
Optional. The directory path where the JSON file will be saved. Defaults to the current working directory.
.NOTES
Requires:
- Microsoft.Graph PowerShell SDK (e.g., Invoke-MgGraphRequest, Get-MgContext)
- Graph permissions to read device management configuration policies and group details.
.EXAMPLE
Export-IntuneDeviceConfigurationPolicyAssignments -policyId "12345678-1234-1234-1234-123456789012" -outputFolder "C:\temp"
Exports assignments for a specific policy to a specified output folder.
.OUTPUTS
A JSON file containing assignment details with properties such as:
id, target, filter, intent, and more depending on the assignment configuration.
.LINK
 https://learn.microsoft.com/en-us/powershell/microsoftgraph/overview
    #>    
    Param(
        [Parameter(Mandatory = $true)]
        [string]$policyId,
        [Parameter(Mandatory = $false)]
        [string]$outputFolder = $pwd
    )

    # Check Graph connection
    if ($null -eq (Get-MgContext)) {
        Write-Error "Authentication needed. Please connect to Microsoft Graph."
        return
    }

    # Get Policy
    $graphApiVersion = "beta"
    $policyUri = "https://graph.microsoft.com/$graphApiVersion/deviceManagement/configurationPolicies/$policyId"
    $policyResponse = Invoke-MgGraphRequest -Uri $policyUri -Method GET

    if (-not $policyResponse) {
        Write-Error "Policy $policyId not found in tenant."
        return
    }

    # Get Assignments
    $assignmentsUri = "https://graph.microsoft.com/$graphApiVersion/deviceManagement/configurationPolicies/$policyId/assignments"
    $currentAssignments = Invoke-MgGraphRequest -Uri $assignmentsUri -Method GET

    if (-not $currentAssignments.value) {
        Write-Warning "No assignments found for PolicyId $policyId"
        return $null
    }
    if ($currentAssignments.value) {
        # Convert to JSON
        $json = $currentAssignments.value | ConvertTo-Json -Depth 10

        # Save to file if output folder specified
        if (-not (Test-Path $outputFolder)) { New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null }
        $safeName = ($policyResponse.Name -replace '[\\/:*?"<>|]', '_')
        $filePath = Join-Path -Path $outputFolder -ChildPath "$safeName$($policyResponse.Id)_Assignments.json"
        $json | Set-Content -Path $filePath -Force
        Write-Host "Assignments exported to $filePath"
    }
    return $json
}
