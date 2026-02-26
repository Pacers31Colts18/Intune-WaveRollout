function Merge-IntuneAssignmentJson {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$originalassignmentFile,
        [Parameter(Mandatory = $true)]
        [string]$additionalassignmentFile,
        [Parameter(Mandatory = $true)]
        [string]$OutputFile
    )

    if (-not (Test-Path $originalassignmentFile)) { 
        Write-Error "Original assignment file not found at $originalassignmentFile" 
        break
    }
    if (-not (Test-Path $additionalassignmentFile)) { 
        Write-Error "Additional assignment file not found at $additionalassignmentFile"
        break
         }

    $data1 = Get-Content $originalassignmentFile -Raw | ConvertFrom-Json
    $data2 = Get-Content $additionalassignmentFile -Raw | ConvertFrom-Json

    # Validate structure
    if (-not $data1.value -or -not $data2.value) {
        Write-Error "One of the files does not contain a valid 'value' array."
        break
    }

    # Merge assignment arrays
    $mergedAssignments = @($data1.value + $data2.value)

    # Remove duplicates by assignment id
    $mergedAssignments = $mergedAssignments |
        Sort-Object id -Unique

    # Use context from first file
    $finalObject = [PSCustomObject]@{
        value            = $mergedAssignments
        "@odata.context" = $data1.'@odata.context'
    }

    # Convert and save
    $jsonOutput = $finalObject | ConvertTo-Json -Depth 10

    $directory = Split-Path $OutputFile -Parent
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $jsonOutput | Set-Content -Path $OutputFile -Encoding UTF8 -Force

    Write-Host "Merged assignment JSON written to $OutputFile"

    return $jsonOutput
}