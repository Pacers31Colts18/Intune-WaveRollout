function New-IntuneAssignmentJson {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$InputFilePath,
        [Parameter(Mandatory = $true)]
        [string]$OutputFilePath
    )

    if (-not (Test-Path $InputFilePath)) { 
        throw "CSV file not found at $InputFilePath" 
    }

    $rows = Import-Csv -Path $InputFilePath
    if (-not $rows) { 
        Write-Error "CSV file contains no rows." 
        break
    }

    # Validate PolicyId exists in CSV
    if (-not $rows[0].PolicyId) {
        Write-Error "CSV must contain a PolicyId column."
        break
    }

    $PolicyId = ($rows | Select-Object -ExpandProperty PolicyId -Unique)

    if (@($PolicyId).Count -gt 1) {
        throw "CSV contains multiple PolicyIds. Only one PolicyId per file is supported."
    }

    $PolicyId = $policyIds[0]

    $assignments = @()

    foreach ($row in $rows) {

        if (-not $row.GroupId) { 
            throw "GroupId is required for each row." 
        }

        $isAllDevices = $row.GroupId -eq "adadadad-808e-44e2-905a-0b7873a8a531"
        $isAllUsers = $row.GroupId -eq "allusers"
        $isExclusion = $row.Exclusion -eq "Yes"

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
        $filterId = $null
        $filterType = "none"

        if (-not $isExclusion) {
            if ($row.FilterId) { $filterId = $row.FilterId }
            if ($row.FilterType) { $filterType = $row.FilterType }
        }

        $assignments += [PSCustomObject]@{
            source   = "direct"
            id       = "$PolicyId`_$($row.GroupId)"
            sourceId = $PolicyId
            target   = [PSCustomObject]@{
                "@odata.type"                              = $odataType
                groupId                                    = if ($isAllDevices -or $isAllUsers) { 
                    $null 
                }
                else { 
                    $row.GroupId 
                }
                deviceAndAppManagementAssignmentFilterId   = $filterId
                deviceAndAppManagementAssignmentFilterType = $filterType
            }
        }
    }

    $jsonOutput = [PSCustomObject]@{
        "@odata.context" = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$PolicyId')/assignments"
        value            = $assignments
    } | ConvertTo-Json -Depth 10

    # Ensure directory exists
    $directory = Split-Path $OutputFilePath -Parent
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $jsonOutput | Set-Content -Path $OutputFilePath -Encoding UTF8 -Force

    Write-Host "Assignment JSON created at $OutputFilePath"

    return $jsonOutput
}