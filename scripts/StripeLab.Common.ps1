Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-StripeLabRoot {
    [CmdletBinding()]
    param(
        [string]$RootPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RootPath)) {
        return $RootPath
    }

    if (-not [string]::IsNullOrWhiteSpace($env:STRIPE_LAB_ROOT)) {
        return $env:STRIPE_LAB_ROOT
    }

    return "C:\stripe-lab"
}

function Get-StripeLabPaths {
    [CmdletBinding()]
    param(
        [string]$RootPath
    )

    $root = Get-StripeLabRoot -RootPath $RootPath
    $configDir = Join-Path $root "config"
    $paths = [ordered]@{
        Root = $root
        BinDir = Join-Path $root "bin"
        ConfigDir = $configDir
        ScriptsDir = Join-Path $root "scripts"
        LogsDir = Join-Path $root "logs"
        SecretsDir = Join-Path $root "secrets"
        RunDir = Join-Path $root "run"
        AppConfigPath = Join-Path $configDir "apps.json"
    }

    return [pscustomobject]$paths
}

function Ensure-StripeLabDirectories {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Paths
    )

    foreach ($dir in @($Paths.Root, $Paths.BinDir, $Paths.ConfigDir, $Paths.ScriptsDir, $Paths.LogsDir, $Paths.SecretsDir, $Paths.RunDir)) {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
}

function Assert-StripeCliAvailable {
    [CmdletBinding()]
    param()

    if (-not (Get-Command stripe -ErrorAction SilentlyContinue)) {
        throw "Stripe CLI non trovato nel PATH. Installa Stripe CLI (es. scoop install stripe) e riprova."
    }
}

function Read-StripeLabConfig {
    [CmdletBinding()]
    param(
        [string]$RootPath
    )

    $paths = Get-StripeLabPaths -RootPath $RootPath

    if (-not (Test-Path -LiteralPath $paths.AppConfigPath)) {
        throw "File config non trovato: $($paths.AppConfigPath)"
    }

    $raw = Get-Content -LiteralPath $paths.AppConfigPath -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Il file config e' vuoto: $($paths.AppConfigPath)"
    }

    $data = $raw | ConvertFrom-Json
    if (-not $data -or -not $data.apps) {
        throw "Config invalida: manca la chiave top-level 'apps'."
    }

    $apps = @($data.apps)
    Assert-StripeLabApps -Apps $apps

    return [pscustomobject]@{
        Paths = $paths
        Apps = $apps
    }
}

function Assert-StripeLabApps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Apps
    )

    if ($Apps.Count -eq 0) {
        throw "Config invalida: 'apps' non puo' essere vuoto."
    }

    $requiredFields = @("name", "repo", "sandbox", "base_url", "webhook_path", "events", "stripe_secret_env", "enabled")
    $nameSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($app in $Apps) {
        foreach ($field in $requiredFields) {
            if (-not ($app.PSObject.Properties.Name -contains $field)) {
                throw "Config invalida: campo obbligatorio '$field' mancante in una app."
            }
        }

        if ([string]::IsNullOrWhiteSpace([string]$app.name)) {
            throw "Config invalida: name non puo' essere vuoto."
        }

        if (-not $nameSet.Add([string]$app.name)) {
            throw "Config invalida: nome app duplicato '$($app.name)'."
        }

        $events = @($app.events)
        if ($events.Count -eq 0) {
            throw "Config invalida: la app '$($app.name)' non ha eventi configurati."
        }

        foreach ($eventName in $events) {
            if ([string]::IsNullOrWhiteSpace([string]$eventName)) {
                throw "Config invalida: la app '$($app.name)' contiene un evento vuoto."
            }
        }

        if ([string]::IsNullOrWhiteSpace([string]$app.stripe_secret_env)) {
            throw "Config invalida: la app '$($app.name)' ha stripe_secret_env vuoto."
        }

        $null = [bool]$app.enabled
    }
}

function Get-StripeLabApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Apps,

        [Parameter(Mandatory = $true)]
        [string]$AppName
    )

    $app = $Apps | Where-Object { $_.name -ieq $AppName } | Select-Object -First 1
    if (-not $app) {
        throw "App '$AppName' non trovata in apps.json."
    }

    return $app
}

function Get-StripeLabForwardUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$WebhookPath
    )

    $base = $BaseUrl.TrimEnd("/")
    $path = if ($WebhookPath.StartsWith("/")) { $WebhookPath } else { "/$WebhookPath" }
    return "$base$path"
}

