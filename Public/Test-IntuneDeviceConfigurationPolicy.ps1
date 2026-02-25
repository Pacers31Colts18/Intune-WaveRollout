function Test-IntuneDeviceConfigurationPolicy {
    Param(
        [Parameter(Mandatory = $false)]
        [string]$filePath
    )

    # Microsoft Graph Connection check
    if ($null -eq (Get-MgContext)) {
        Write-Error "Authentication needed. Please connect to Microsoft Graph."
        Break
    }

    #region Declarations
    $FunctionName = $MyInvocation.MyCommand.Name.ToString()
    $date = Get-Date -Format yyyyMMdd-HHmm
    if ($outputdir.Length -eq 0) { $outputdir = $pwd }
    $OutputFilePath = "$OutputDir\$FunctionName-$date.csv"
    $LogFilePath = "$OutputDir\$FunctionName-$date.log"
    $graphApiVersion = "beta"
    $resultCheck = @()
    #endregion

    #Test Path
    try {
        $testPath = Test-Path -Path $filePath
        Write-Host "File path is valid: $filePath"
    }
    catch {
        Write-Error "An error occurred while testing the file path: $_"
        break
    }

    $jsonFiles = Get-ChildItem -Path $filePath -Filter *.json
    if ($jsonFiles.Count -eq 0) {
        Write-Warning "No JSON files found in path: $filePath"
        return
    }

    $jsonData = $jsonFiles | ForEach-Object {
        Get-Content -Path $_.FullName -Raw | ConvertFrom-Json | Select-Object -Property Name, id
    }    


    #region Get Policy
    $uri = "https://graph.microsoft.com/$graphApiVersion/deviceManagement/configurationPolicies/$($jsonData.id)"
    $policyResponse = Invoke-MgGraphRequest -Uri $uri -Method GET

    if ($policyResponse) {
        Write-Error "Policy found...stopping import."
        Write-Error "PolicyName: $($policyResponse.Name)"
        Write-Error "PolicyId: $($policyResponse.id)"
        $results += [PSCustomObject]@{
            PolicyName = $policyResponse.Name
            PolicyId = $policyResponse.id
        }
        return $results
    }
    else {
        Write-Host "No Settings Catalog policy found: $policyName"
    }
    #endregion
}