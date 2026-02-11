# Contributing

Thanks for contributing to `coderabbit-fixer`.

## Development Setup

1. Clone the repository.
2. Install required tools: `gh`, `jq`, `python3`, `shellcheck`.
3. Optional: install `bun` to validate Bun runtime behavior.

## Validate Changes

Run all local checks before opening a PR:

```bash
./tests/run.sh
shellcheck -x bin/_cr_dispatch.sh bin/cr-gather bin/cr-next bin/cr-status bin/cr-done bin/cr-metrics runtime/bash/cr-gather runtime/bash/cr-next runtime/bash/cr-status runtime/bash/cr-done runtime/bash/cr-metrics install.sh tests/cr-gather-fixtures.sh tests/runtime-parity.sh tests/cr-state-tools.sh tests/runtime-dispatch.sh tests/run.sh
python3 -m py_compile runtime/python/_dispatch.py runtime/python/cr-gather runtime/python/cr-next runtime/python/cr-status runtime/python/cr-done runtime/python/cr-metrics
```

## PR Guidelines

1. Keep changes focused and atomic.
2. Add or update tests for behavior changes.
3. Update docs (`README.md`, `docs/`) when UX or behavior changes.
4. Avoid breaking CLI compatibility unless explicitly discussed.
5. Use clear commit messages describing user-visible impact.

## Runtime Expectations

Each runtime (`bash`, `python`, `bun`) must provide executable entrypoints for:
- `cr-gather`
- `cr-status`
- `cr-next`
- `cr-done`
- `cr-metrics`

If you add a new command, update:
- `bin/`
- `runtime/*/`
- `tests/runtime-parity.sh`
- `tests/runtime-dispatch.sh`
