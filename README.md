# Stripe Lab Multi-Repo (Windows Server 2025)

Laboratorio centralizzato per test locali Stripe su piu repository con Stripe CLI nativa e listener isolati per app.

## Struttura prevista

Il repository va clonato in `C:\stripe-lab`.

- `C:\stripe-lab\bin\`
- `C:\stripe-lab\config\apps.json`
- `C:\stripe-lab\scripts\`
- `C:\stripe-lab\logs\`
- `C:\stripe-lab\secrets\`
- `C:\stripe-lab\run\`

## Prerequisiti

1. PowerShell 7+
2. Stripe CLI installata
3. Accesso internet verso Stripe API
4. Chiavi test per ogni app/sandbox

Installazione Stripe CLI (consigliata):

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
scoop install stripe
stripe version
```

## Bootstrap ambiente

```powershell
cd C:\stripe-lab
.\scripts\Initialize-StripeLab.ps1 -RootPath C:\stripe-lab -LockDownAcl
```

## Configurazione app (`config/apps.json`)

Campi obbligatori per ogni app:

- `name` (univoco)
- `repo`
- `sandbox`
- `base_url`
- `webhook_path`
- `events` (array)
- `stripe_secret_env` (nome env var)
- `enabled` (boolean)

Esempio endpoint per FreeLance:
- `base_url`: `http://localhost:3000`
- `webhook_path`: `/api/webhooks/stripe`

## Segreti (mai in JSON)

Imposta una variabile ambiente per ogni app (solo `sk_test_*`):

```powershell
[Environment]::SetEnvironmentVariable("STRIPE_APP_FREELANCE_SK_TEST", "sk_test_xxx", "Machine")
[Environment]::SetEnvironmentVariable("STRIPE_APP_CLIENT_PORTAL_SK_TEST", "sk_test_xxx", "Machine")
[Environment]::SetEnvironmentVariable("STRIPE_APP_REDEMPTOR_HUB_SK_TEST", "sk_test_xxx", "Machine")
[Environment]::SetEnvironmentVariable("STRIPE_APP_ADMIN_CONSOLE_SK_TEST", "sk_test_xxx", "Machine")
```

Le script rifiutano chiavi `sk_live_*`.

## Comandi operativi

### Avvio listener singolo

```powershell
.\scripts\Start-StripeListener.ps1 -AppName freelance-web -RootPath C:\stripe-lab
```

### Avvio listener multipli

```powershell
.\scripts\Start-StripeListeners.ps1 -OnlyEnabled -RootPath C:\stripe-lab
```

### Stato ambiente

```powershell
.\scripts\Get-StripeStatus.ps1 -RootPath C:\stripe-lab
```

### Trigger evento su app specifica

```powershell
.\scripts\Test-StripeEvent.ps1 -AppName freelance-web -Event checkout.session.completed -RootPath C:\stripe-lab
```

### Stop listener

```powershell
.\scripts\Stop-StripeListeners.ps1 -AppName freelance-web -RootPath C:\stripe-lab
.\scripts\Stop-StripeListeners.ps1 -RootPath C:\stripe-lab
```

## Runtime files

- PID: `run\<app>.pid`
- Log: `logs\<app>.log`
- Error log: `logs\<app>.err.log`
- Webhook secret runtime: `secrets\<app>.webhook.secret`

## Onboarding nuova app

1. Crea sandbox dedicato in Stripe Dashboard.
2. Crea una env var Machine con `sk_test_*` della sandbox.
3. Aggiungi entry in `config/apps.json`.
4. Avvia listener con `Start-StripeListener.ps1`.
5. Copia il secret da `secrets\<app>.webhook.secret` nella configurazione dell'app target (`STRIPE_WEBHOOK_SECRET`).
6. Esegui `Test-StripeEvent.ps1` per convalida E2E.

## Troubleshooting rapido

- `Stripe CLI non trovato`: verifica PATH e `stripe version`.
- `Environment variable ... non impostata`: crea la env var indicata in `stripe_secret_env`.
- `Rifiutata chiave live`: stai usando `sk_live_*`; sostituisci con `sk_test_*`.
- `Webhook signature verification failed`: riallinea `STRIPE_WEBHOOK_SECRET` con il file in `secrets\` dopo restart listener.
- `404 endpoint`: correggi `base_url`/`webhook_path` e verifica che l'app sia in ascolto.
- `listener_log_match=false` in test evento: listener non attivo o evento non incluso in `events`.

## Sicurezza

- Solo modalita test in ambiente locale.
- Nessun secret nel repository.
- Cartella `secrets` esclusa dal versionamento.
- Log senza dump chiavi complete.
