function Get-IntuneDeviceConfigurationPolicyAssignments {
    Param(
        [Parameter(Mandatory = $false)]
        [string]$policyId
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

    #region Get Policy
    $uri = "https://graph.microsoft.com/$graphApiVersion/deviceManagement/configurationPolicies/$policyId"
    $policyResponse = Invoke-MgGraphRequest -Uri $uri -Method GET

    if ($policyResponse) {
        Write-Output "Policy found..."
        Write-Output "PolicyName: $($policyResponse.Name)"
        Write-Output "PolicyId: $($policyResponse.id)"
    }
    else {
        Write-Error "No Settings Catalog policy found: $policyName"
        break
    }
    #endregion

    #region Get Current Assignments
        try {
            $uri = "https://graph.microsoft.com/$graphApiVersion/deviceManagement/configurationPolicies/$($policyResponse.Id)/assignments"
            $currentAssignments = Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject
            if ($currentAssignments) {
                Write-Output "Current assignments found: $($policyResponse.Name)"
            }
            else {
                Write-Warning "No current assignments found: $($policyResponse.Name)"
            }
        }
        catch {
            Write-Error "Error gathering current assignments: $($Error[0].ErrorDetails.Message)"
            break
        }
        #endregion
        $json = $currentAssignments | ConvertTo-Json -Depth 100
        return $json
}

