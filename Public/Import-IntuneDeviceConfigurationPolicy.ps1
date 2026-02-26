Function Import-IntuneDeviceConfigurationPolicy {

    [CmdletBinding()]
    param
    (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FolderPath
    )

    # Ensure Graph connection exists
    if (-not (Get-MgContext)) {
        throw "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    }

    if (-not (Test-Path $FolderPath)) {
        throw "Folder path '$FolderPath' does not exist."
    }

    $JsonFiles = Get-ChildItem -Path $FolderPath -Filter *.json -File

    if (-not $JsonFiles) {
        throw "No JSON files found in folder: $FolderPath"
    }

    $Results = @()

    foreach ($File in $JsonFiles) {

        Write-Host "Processing: $($File.Name)"

        try {

            # Read JSON
            $RawJson = Get-Content -Path $File.FullName -Raw
            $JsonObject = $RawJson | ConvertFrom-Json

            # Remove properties not allowed on import
            $JsonObject.PSObject.Properties.Remove("id")
            $JsonObject.PSObject.Properties.Remove("createdDateTime")
            $JsonObject.PSObject.Properties.Remove("lastModifiedDateTime")
            $JsonObject.PSObject.Properties.Remove("version")
            $JsonObject.PSObject.Properties.Remove("supportsScopeTags")
            $JsonObject.PSObject.Properties.Remove("supportedScopeTags")

            $DisplayName = $JsonObject.name

            if (-not $DisplayName) {
                throw "Policy file '$($File.Name)' does not contain a 'name' property."
            }

            # Check if policy already exists
            $FilterUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=name eq '$DisplayName'"
            $Existing = Invoke-MgGraphRequest -Method GET -Uri $FilterUri

            $ExistingPolicy = $Existing.value | Select-Object -First 1

            $Body = $JsonObject | ConvertTo-Json -Depth 20

            if ($ExistingPolicy) {

                $PolicyId = $ExistingPolicy.id
                Write-Host "Policy exists. Updating: $DisplayName ($PolicyId)"

                Invoke-MgGraphRequest `
                    -Method PUT `
                    -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$PolicyId" `
                    -Body $Body `
                    -ContentType "application/json"

            }
            else {

                Write-Host "Policy does not exist. Creating: $DisplayName"

                $Created = Invoke-MgGraphRequest `
                    -Method POST `
                    -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" `
                    -Body $Body `
                    -ContentType "application/json"

                $PolicyId = $Created.id
            }

            if (-not $PolicyId) {
                throw "Failed to determine Policy ID for '$DisplayName'"
            }

            Write-Host "Success: $DisplayName ($PolicyId)"

            # Return object for workflow
            $Results += [PSCustomObject]@{
                Name = $File.Name      # must match CSV FileName column
                Id   = $PolicyId
            }

        }
        catch {
            Write-Error "Failed processing $($File.Name): $_"
            throw
        }
    }

    return $Results
}