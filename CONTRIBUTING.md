# Contributing

Thanks for contributing to Prowl.

## Development Setup

1. Use Xcode 26.3+ (Swift 6.2).
2. Clone the repo and run:

```bash
swift test
```

3. For iOS package compatibility checks:

```bash
xcodebuild \
  -scheme Prowl-Package \
  -destination "generic/platform=iOS Simulator" \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO \
  IPHONEOS_DEPLOYMENT_TARGET=15.0 \
  build
```

## Pull Request Guidelines

- Keep changes focused and reviewable.
- Add or update tests for behavior changes.
- Avoid exposing new public API unless necessary.
- Update `README.md` and `CHANGELOG.md` for user-facing changes.

## Release Process

- Follow the release checklist in `README.md`.
- Keep `Sources/ProwlKit/Prowl.swift` version aligned with the release tag.
- Use immutable annotated tags.
