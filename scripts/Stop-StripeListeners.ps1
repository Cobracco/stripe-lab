[CmdletBinding()]
param(
    [string]$AppName,

    [string]$RootPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "StripeLab.Common.ps1")

$paths = (Get-StripeLabPaths -RootPath $RootPath)
Ensure-StripeLabDirectories -Paths $paths

$targets = @()
if (-not [string]::IsNullOrWhiteSpace($AppName)) {
    $config = Read-StripeLabConfig -RootPath $paths.Root
    $app = Get-StripeLabApp -Apps $config.Apps -AppName $AppName
    $targets = @([string]$app.name)
}
else {
    $pidFiles = Get-ChildItem -LiteralPath $paths.RunDir -Filter "*.pid" -File -ErrorAction SilentlyContinue
    $targets = @($pidFiles | ForEach-Object { $_.BaseName })
}

if ($targets.Count -eq 0) {
    Write-Output "Nessun listener da fermare."
    return
}

$results = foreach ($target in $targets) {
    $pidPath = Join-Path $paths.RunDir ("{0}.pid" -f $target)
    $pidInfo = Get-StripeLabPidInfo -PidFilePath $pidPath

    if (-not $pidInfo.HasPidFile) {
        [pscustomobject]@{
            app = $target
            pid = $null
            status = "pid_not_found"
        }
        continue
    }

    if ($pidInfo.IsRunning -and $pidInfo.Pid) {
        try {
            Stop-Process -Id $pidInfo.Pid -Force -ErrorAction Stop
            Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
            [pscustomobject]@{
                app = $target
                pid = $pidInfo.Pid
                status = "stopped"
            }
        }
        catch {
            [pscustomobject]@{
                app = $target
                pid = $pidInfo.Pid
                status = "stop_failed"
                error = $_.Exception.Message
            }
        }
    }
    else {
        Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
        [pscustomobject]@{
            app = $target
            pid = $pidInfo.Pid
            status = "stale_pid_removed"
        }
    }
}

$results | Format-Table -AutoSize
$results
