[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$isWindowsPlatform = if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
    [bool]$IsWindows
}
else {
    $env:OS -eq "Windows_NT"
}

if (-not $isWindowsPlatform) {
    throw "Questo script e' pensato per Windows Server 2025."
}

if (Get-Command stripe -ErrorAction SilentlyContinue) {
    stripe version
    Write-Output "Stripe CLI gia installata."
    return
}

if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    Invoke-RestMethod -Uri "https://get.scoop.sh" | Invoke-Expression
}

scoop install stripe
stripe version
