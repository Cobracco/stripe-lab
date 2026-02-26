[CmdletBinding()]
param(
    [switch]$OnlyEnabled,

    [string]$RootPath,

    [int]$SecretTimeoutSeconds = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "StripeLab.Common.ps1")

$config = Read-StripeLabConfig -RootPath $RootPath
$apps = @($config.Apps)

# Default behavior: start only enabled apps, coherent with operational plan.
$selectedApps = @($apps | Where-Object { [bool]$_.enabled })
if (-not $OnlyEnabled.IsPresent -and $selectedApps.Count -eq 0) {
    # Keep behavior explicit when no enabled apps are configured.
    $selectedApps = @()
}

if ($selectedApps.Count -eq 0) {
    throw "Nessuna app abilitata trovata in apps.json. Imposta enabled=true almeno su una app."
}

$startScriptPath = Join-Path $scriptDir "Start-StripeListener.ps1"
$results = foreach ($app in $selectedApps) {
    try {
        & $startScriptPath -AppName ([string]$app.name) -RootPath $config.Paths.Root -SecretTimeoutSeconds $SecretTimeoutSeconds
    }
    catch {
        [pscustomobject]@{
            app = [string]$app.name
            repo = [string]$app.repo
            status = "error"
            pid = $null
            forward_to = Get-StripeLabForwardUrl -BaseUrl ([string]$app.base_url) -WebhookPath ([string]$app.webhook_path)
            webhook_secret_file = $false
            error = $_.Exception.Message
        }
    }
}

$results | Format-Table -AutoSize
$results
