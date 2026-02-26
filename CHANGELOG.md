# Changelog

All notable changes to this project are documented in this file.

## [1.0.1] - 2026-02-26

### Fixed

- PowerShell 5.1 compatibility by removing direct dependence on `$IsWindows`.
- Improved listener diagnostics when `stripe listen` exits early.
- Safer log polling with file-lock handling during secret/event detection.
- `Test-StripeEvent.ps1` now fails fast if the target listener is not running.
- Removed `--print-secret` from listener startup to keep `stripe listen` process alive.

## [1.0.0] - 2026-02-26

### Added

- Initial Stripe Lab multi-repo demo scaffolding
- PowerShell command suite:
  - `Install-StripeCli.ps1`
  - `Initialize-StripeLab.ps1`
  - `Start-StripeListener.ps1`
  - `Start-StripeListeners.ps1`
  - `Stop-StripeListeners.ps1`
  - `Test-StripeEvent.ps1`
  - `Get-StripeStatus.ps1`
- Common module `StripeLab.Common.ps1`
- Central app registry contract in `config/apps.json`
- Community standards and contribution files
- GitHub CI workflow for JSON + PowerShell syntax validation
