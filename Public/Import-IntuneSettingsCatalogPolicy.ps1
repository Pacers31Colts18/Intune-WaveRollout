Function Import-IntuneSettingsCatalogPolicy {
    <#
    .SYNOPSIS
    Import all .JSON settings catalog policies from a folder into Intune using Invoke-MgGraphRequest.
    .DESCRIPTION
    Imports every .JSON file in a folder as a Settings Catalog policy. No assignments are created.
    #>

    [CmdletBinding()]
    param
    (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$folderPath
    )

    # Ensure Graph context exists
    if ($null -eq (Get-MgContext)) {
        Write-Error "Authentication needed. Please connect to Graph."
        return
    }

    # Declarations
    $FunctionName = $MyInvocation.MyCommand.Name.ToString()
    $date = Get-Date -Format yyyyMMdd-HHmm
    if ($OutputDir.Length -eq 0) { $OutputDir = $pwd }
    $LogFilePath = "$OutputDir\$FunctionName-$date.log"

    # Get all JSON files
    $JsonFiles = Get-ChildItem -Path $FolderPath -Filter *.json
    if ($JsonFiles.Count -eq 0) {
        Write-Error "No JSON files found in folder."
        return
    }

    $GraphUri = "/beta/deviceManagement/configurationPolicies"

    foreach ($File in $JsonFiles) {

        Write-Output "Processing file: $($File.FullName)"

        try {
            # Read JSON
            $JSON_Data = Get-Content -Path $File.FullName -Raw

            # Remove properties not allowed during import
            $JSON_Convert = $JSON_Data | ConvertFrom-Json |
            Select-Object -Property * -ExcludeProperty id, createdDateTime, lastModifiedDateTime, version, supportsScopeTags

            $DisplayName = $JSON_Convert.name
            $JSON_Output = $JSON_Convert | ConvertTo-Json -Depth 20

            Write-Output "Importing policy '$DisplayName'..."

            # Graph API call using Invoke-MgGraphRequest
            $response = Invoke-MgGraphRequest -Method POST -Uri $GraphUri -Body $JSON_Output -ContentType "application/json"

            Write-Output "Successfully imported: $DisplayName"
        }
        catch {
            Write-Error "Error importing file $($File.Name): $_"
        }
    }
}
