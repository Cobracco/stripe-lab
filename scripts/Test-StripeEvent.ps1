[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AppName,

    [Parameter(Mandatory = $true)]
    [string]$Event,

    [string]$RootPath,

    [int]$LogWaitSeconds = 20
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

$envVarName = [string]$app.stripe_secret_env
$secretKey = Get-StripeLabEnvVarValue -Name $envVarName
if ([string]::IsNullOrWhiteSpace($secretKey)) {
    throw "Environment variable '$envVarName' non impostata per app '$($app.name)'."
}
Assert-StripeLabTestSecretKey -SecretKey $secretKey -EnvVarName $envVarName

$logPath = Join-Path $paths.LogsDir ("{0}.log" -f $app.name)
$fromByte = 0
if (Test-Path -LiteralPath $logPath) {
    $fromByte = (Get-Item -LiteralPath $logPath).Length
}

$env:STRIPE_API_KEY = $secretKey
$output = & stripe trigger $Event 2>&1
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    throw "stripe trigger ha fallito per app '$($app.name)'. ExitCode=$exitCode. Output: $($output -join ' ')"
}

$matched = Wait-StripeLabLogPattern -LogPath $logPath -Pattern ([Regex]::Escape($Event)) -TimeoutSeconds $LogWaitSeconds -FromByte $fromByte

[pscustomobject]@{
    app = [string]$app.name
    event = $Event
    trigger_ok = $true
    listener_log_match = $matched
    log_path = $logPath
    stripe_output = ($output -join [Environment]::NewLine)
}
