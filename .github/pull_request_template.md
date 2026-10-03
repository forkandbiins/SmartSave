## Prompt number

<!-- Link the SmartSave prompt or write its number. -->

## Summary

<!-- What changed and why? -->

## Files changed

<!-- List every changed file and explain any exception to the prompt allowlist. -->

## Checklist

- [ ] Prompt number and scope are documented.
- [ ] Only allowlisted files changed.
- [ ] `flutter analyze` passes in every affected Flutter package.
- [ ] `flutter test` passes in every affected Flutter package.
- [ ] Boundary grep checks pass.
- [ ] No UI import uses `package:smartsave_backend/src`.
- [ ] No UI import uses a BLE plugin or `permission_handler`.
- [ ] Public API or protocol documentation is updated when needed.
