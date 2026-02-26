[CmdletBinding()]
param(
    [string]$RootPath,

    [switch]$LockDownAcl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$isWindowsPlatform = if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
    [bool]$IsWindows
}
else {
    $env:OS -eq "Windows_NT"
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "StripeLab.Common.ps1")

$paths = Get-StripeLabPaths -RootPath $RootPath
Ensure-StripeLabDirectories -Paths $paths

if ($LockDownAcl.IsPresent) {
    if ($isWindowsPlatform) {
        $targetDirs = @($paths.Root, $paths.ConfigDir, $paths.LogsDir, $paths.SecretsDir, $paths.RunDir)
        foreach ($dir in $targetDirs) {
            & icacls $dir /inheritance:r /grant:r "Administrators:(OI)(CI)F" /grant:r "SYSTEM:(OI)(CI)F" | Out-Null
        }
    }
    else {
        Write-Warning "LockDownAcl richiesto ma non sei su Windows: ACL non applicate."
    }
}

[pscustomobject]@{
    root = $paths.Root
    config = $paths.AppConfigPath
    scripts = $paths.ScriptsDir
    logs = $paths.LogsDir
    secrets = $paths.SecretsDir
    run = $paths.RunDir
}
