# Contributing

Thanks for contributing.

## Prerequisites

- Windows (recommended for runtime validation)
- PowerShell 7+
- Stripe CLI

## Development Flow

1. Fork and clone the repository.
2. Create a feature branch.
3. Keep changes focused and documented.
4. Run checks locally where possible.
5. Open a Pull Request using the provided template.

## Pull Request Checklist

- [ ] No secrets/API keys committed
- [ ] README/docs updated when behavior changes
- [ ] `config/apps.json` remains valid JSON
- [ ] Scripts remain compatible with PowerShell 7+
- [ ] CI checks pass

## Coding Guidelines

- Prefer clear, defensive PowerShell.
- Fail fast on invalid input.
- Keep paths configurable through `-RootPath` and/or `STRIPE_LAB_ROOT`.
- Do not introduce production shortcuts.

## Commit Style

Use conventional-style messages when possible:

- `feat: ...`
- `fix: ...`
- `docs: ...`
- `ci: ...`
- `chore: ...`
