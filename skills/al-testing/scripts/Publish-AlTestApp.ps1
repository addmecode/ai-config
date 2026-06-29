<#
.SYNOPSIS
Publishes a built AL (test) app to a Business Central container via the development
endpoint, the same mechanism VS Code uses for F5.

.DESCRIPTION
The dev endpoint deploys the prebuilt .app as-is. This deliberately avoids the
in-container recompile that Publish-BcContainerApp performs (and which fails with
AL1024/AL0185 when the app.json platform version is lower than the container) — so do
NOT add -replaceDependencies, which would force that recompile.

Credential resolution order (first hit wins):
  1. an explicit -Credential argument;
  2. a Windows Credential Manager entry whose Target name equals -ContainerName (the
     container name from the test project's launch.json `server` host);
  3. a one-time interactive prompt, whose result is THEN saved to Credential Manager so
     every later run is non-interactive.

Provisioning is automatic: the script installs the CredentialManager module if it is
missing and creates the vault entry on first use — no manual setup steps. VS Code's cached
F5 credentials live in encrypted SecretStorage (DPAPI / state.vscdb) and cannot be reused
from a script, which is why a dedicated vault entry is needed.

.PARAMETER ContainerName
Name of the BC container (the server host from the test project's launch.json). Also used
as the Credential Manager Target name for credential storage/lookup.

.PARAMETER AppFile
Absolute path to the built .app file to publish.

.PARAMETER Credential
Optional PSCredential for UserPassword auth. If omitted, the script reads the Credential
Manager vault (Target = ContainerName), prompting once and storing it if not present yet.

.PARAMETER ResetCredential
Force a fresh prompt and overwrite the stored Credential Manager entry (use after a
password change).

.EXAMPLE
.\Publish-AlTestApp.ps1 -ContainerName 'ui-translation-bc-27-3' `
    -AppFile 'C:\proj\Test\Publisher_Name_1.0.0.0.app'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ContainerName,
    [Parameter(Mandatory)] [string] $AppFile,
    [System.Management.Automation.PSCredential] $Credential,
    [switch] $ResetCredential
)

$ErrorActionPreference = 'Stop'

# Ensure the CredentialManager module is available, installing it (and its NuGet provider)
# on first use so credential storage works without any manual setup.
# NOTE: status messages use Write-Host, not Write-Output, so they do not leak into these
# functions' return value (an [PSCredential] consumer would otherwise receive an Object[]).
function Initialize-CredentialManager {
    if (-not (Get-Module -ListAvailable CredentialManager)) {
        Write-Host "CredentialManager module not found - installing it for the current user (one-time)..."
        if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
        }
        Install-Module CredentialManager -Scope CurrentUser -Force -AllowClobber | Out-Null
    }
    if ($null -eq (Get-Module CredentialManager)) { Import-Module CredentialManager }
}

# Resolve a credential for $ContainerName: read the vault, else prompt once and persist it
# under the container name so subsequent runs are non-interactive.
function Resolve-ContainerCredential {
    Initialize-CredentialManager

    if (-not $ResetCredential) {
        $stored = Get-StoredCredential -Target $ContainerName
        if ($null -ne $stored) {
            Write-Host "Using stored credential from Credential Manager (Target '$ContainerName')."
            return $stored
        }
    }

    $prompted = Get-Credential -Message "BC container credentials for $ContainerName"
    New-StoredCredential -Target $ContainerName -UserName $prompted.UserName `
        -SecurePassword $prompted.Password -Type Generic -Persist LocalMachine | Out-Null
    Write-Host "Saved credential to Credential Manager (Target '$ContainerName') for future runs."
    return $prompted
}

if (-not (Test-Path $AppFile)) { throw "App file not found: $AppFile" }
if ($null -eq (Get-Module BcContainerHelper)) { Import-Module BcContainerHelper -DisableNameChecking }

if ($null -eq $Credential) { $Credential = Resolve-ContainerCredential }

Publish-BcContainerApp -containerName $ContainerName -appFile $AppFile `
    -useDevEndpoint -credential $Credential

Write-Output "PUBLISHED OK: $AppFile -> $ContainerName"
