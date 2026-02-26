[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AppName,

    [string]$RootPath,

    [int]$SecretTimeoutSeconds = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "StripeLab.Common.ps1")

Assert-StripeCliAvailable
$config = Read-StripeLabConfig -RootPath $RootPath
$paths = $config.Paths
Ensure-StripeLabDirectories -Paths $paths

$app = Get-StripeLabApp -Apps $config.Apps -AppName $AppName

$pidPath = Join-Path $paths.RunDir ("{0}.pid" -f $app.name)
$logPath = Join-Path $paths.LogsDir ("{0}.log" -f $app.name)
$logErrPath = Join-Path $paths.LogsDir ("{0}.err.log" -f $app.name)
$secretPath = Join-Path $paths.SecretsDir ("{0}.webhook.secret" -f $app.name)

$pidInfo = Get-StripeLabPidInfo -PidFilePath $pidPath
if ($pidInfo.HasPidFile -and $pidInfo.IsRunning) {
    $forwardUrl = Get-StripeLabForwardUrl -BaseUrl ([string]$app.base_url) -WebhookPath ([string]$app.webhook_path)
    $result = [pscustomobject]@{
        app = [string]$app.name
        repo = [string]$app.repo
        status = "already_running"
        pid = $pidInfo.Pid
        forward_to = $forwardUrl
        webhook_secret_file = (Test-Path -LiteralPath $secretPath)
    }

    $result
    return
}

if ($pidInfo.HasPidFile -and -not $pidInfo.IsRunning) {
    Remove-StripeLabStalePid -PidFilePath $pidPath | Out-Null
}

$envVarName = [string]$app.stripe_secret_env
$secretKey = Get-StripeLabEnvVarValue -Name $envVarName
if ([string]::IsNullOrWhiteSpace($secretKey)) {
    throw "Environment variable '$envVarName' non impostata per app '$($app.name)'."
}

Assert-StripeLabTestSecretKey -SecretKey $secretKey -EnvVarName $envVarName

$forwardUrl = Get-StripeLabForwardUrl -BaseUrl ([string]$app.base_url) -WebhookPath ([string]$app.webhook_path)
$eventsArg = Get-StripeLabEventsArgument -Events @($app.events)

$arguments = @(
    "listen",
    "--events", $eventsArg,
    "--forward-to", $forwardUrl
)

$env:STRIPE_API_KEY = $secretKey

if (-not (Test-Path -LiteralPath $logPath)) {
    New-Item -ItemType File -Path $logPath -Force | Out-Null
}
Add-Content -LiteralPath $logPath -Value ("`n----- listener restart {0} -----" -f (Get-Date -Format "s"))
$logScanStartByte = (Get-Item -LiteralPath $logPath).Length

$process = Start-Process -FilePath "stripe" -ArgumentList $arguments -PassThru -NoNewWindow -RedirectStandardOutput $logPath -RedirectStandardError $logErrPath
Set-Content -LiteralPath $pidPath -Value ([string]$process.Id) -Encoding ascii

Start-Sleep -Seconds 1
$processStillRunning = $null -ne (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)
if (-not $processStillRunning) {
    Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
    $stderrTail = if (Test-Path -LiteralPath $logErrPath) {
        (Get-Content -LiteralPath $logErrPath -Tail 40 -ErrorAction SilentlyContinue) -join [Environment]::NewLine
    }
    else {
        ""
    }

    $errorDetails = if ([string]::IsNullOrWhiteSpace($stderrTail)) {
        "Nessun dettaglio su stderr. Controlla i log: '$logPath' e '$logErrPath'."
    }
    else {
        "Ultime righe stderr: $stderrTail"
    }

    throw "Il listener Stripe per app '$($app.name)' si e' chiuso subito dopo l'avvio. $errorDetails"
}

$webhookSecret = Wait-StripeLabWebhookSecret -LogPath $logPath -TimeoutSeconds $SecretTimeoutSeconds -FromByte $logScanStartByte
if (-not [string]::IsNullOrWhiteSpace($webhookSecret)) {
    Set-Content -LiteralPath $secretPath -Value $webhookSecret -Encoding ascii
}

$processStillRunning = $null -ne (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)
if (-not $processStillRunning) {
    Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
    throw "Il listener Stripe per app '$($app.name)' non e' piu' in esecuzione. Controlla '$logPath' e '$logErrPath'."
}

$status = if (-not [string]::IsNullOrWhiteSpace($webhookSecret)) { "started" } else { "started_secret_pending" }

[pscustomobject]@{
    app = [string]$app.name
    repo = [string]$app.repo
    status = $status
    pid = $process.Id
    forward_to = $forwardUrl
    webhook_secret_file = (Test-Path -LiteralPath $secretPath)
}
