[CmdletBinding()]
param(
    [string]$RootPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "StripeLab.Common.ps1")

$config = Read-StripeLabConfig -RootPath $RootPath
$paths = $config.Paths
Ensure-StripeLabDirectories -Paths $paths

$rows = foreach ($app in @($config.Apps)) {
    $name = [string]$app.name
    $pidPath = Join-Path $paths.RunDir ("{0}.pid" -f $name)
    $logPath = Join-Path $paths.LogsDir ("{0}.log" -f $name)
    $secretPath = Join-Path $paths.SecretsDir ("{0}.webhook.secret" -f $name)

    $pidInfo = Get-StripeLabPidInfo -PidFilePath $pidPath
    if ($pidInfo.HasPidFile -and -not $pidInfo.IsRunning) {
        Remove-StripeLabStalePid -PidFilePath $pidPath | Out-Null
        $pidInfo = Get-StripeLabPidInfo -PidFilePath $pidPath
    }

    $lastLogUtc = $null
    if (Test-Path -LiteralPath $logPath) {
        $lastLogUtc = (Get-Item -LiteralPath $logPath).LastWriteTimeUtc
    }

    [pscustomobject]@{
        app = $name
        repo = [string]$app.repo
        enabled = [bool]$app.enabled
        running = [bool]$pidInfo.IsRunning
        pid = $pidInfo.Pid
        forward_to = Get-StripeLabForwardUrl -BaseUrl ([string]$app.base_url) -WebhookPath ([string]$app.webhook_path)
        webhook_secret_file = (Test-Path -LiteralPath $secretPath)
        last_log_utc = $lastLogUtc
    }
}

$orphanPidFiles = Get-ChildItem -LiteralPath $paths.RunDir -Filter "*.pid" -File -ErrorAction SilentlyContinue |
    Where-Object { ($rows.app -notcontains $_.BaseName) }

foreach ($orphan in $orphanPidFiles) {
    $pidInfo = Get-StripeLabPidInfo -PidFilePath $orphan.FullName
    if ($pidInfo.HasPidFile -and -not $pidInfo.IsRunning) {
        Remove-StripeLabStalePid -PidFilePath $orphan.FullName | Out-Null
    }

    $rows += [pscustomobject]@{
        app = $orphan.BaseName
        repo = "<orphan>"
        enabled = $false
        running = [bool]$pidInfo.IsRunning
        pid = $pidInfo.Pid
        forward_to = "<unknown>"
        webhook_secret_file = $false
        last_log_utc = $null
    }
}

$rows | Sort-Object app | Format-Table -AutoSize
$rows
