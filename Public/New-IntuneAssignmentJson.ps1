function New-IntuneAssignmentJson {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$PolicyId,
        [Parameter(Mandatory = $true)]
        [string]$CsvPath,
        [Parameter(Mandatory = $true)]
        [string]$OutputFile
    )

    if (-not (Test-Path $CsvPath)) { 
        throw "CSV file not found at $CsvPath" 
    }

    $rows = Import-Csv -Path $CsvPath
    if (-not $rows) { 
        throw "CSV file contains no rows." 
    }

    $assignments = @()

    foreach ($row in $rows) {

        if (-not $row.GroupId) { 
            throw "GroupId is required for each row." 
        }

        $isAllDevices = $row.GroupId -eq "adadadad-808e-44e2-905a-0b7873a8a531"
        $isAllUsers   = $row.GroupId -eq "allusers"
        $isExclusion  = $row.Exclusion -eq "Yes"

        if ($isExclusion -and ($isAllDevices -or $isAllUsers)) {
            throw "Exclusions cannot be applied to All Devices or All Users."
        }

        $odataType = if ($isAllDevices) {
            "#microsoft.graph.allDevicesAssignmentTarget"
        }
        elseif ($isAllUsers) {
            "#microsoft.graph.allUsersAssignmentTarget"
        }
        elseif ($isExclusion) {
            "#microsoft.graph.exclusionGroupAssignmentTarget"
        }
        else {
            "#microsoft.graph.groupAssignmentTarget"
        }

        # Filters allowed for everything except exclusions
        $filterId   = $null
        $filterType = "none"

        if (-not $isExclusion) {
            if ($row.FilterId)   { $filterId   = $row.FilterId }
            if ($row.FilterType) { $filterType = $row.FilterType }
        }

        $assignments += [PSCustomObject]@{
            source   = "direct"
            id       = "$PolicyId`_$($row.GroupId)"
            sourceId = $PolicyId
            target   = [PSCustomObject]@{
                "@odata.type" = $odataType
                groupId = if ($isAllDevices -or $isAllUsers) { 
                    $null 
                } else { 
                    $row.GroupId 
                }
                deviceAndAppManagementAssignmentFilterId   = $filterId
                deviceAndAppManagementAssignmentFilterType = $filterType
            }
        }
    }

    $jsonOutput = [PSCustomObject]@{
       "@odata.context" = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$PolicyId')/assignments"
        value = $assignments
    } | ConvertTo-Json -Depth 10

    # Ensure directory exists
    $directory = Split-Path $OutputFile -Parent
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    # Write file ONCE
    $jsonOutput | Set-Content -Path $OutputFile -Encoding UTF8 -Force

    Write-Host "Assignment JSON created at $OutputFile"

    return $jsonOutput
}