function Get-StripeLabEventsArgument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Events
    )

    $items = @($Events | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($items.Count -eq 0) {
        throw "Lista eventi vuota."
    }

    return ($items -join ",")
}

function Get-StripeLabEnvVarValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $processValue = [Environment]::GetEnvironmentVariable($Name, [EnvironmentVariableTarget]::Process)
    if (-not [string]::IsNullOrWhiteSpace($processValue)) {
        return $processValue
    }

    $userValue = [Environment]::GetEnvironmentVariable($Name, [EnvironmentVariableTarget]::User)
    if (-not [string]::IsNullOrWhiteSpace($userValue)) {
        return $userValue
    }

    $machineValue = [Environment]::GetEnvironmentVariable($Name, [EnvironmentVariableTarget]::Machine)
    if (-not [string]::IsNullOrWhiteSpace($machineValue)) {
        return $machineValue
    }

    return $null
}

function Assert-StripeLabTestSecretKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SecretKey,

        [Parameter(Mandatory = $true)]
        [string]$EnvVarName
    )

    if ($SecretKey.StartsWith("sk_live_", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Rifiutata chiave live in '$EnvVarName'. Usa solo chiavi test (sk_test_*)."
    }

    if (-not $SecretKey.StartsWith("sk_test_", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Chiave non valida in '$EnvVarName': atteso prefisso sk_test_."
    }
}

function Get-StripeLabPidInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PidFilePath
    )

    if (-not (Test-Path -LiteralPath $PidFilePath)) {
        return [pscustomobject]@{
            HasPidFile = $false
            Pid = $null
            IsRunning = $false
            Process = $null
        }
    }

    $rawPid = (Get-Content -LiteralPath $PidFilePath -Raw).Trim()
    $pidValue = 0
    if (-not [int]::TryParse($rawPid, [ref]$pidValue)) {
        return [pscustomobject]@{
            HasPidFile = $true
            Pid = $null
            IsRunning = $false
            Process = $null
        }
    }

    try {
        $process = Get-Process -Id $pidValue -ErrorAction Stop
        return [pscustomobject]@{
            HasPidFile = $true
            Pid = $pidValue
            IsRunning = $true
            Process = $process
        }
    }
    catch {
        return [pscustomobject]@{
            HasPidFile = $true
            Pid = $pidValue
            IsRunning = $false
            Process = $null
        }
    }
}

function Remove-StripeLabStalePid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PidFilePath
    )

    $pidInfo = Get-StripeLabPidInfo -PidFilePath $PidFilePath
    if ($pidInfo.HasPidFile -and -not $pidInfo.IsRunning) {
        Remove-Item -LiteralPath $PidFilePath -Force
        return $true
    }

    return $false
}

function Wait-StripeLabWebhookSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath,

        [int]$TimeoutSeconds = 20,

        [long]$FromByte = 0
    )

    $endTime = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $endTime) {
        if (Test-Path -LiteralPath $LogPath) {
            $item = Get-Item -LiteralPath $LogPath
            if ($item.Length -gt 0) {
                $bytes = [System.IO.File]::ReadAllBytes($LogPath)
                $startIndex = if ($FromByte -gt 0 -and $FromByte -lt $bytes.Length) { [int]$FromByte } else { 0 }
                $length = $bytes.Length - $startIndex

                if ($length -gt 0) {
                    $text = [System.Text.Encoding]::UTF8.GetString($bytes, $startIndex, $length)
                    if ($text -match "whsec_[A-Za-z0-9]+") {
                        return $Matches[0]
                    }
                }
            }
        }

        Start-Sleep -Milliseconds 500
    }

    return $null
}

function Wait-StripeLabLogPattern {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [int]$TimeoutSeconds = 20,

        [long]$FromByte = 0
    )

    $endTime = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $endTime) {
        if (Test-Path -LiteralPath $LogPath) {
            $item = Get-Item -LiteralPath $LogPath
            if ($item.Length -gt 0) {
                $bytes = [System.IO.File]::ReadAllBytes($LogPath)
                $startIndex = if ($FromByte -gt 0 -and $FromByte -lt $bytes.Length) { [int]$FromByte } else { 0 }
                $length = $bytes.Length - $startIndex

                if ($length -gt 0) {
                    $text = [System.Text.Encoding]::UTF8.GetString($bytes, $startIndex, $length)
                    if ($text -match $Pattern) {
                        return $true
                    }
                }
            }
        }

        Start-Sleep -Milliseconds 500
    }

    return $false
}
