# Contributing to CopyLasso

Thank you for helping build CopyLasso. The project is still in early pre-release development, so focused changes that preserve the approved v0.1 scope are the easiest to review.

## Before Making a Change

- Read the [v0.1 product contract](docs/v0.1-product-contract.md) for supported behavior, privacy guarantees, and non-goals.
- Review the [development environment](docs/development-environment.md) and use the documented stable Xcode toolchain.
- Open an issue before starting a large feature, architectural change, new dependency, or product-scope change.
- Never include credentials, signing material, captured screen content, recognized private text, or other sensitive data in a commit, issue, test fixture, screenshot, or log.

## Development Expectations

- Keep each pull request small, cohesive, and limited to one clear purpose.
- Develop production behavior test-first. Add focused failing tests, confirm the expected failure, implement the smallest passing change, and run the relevant broader suite.
- Test success, failure, cancellation, boundary, and state-transition behavior introduced by the change.
- Use native Apple frameworks when they meet the requirement cleanly.
- Format Swift with the version bundled with Xcode: `xcrun swift-format`.
- Treat new compiler and analyzer warnings as failures.
- Update public documentation whenever user-visible behavior, requirements, privacy, or limitations change.

Some macOS behavior, including real privacy dialogs, global shortcut delivery, visual overlays, display capture, signing, notarization, and Gatekeeper checks, requires manual verification. Separate and automate the testable logic first, then describe the manual procedure and result in the pull request.

## Original Work and Privacy

Contributions must be original or compatible with the MIT License. Do not copy proprietary source code, private implementation details, branding, icons, screenshots, interface assets, website copy, or other protected material.

CopyLasso must never log, persist, or transmit screenshots, recognized text, clipboard text, or HUD preview text. Preserve the existing clipboard on every cancellation and failure path, and keep platform APIs behind testable boundaries where practical.

## Pull Requests

A pull request should explain:

- what changed and why;
- the tests and manual checks performed;
- any user-visible, privacy, security, or accessibility impact; and
- any remaining limitation or follow-up work.

Submit only green commits. Reviewers may ask for a change to be split if unrelated work makes the behavior or verification difficult to assess.

By contributing, you agree that your contribution is licensed under the repository's [MIT License](LICENSE).
