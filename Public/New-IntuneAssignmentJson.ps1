function New-IntuneAssignmentJson {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$InputFilePath,
        [Parameter(Mandatory = $true)]
        [string]$OutputFilePath
    )

    # Validate CSV Exists
    if (-not (Test-Path $InputFilePath)) { 
        Write-Error "CSV file not found at $InputFilePath" 
    }

    $rows = Import-Csv -Path $InputFilePath

    if (-not $rows) { 
        Write-Error "CSV file contains no rows."
    }

    # Validate Required Columns
    if (-not $rows[0].PolicyId) {
        Write-Error "CSV must contain a PolicyId column."
    }

    if (-not $rows[0].GroupId) {
        Write-Error "CSV must contain a GroupId column."
    }

    if (-not $rows[0].AssignmentType) {
        Write-Error "CSV must contain an AssignmentType column (include/exclude)."
    }

    # Validate Single PolicyId
    $policyIds = @($rows | Select-Object -ExpandProperty PolicyId -Unique)

    if ($policyIds.Count -ne 1) {
        throw "CSV must contain exactly ONE unique PolicyId."
    }

    $PolicyId = [string]$policyIds[0]

    $assignments = @()

    foreach ($row in $rows) {

        $groupId = $row.GroupId.Trim()
        $assignmentType = $row.AssignmentType.Trim().ToLower()

        if ($assignmentType -notin @("include", "exclude")) {
            throw "AssignmentType must be either 'include' or 'exclude'. Found: $assignmentType"
        }

        $isAllDevices = $groupId -eq "adadadad-808e-44e2-905a-0b7873a8a531"
        $isAllUsers = $groupId -eq "allusers"
        $isExclusion = $assignmentType -eq "exclude"

        if ($isExclusion -and ($isAllDevices -or $isAllUsers)) {
            throw "Exclusions cannot be applied to All Devices or All Users."
        }

        # Determine OData Type
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

        # Handle Filters
        $filterId = $null
        $filterType = "none"

        if (-not $isExclusion) {
            if ($row.FilterId) { $filterId = $row.FilterId.Trim() }
            if ($row.FilterType) { $filterType = $row.FilterType.Trim() }
        }

        # Build Assignment Object
        $assignments += [PSCustomObject]@{
            source   = "direct"
            id       = "${PolicyId}_$groupId"
            sourceId = $PolicyId
            target   = [PSCustomObject]@{
                "@odata.type"                              = $odataType
                groupId                                    = if ($isAllDevices -or $isAllUsers) { $null } else { $groupId }
                deviceAndAppManagementAssignmentFilterId   = $filterId
                deviceAndAppManagementAssignmentFilterType = $filterType
            }
        }
    }

    # Build Final JSON
    $jsonOutput = [PSCustomObject]@{
        "@odata.context" = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$PolicyId')/assignments"
        value            = $assignments
    } | ConvertTo-Json -Depth 10

    # Ensure output directory exists
    $directory = Split-Path $OutputFilePath -Parent
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $jsonOutput | Set-Content -Path $OutputFilePath -Encoding UTF8 -Force

    Write-Host "Assignment JSON created at $OutputFilePath"

    return $jsonOutput
}