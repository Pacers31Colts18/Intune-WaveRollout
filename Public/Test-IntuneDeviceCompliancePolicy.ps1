function Test-IntuneDeviceCompliancePolicy {
    <#
    .SYNOPSIS
        Checks if Intune Device Compliance Policies already exist in the tenant by name.
    .DESCRIPTION
        Reads JSON files from a specified folder and checks whether a policy with the same
        'name' property already exists in the tenant via Microsoft Graph. Returns any matches
        so the caller can decide how to handle conflicts.
    .PARAMETER FolderPath
        Mandatory. The path to the folder containing JSON files of Intune Device Compliance Policies.
    .NOTES
        Requires:
        - Microsoft.Graph PowerShell SDK (Invoke-MgGraphRequest, Get-MgContext)
        - DeviceManagementConfiguration.Read.All (minimum)
    .EXAMPLE
        Test-IntuneDeviceConfigurationPolicy -FolderPath "C:\temp\IntunePolicies"
    .LINK
        https://learn.microsoft.com/en-us/powershell/microsoftgraph/overview
    #>

    [CmdletBinding()]
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

    if (-not (Test-Path -Path $FolderPath)) {
        Write-Error "Folder path '$FolderPath' does not exist."
        return
    }

    $JsonFiles = Get-ChildItem -Path $FolderPath -Filter *.json -File

    if (-not $JsonFiles) {
        Write-Warning "No JSON files found in folder: $FolderPath"
        return
    }

    $Results = @()

    foreach ($File in $JsonFiles) {

        Write-Verbose "Checking: $($File.Name)"

        try {
            $JsonObject = Get-Content -Path $File.FullName -Raw | ConvertFrom-Json
        }
        catch {
            Write-Warning "Could not parse '$($File.Name)' as JSON. Skipping."
            continue
        }

        $PolicyName = $JsonObject.DisplayName

        if (-not $PolicyName) {
            Write-Warning "No 'displayName' property found in '$($File.Name)'. Skipping."
            continue
        }

        
        $FilterUri = "https://graph.microsoft.com/beta/deviceManagement/DeviceCompliancePolicies?`$filter=displayName eq '$PolicyName'"

        try {
            $Response = Invoke-MgGraphRequest -Method GET -Uri $FilterUri -ErrorAction Stop
        }
        catch {
            Write-Warning "Graph query failed for policy name '$PolicyName': $_"
            continue
        }

        $Match = $Response.value | Select-Object -First 1

        if ($Match) {
            Write-Verbose "Found existing policy: $PolicyName [$($Match.id)]"
            $Results += [PSCustomObject]@{
                PolicyName = $Match.displayName
                PolicyId   = $Match.id
                SourceFile = $File.Name
            }
        }
    }

    return $Results
}
