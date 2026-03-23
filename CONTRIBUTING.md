# Contributing

Thanks for contributing to Prompt-Preflight.

## Development Setup

1. Use macOS 14+ with Xcode 16+ (or Swift 6.2 toolchain).
2. Clone the repo.
3. Build once:

```bash
swift build
```

4. Run tests:

```bash
swift test
```

## Workflow

1. Create a branch from `main`.
2. Keep changes scoped to one concern.
3. Add or update tests when behavior changes.
4. Run `swift test` before opening a PR.
5. Open a pull request with a clear summary and testing notes.

## Pull Request Checklist

- [ ] Builds successfully with `swift build`
- [ ] Tests pass with `swift test`
- [ ] No unrelated file changes
- [ ] README/docs updated if behavior changed

## Code Style

- Follow existing Swift style in the repository.
- Prefer small, focused functions and explicit naming.
- Avoid introducing new dependencies unless necessary.

## Reporting Issues

Open an issue with:

- Expected behavior
- Actual behavior
- Reproduction steps
- macOS version, Swift/Xcode version
- Logs/screenshots if relevant
