function Export-IntuneDeviceConfigurationPolicyAssignments {
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
