# Demo Walkthrough

## Goal

Show isolated Stripe webhook testing for multiple local apps using one shared lab.

## Scenario

- App A (`demo-app-1`) runs on `http://localhost:3000`
- App B (`demo-app-2`) runs on `http://localhost:3001`
- Each app has a separate Stripe sandbox key

## Steps

1. Start listener for App A:

```powershell
.\scripts\Start-StripeListener.ps1 -AppName demo-app-1 -RootPath C:\stripe-lab
```

2. Start listener for App B:

```powershell
.\scripts\Start-StripeListener.ps1 -AppName demo-app-2 -RootPath C:\stripe-lab
```

3. Trigger event on App A:

```powershell
.\scripts\Test-StripeEvent.ps1 -AppName demo-app-1 -Event checkout.session.completed -RootPath C:\stripe-lab
```

4. Verify isolation:

- `logs\demo-app-1.log` contains the event
- `logs\demo-app-2.log` does not contain that event unless triggered explicitly for App B

## Expected Outcome

You can run concurrent local webhook listeners across repositories with explicit app-level isolation.
