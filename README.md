# library-shared-workflows

Reusable GitHub Actions workflows for Node and Go repositories. One caller job runs
the entire pipeline:

```
changes ──► node (matrix) ─┐
        ├─► go (matrix)   ─┼─► swagger (optional) ─► bump-version (optional)
        └─► security (opt)─┘
```

| Stage | Runs on | What it does |
| --- | --- | --- |
| `changes` | every event | Normalizes `projects`, filters by changed paths |
| `node` / `go` | every event | Lint & Format, Unit Tests (+ coverage report), Build — three parallel jobs per project |
| `security` | when `enable-security-scan` | Semgrep (SAST) and Gitleaks (secrets) |
| `swagger` | push / manual run on the default branch, when `enable-swagger` | Regenerates OpenAPI docs → GitHub Pages and/or commit |
| `bump-version` | push to the default branch, when `enable-bump-version` | Bumps, commits and tags the version |

## Quick start

1. Copy [`templates/ci.caller.yml`](templates/ci.caller.yml) to `.github/workflows/ci.yml` and fill in `projects`.
2. Optionally copy [`templates/bump-version.caller.yml`](templates/bump-version.caller.yml) to allow manual bumps.
3. Add the `APP_ID` / `APP_PRIVATE_KEY` secrets (see [Requirements](#requirements)).

```yaml
jobs:
  ci:
    uses: Fong0975/library-shared-workflows/.github/workflows/ci.yml@v1
    permissions:
      contents: read
      pull-requests: write
      pages: write
      id-token: write
    secrets:
      APP_ID: ${{ secrets.APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
    with:
      projects: |
        [{ "name": "app", "language": "node" }]
```

## Requirements

- **Permissions** – the calling job must grant `contents: read`, `pull-requests: write`,
  `pages: write` and `id-token: write`. GitHub validates the permissions of every nested
  job when the run starts, even for stages that are disabled, so all four are always needed.
- **Secrets** – pass each one explicitly under `secrets:` rather than with `secrets: inherit`,
  which hands every repository secret to the reusable workflow (Semgrep's `p/security-audit`
  also flags it as blocking).
  - `APP_ID`, `APP_PRIVATE_KEY`: a GitHub App (client ID and private key) with
    `contents: write` that is allowed to bypass the default branch's protection. Required by
    `bump-version` and by `swagger-publish: commit|both`; there is no `GITHUB_TOKEN` fallback.
  - `GITLEAKS_LICENSE`: only for repositories owned by a GitHub Organization.
- **GitHub Pages** – when `swagger-publish` includes `pages`, set *Settings → Pages → Source*
  to **GitHub Actions**.
- **Node test reports** – the default test command expects Vitest (or Jest-compatible JSON
  output) and the `json-summary` coverage reporter, which writes `coverage/coverage-summary.json`.

## `ci.yml` inputs

| Input | Default | Description |
| --- | --- | --- |
| `projects` | **required** | JSON array of projects, see [Projects](#projects) |
| `ignore-paths` | images, `LICENSE`, `.editorconfig`, … | JSON array of globs that never trigger a check |
| `default-branch` | `main` | Branch whose pushes run `swagger` and `bump-version` |
| `enable-security-scan` | `false` | Run Semgrep and Gitleaks |
| `semgrep-configs` | `p/security-audit p/owasp-top-ten` | Space-separated Semgrep configs; empty skips Semgrep |
| `enable-swagger` | `false` | Regenerate the Swagger documentation |
| `swagger-language` | `go` | `node` or `go` toolchain |
| `swagger-dir` | `.` | Directory the swagger commands run in |
| `swagger-install` | `""` | Command run before generating (e.g. `npm ci`) |
| `swagger-command` | `""` | Generate command, required when swagger is enabled |
| `swagger-output-dir` | `docs` | Output directory, relative to `swagger-dir` |
| `swagger-spec-file` | `swagger.json` | Document Swagger UI loads, relative to the output directory |
| `swagger-publish` | `pages` | `pages`, `commit` or `both` |
| `swagger-title` | `<repo> API Documentation` | GitHub Pages title |
| `swagger-paths` | `["**", "!**/*.md", "!.github/**"]` | A push regenerates only when one of these changed |
| `enable-bump-version` | `true` | Bump the version after a successful push |
| `bump-level` | `patch` | `patch` or `minor` for the automatic bump |
| `dependency-bump-level` | `patch` | Level used instead when the push only updates dependencies; `""` disables it |
| `dependency-paths` | `["**/package.json", "**/package-lock.json", "**/go.mod", "**/go.sum"]` | Dependency manifests checked by `dependency-bump-level` |
| `version-file` | `""` | Plain-text version file (e.g. `VERSION`); empty uses `package.json` |
| `npm-dirs` | `["."]` | Directories whose `package.json` receives the version (`[]` for none) |
| `npm-workspaces` | `[]` | npm workspaces (relative to the first `npm-dirs` entry) that receive the version |
| `node-version-file` | `<first npm-dir>/.nvmrc` | Node version used for `npm version` |
| `bump-paths` | `["**", "!**/*.md", "!.github/**"]` | A push bumps only when one of these changed |

## Projects

Each entry of `projects` describes one directory checked with one toolchain. Every field
except `name` and `language` is optional; setting a command to `""` skips that step, and a
job whose commands are all empty is skipped.

### Common fields

| Field | Default | Description |
| --- | --- | --- |
| `name` | **required** | Unique; letters, digits, `-`, `_`. Shown in check names and PR comments |
| `language` | **required** | `node` or `go` |
| `dir` | `.` | Working directory of every command |
| `paths` | `["<dir>/**"]` | Globs that select the project on pull requests (`!` excludes) |
| `env` | `{}` | Environment variables for every step (e.g. placeholder `DATABASE_URL`) |
| `format`, `lint`, `typecheck` | per language | Commands of the **Lint & Format** job |
| `test` | per language | Command of the **Unit Tests** job |
| `build` | per language | Command of the **Build** job |
| `test-results` | per language | Results file read by the report, relative to `dir` |
| `coverage-file` | per language | Coverage file read by the report, relative to `dir` |
| `coverage-threshold` | `0` | Minimum total coverage in percent; `0` disables the check |

### Node defaults

| Field | Default |
| --- | --- |
| `install` | `npm ci` |
| `format` | `npm run format:check` |
| `lint` | `npm run lint` |
| `typecheck` | `npm run typecheck` |
| `test` | `npm run test:coverage -- --reporter=default --reporter=json --outputFile.json=test-results.json` |
| `build` | `npm run build` |
| `node-version-file` | `<dir>/.nvmrc` |
| `cache` / `cache-dependency-path` | `npm` / `<dir>/package-lock.json` |
| `test-results` / `coverage-file` | `test-results.json` / `coverage/coverage-summary.json` |

For npm workspaces, keep `dir: "."` (one install at the root) and target the workspace in
the commands, e.g. `npm run lint -w client`.

### Go defaults

| Field | Default |
| --- | --- |
| `golangci-lint` | `latest` – golangci-lint version; `""` disables the action |
| `golangci-lint-args` | `--timeout=5m` |
| `format`, `lint`, `typecheck` | `""` |
| `test` | `go test ./... -v -race -coverprofile=coverage.out 2>&1 \| tee test-output.txt` |
| `build` | `go build ./...` |
| `go-version-file` | `<dir>/go.mod` |
| `cache-dependency-path` | `<dir>/go.sum` |
| `test-results` / `coverage-file` | `test-output.txt` / `coverage.out` |
| `coverage-exclude` | `""` – extended regex of cover-profile lines to drop before measuring |
| `env` | `{"CGO_ENABLED": "1"}` (needed by `-race`) |

## Behavior

### Change detection

- **pull_request** – only projects whose `paths` changed run; the others report as
  *skipped*, which satisfies required status checks. A PR touching `.github/workflows/**`
  runs everything. Security runs when any non-ignored file changed.
- **push** – every project runs; `swagger-paths` and `bump-paths` are matched against the
  pushed commits.
- **other events** (e.g. `workflow_dispatch`) – everything runs.

### Unit test reports

Each project's report (test counts, coverage and, when a threshold is set, the files or
functions below it) is written to the job summary and posted as a sticky PR comment keyed by
the project name. The job fails when total coverage is below `coverage-threshold`.

### Security

Semgrep fails only on findings introduced by the PR (`--baseline-commit`); other events scan
the whole repository. To schedule periodic full scans, add a `schedule` trigger to the caller.

### Swagger

Runs after every check passes on the default branch. `pages` deploys the output directory
plus a Swagger UI `index.html`; `commit` replaces the output directory on the default branch
and pushes `docs: regenerate swagger documentation [skip ci]` when it changed.

### Version bump

Reads the version from `version-file` (or the first `npm-dirs` `package.json`), increments
it, writes it to every configured location, then pushes
`chore: Bump version to vX.Y.Z [skip ci]` (body: the pushed commit titles, or the manual
notes) and the tag `vX.Y.Z`. `[skip ci]` prevents the commit from triggering CI again.

A push counts as a dependency update, and is bumped by `dependency-bump-level` instead of
`bump-level`, when every pushed commit was authored by `dependabot[bot]` or when only
`dependency-paths` files changed (ignoring `ignore-paths`). For example, with
`bump-level: minor` a feature merge bumps `1.4.0 → 1.5.0` while a Dependabot merge or a
lockfile-only fix bumps `1.5.0 → 1.5.1`. A `package.json` edit that changes only scripts
also counts as a dependency update.

For manual bumps, call `bump-version.yml` from a `workflow_dispatch` workflow
([template](templates/bump-version.caller.yml)); it also accepts `major`.

## Examples

### Single Next.js app (koukou)

```yaml
with:
  projects: |
    [{
      "name": "app",
      "language": "node",
      "env": {
        "NEXT_TELEMETRY_DISABLED": "1",
        "DATABASE_URL": "mysql://ci:ci@localhost:3306/koukou"
      },
      "coverage-threshold": 85
    }]
  enable-security-scan: true
  semgrep-configs: p/security-audit p/owasp-top-ten p/typescript p/react p/nextjs
```

### npm workspaces (tripdeck)

```yaml
with:
  projects: |
    [
      {
        "name": "client", "language": "node",
        "paths": ["client/**", "package.json", "package-lock.json", ".nvmrc", ".prettierrc.json", ".prettierignore"],
        "format": "npm run format:check",
        "lint": "npm run lint:check -w client",
        "typecheck": "",
        "test": "npm run test:coverage -w client",
        "build": "npm run build -w client",
        "test-results": "client/test-results.json",
        "coverage-file": "client/coverage/coverage-summary.json"
      },
      {
        "name": "server", "language": "node",
        "paths": ["server/**", "package.json", "package-lock.json", ".nvmrc"],
        "format": "",
        "lint": "npm run lint:check -w server",
        "typecheck": "",
        "test": "npm run test:coverage -w server",
        "build": "npm run build -w server",
        "test-results": "server/test-results.json",
        "coverage-file": "server/coverage/coverage-summary.json"
      }
    ]
  npm-workspaces: '["client", "server"]'
```

### Go backend + Node frontend with Swagger (word-flashcard)

```yaml
with:
  projects: |
    [
      {
        "name": "backend", "language": "go",
        "paths": ["**/*.go", "go.mod", "go.sum", ".golangci.yml"],
        "golangci-lint": "v2.12.2",
        "coverage-threshold": 60,
        "coverage-exclude": "word-flashcard/docs/docs\\.go|word-flashcard/(data|internal)/mocks/.*_mock\\.go"
      },
      {
        "name": "web", "language": "node", "dir": "web",
        "format": "",
        "lint": "npm run lint:check",
        "typecheck": "npm run type-check",
        "coverage-threshold": 80
      }
    ]
  enable-security-scan: true
  semgrep-configs: p/security-audit p/owasp-top-ten p/golang p/typescript p/react
  enable-swagger: true
  swagger-language: go
  swagger-command: go run github.com/swaggo/swag/cmd/swag@latest init
  swagger-paths: '["internal/**", "main.go"]'
  swagger-title: Word Flashcard API Documentation
  version-file: VERSION
  npm-dirs: '["web"]'
```

## Versioning

Callers reference `@v1`. Workflows and actions in this repository also reference each other
at `@v1`, so a change only takes effect for callers once the `v1` tag is moved:

```bash
git tag v1.x.y && git tag -f v1
git push origin v1.x.y && git push -f origin v1
```

Actions marked `# TODO: pin to a commit SHA` still reference a major tag and should be pinned.
