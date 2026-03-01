Function Import-IntuneDeviceConfigurationPolicy {
<#
.SYNOPSIS
Imports Microsoft Intune Device Configuration Policies from JSON files in a specified folder. It creates new policies or updates existing ones based on the 'name' property in the JSON.
.DESCRIPTION
This function imports Intune Device Configuration Policies from JSON files in a specified folder. It creates new policies or updates existing ones based on the 'name' property in the JSON.
.PARAMETER folderPath
Mandatory. The path to the folder containing JSON files of Intune Device Configuration Policies.
.NOTES
Requires:
- Microsoft.Graph PowerShell SDK (e.g., Invoke-MgGraphRequest, Get-MgContext)
- Microsoft.Graph.DeviceManagement permissions to read and write configuration policies.
.EXAMPLE
Import-IntuneDeviceConfigurationPolicy -FolderPath "C:\temp\IntunePolicies"
Imports all Intune Device Configuration Policies from the specified folder.
.LINK
 https://learn.microsoft.com/en-us/powershell/microsoftgraph/overview
    #>      

    [CmdletBinding()]
    param
    (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FolderPath
    )

    # Ensure Graph connection exists
    if (-not (Get-MgContext)) {
        Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
        break
    }

    if (-not (Test-Path $FolderPath)) {
        Write-Error "Folder path '$FolderPath' does not exist."
        break
    }

    $JsonFiles = Get-ChildItem -Path $FolderPath -Filter *.json -File

    if (-not $JsonFiles) {
        Write-Error "No JSON files found in folder: $FolderPath"
        break
    }

    $Results = @()

    foreach ($File in $JsonFiles) {

        Write-Host "Processing: $($File.Name)"

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
                Write-Error "Policy file '$($File.Name)' does not contain a 'name' property."
                break
            }

            # Check if policy already exists
            try {
                $FilterUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=name eq '$DisplayName'"
                $Existing = Invoke-MgGraphRequest -Method GET -Uri $FilterUri   
            }
            catch {
                Write-Error "Failed to query existing policies for '$DisplayName': $_"
                break
            }

            $ExistingPolicy = $Existing.value | Select-Object -First 1

            $Body = $JsonObject | ConvertTo-Json -Depth 20

            if ($ExistingPolicy) {

                $PolicyId = $ExistingPolicy.id
                Write-Host "Policy exists. Updating: $DisplayName ($PolicyId)"
                try {
                Invoke-MgGraphRequest -Method PUT -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$PolicyId" -Body $Body -ContentType "application/json"
                }
                catch {
                    Write-Error "Failed to update policy '$DisplayName': $_"
                    break
                }
            }
            else {
                Write-Host "Policy does not exist. Creating: $DisplayName"
                try {
                    $Created = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" -Body $Body -ContentType "application/json"
                }
                catch {
                    Write-Error "Failed to create policy '$DisplayName': $_"
                    break
                }
                $PolicyId = $Created.id
            }

            if (-not $PolicyId) {
                Write-Error "Failed to determine Policy ID for '$DisplayName'"
                break
            }

            Write-Host "Policy imported: $DisplayName ($PolicyId)"

            # Return object for workflow
            $Results += [PSCustomObject]@{
                Name = $File.Name 
                Id   = $PolicyId
            }

        }
        catch {
            Write-Error "Failed processing $($File.Name): $_"
            break
        }
            return $Results
    }

