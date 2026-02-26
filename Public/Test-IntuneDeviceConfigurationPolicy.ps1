function Test-IntuneDeviceConfigurationPolicy {
    Param(
        [Parameter(Mandatory = $false)]
        [string]$inputfilePath
        
    )

    # Microsoft Graph Connection check
    if ($null -eq (Get-MgContext)) {
        Write-Error "Authentication needed. Please connect to Microsoft Graph."
        return
    }

    # Initialize
    $graphApiVersion = "beta"
    $results = @()

    # Check folder
    if (-not (Test-Path -Path $filePath)) {
        Write-Warning "File path not found: $filePath"
        return
    }

    $jsonFiles = Get-ChildItem -Path $filePath -Filter *.json
    if ($jsonFiles.Count -eq 0) {
        Write-Warning "No JSON files found in path: $filePath"
        return
    }

    # Loop through JSON files
    foreach ($file in $jsonFiles) {
        $policyData = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json | Select-Object -Property Name, id

        if (-not $policyData.id) {
            Write-Warning "No ID found in $($file.Name), skipping."
            continue
        }

        $uri = "https://graph.microsoft.com/$graphApiVersion/deviceManagement/configurationPolicies/$($policyData.id)"

        try {
            $policyResponse = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
        }
        catch {
            Write-Host "Policy $($policyData.Name) - $($policyData.id) not found in tenant."
            continue
        }

        if ($policyResponse) {
            $results += [PSCustomObject]@{
                PolicyName = $policyResponse.Name
                PolicyId   = $policyResponse.id
            }
        }
    }

    if ($results.Count -gt 0) {
        Write-Error "Policies found in tenant matching JSON file(s):"
        Write-Error ($results | Format-Table -AutoSize | Out-String)
    }

    return $results
}
