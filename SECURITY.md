# Security Policy

## Supported Use

This repository is intended for demo/local Stripe testing only.
Production use is out of scope.

## Reporting a Vulnerability

Please do not open public issues for security-sensitive findings.
Report privately to: security@cobracco.com

When reporting, include:

- Affected file(s)/script(s)
- Reproduction steps
- Expected vs actual behavior
- Potential impact

## Security Controls in This Project

- Test-key enforcement (`sk_test_*` required)
- Live-key rejection (`sk_live_*` blocked)
- Secrets loaded from environment variables only
- Runtime secrets/logs excluded from git

## Hardening Recommendations

- Restrict file ACLs on `secrets/`, `logs/`, and `run/`
- Rotate test keys regularly
- Avoid sharing full logs externally
