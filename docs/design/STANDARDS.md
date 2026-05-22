# Component-Repo Standards

Every idaptik component repo MUST conform to all four standards below.
The scaffold generator (`tools/scaffold-component.py`) produces a
conformant repo from these standards; manual creation MUST audit against
this checklist.

## 1. RSR template files

From `hyperpolymath/rsr-template-repo`. Each file's purpose and required
content sketch is below. When a file is generated, the generator writes
a stub with `TODO(scaffold)` markers; humans fill in component-specific
content before merge.

### Top-level files

| File | Purpose | Required content sketch |
|------|---------|--------------------------|
| `LICENSE` | License text | MPL-2.0 body |
| `SECURITY.md` | Security disclosure policy | Reporting address, response time |
| `CODE_OF_CONDUCT.md` | Behavioural norms | Contributor Covenant adapted |
| `CONTRIBUTING.md` | How to contribute | DCO, branch rules, review path |
| `README.adoc` | Project intro | Standalone status, what this repo does |
| `QUICKSTART-DEV.adoc` | Local dev setup | Toolchain install, first build |
| `QUICKSTART-USER.adoc` | End-user run | Container pull, launch |
| `QUICKSTART-MAINTAINER.adoc` | Maintainer ops | Release cut, version bump |
| `ROADMAP.adoc` | Forward plan | Quarter-resolution milestones |
| `EXPLAINME.adoc` | Pitch | One paragraph for non-experts |
| `TOPOLOGY.md` | Internal layout | Subdir purposes, dep graph |
| `AUDIT.adoc` | Recurring audit log | Append-only entries |
| `READINESS.md` | Production readiness | Per-criterion grade |
| `PROOF-NEEDS.md` | Outstanding proof obligations | Per-property table |
| `PROOF-STATUS.md` | Discharged proof state | Mirror of NEEDS |
| `TEST-NEEDS.md` | Test coverage targets | Per-component table |
| `TEMPLATE-STANDARDS-AUDIT.adoc` | Self-conformance to RSR | Pass/fail per standard |
| `CHANGELOG.md` | Keep-a-Changelog format | YYYY-MM-DD per release |
| `0-AI-MANIFEST.a2ml` | AI-agent contract | What agents may/must not do here |

### Dotfiles & directories

| Path | Purpose |
|------|---------|
| `.editorconfig` | Editor format defaults |
| `.gitattributes` | EOL + binary handling |
| `.gitignore` | Standard idaptik-ecosystem ignores |
| `.envrc` | direnv hook |
| `.tool-versions` | asdf pins |
| `.pre-commit-config.yaml` | Pre-commit hooks |
| `.well-known/` | Discovery metadata |
| `.github/` | CI workflows + ISSUE_TEMPLATE + PULL_REQUEST_TEMPLATE |
| `.gitlab-ci.yml` | GitLab parity if mirrored |
| `.guix-channel` | Guix channel metadata |
| `.devcontainer/` | Codespaces / VS Code container |
| `flake.nix` + `flake.lock` | Nix flake |
| `guix.scm` | Guix manifest |
| `setup.sh` | First-run idempotent setup |
| `docs/` | Component-specific docs (incl. `docs/design/` journal slice) |
| `scripts/` | Utility scripts |
| `tools/` | Build tooling |
| `examples/` | Examples |
| `tests/` | Test suite |
| `src/` | Source (per-language conventions inside) |

## 2. Stapeln container build

From `idaptik/stapeln.toml`. Every component:

* Uses `cgr.dev/chainguard/wolfi-base` (or `static`, `nginx`, `rust`) as the
  base image. **Never** `ubuntu`, `alpine` (untrusted), or `scratch` (loses
  Wolfi's security posture).
* Defines layers per phase: `*-base`, `*-deps`, `*-build`, `*-runtime`.
* `cache = true` on every cacheable layer with a `cache-key` rooted in the
  closest pinning artifact (`Cargo.lock`, `mix.lock`, `deno.lock`,
  `dune.lock`).
* Signs with `algorithm = "ML-DSA-87"`, `provider = "cerro-torre"`.
* Emits SPDX SBOM with `include-deps = true`.
* Runs as `user = "nonroot"` with `read-only-root = true`,
  `no-new-privileges = true`, `cap-drop = ["ALL"]`.
* Health checks every layer that exposes a port.
* Defines `[targets.{development, staging, production, test}]` profiles.
* Has a `Containerfile` at root for podman-build fallback when stapeln is
  unavailable; the Containerfile must produce a byte-identical runtime
  image.

## 3. Contractiles

From `idaptik/contractile.just` and the contractiles convention:

```
contractiles/
├── Dustfile.a2ml      # recovery & rollback actions
├── Intentfile.a2ml    # declared future intent
├── Mustfile.a2ml      # physical state invariants
└── Trustfile.a2ml     # integrity/provenance verification
```

`contractile.just` is regenerated from this directory by
`contractile gen-just --dir contractiles`. The generated file is
checked in; CI verifies it matches a fresh regeneration.

### Required `must-*` checks

Every component:

* `must-license-present` — `test -f LICENSE`
* `must-readme-present` — `test -f README.adoc || test -f README.md`
* `must-security-md` — `test -f SECURITY.md`
* `must-spdx-headers` — every source file has SPDX-License-Identifier
* `must-changelog-current` — CHANGELOG.md last entry within 90 days
* `must-stapeln-config` — `test -f stapeln.toml`
* `must-containerfile` — `test -f Containerfile`
* `must-no-banned-files` — no `Dockerfile`, `Makefile`, `package-lock.json`,
  `node_modules/`, `.env*`
* (component-specific) `must-{lang}-compiles` — language-specific

### Required `trust-*` checks

* `trust-license-content` — LICENSE contains SPDX identifier
* `trust-no-secrets-committed` — no `.env`, `credentials.json`,
  `.env.local`
* `trust-container-images-pinned` — Containerfile and stapeln.toml use
  `@sha256:` pins for all base images

## 4. 6a2 machine-readable state

From `idaptik/.machine_readable/6a2/`:

```
.machine_readable/6a2/
├── STATE.a2ml      # current state (component %, build/test status)
├── ECOSYSTEM.a2ml  # relational data (depends-on, used-by)
├── META.a2ml       # project metadata
├── AGENTIC.a2ml    # agent-facing capabilities
├── NEUROSYM.a2ml   # neurosymbolic integration
└── PLAYBOOK.a2ml   # operational runbooks
```

### STATE.a2ml minimum schema

```
[metadata]
project = "<name>"
version = "<semver>"
type = "<role>"
last-updated = "<YYYY-MM-DD>"
branch = "<git branch>"
build-status = "<status>"
test-status = "<status>"

[component-status]
# percentage completion per major subcomponent
<name> = { percent = <0-100>, notes = "<...>" }

[route-to-mvp]
remaining = [
  { item = "<...>", priority = "<low|medium|high>" }
]
```

### ECOSYSTEM.a2ml minimum schema

```
[depends-on]
# repos this component reads from
<dep-repo> = "<purpose>"

[used-by]
# repos that consume this one
<consumer-repo> = "<usage>"

[contracts]
# entries from idaptik-contracts this component imports
imports = ["<enum-name>", ...]
```

### Update discipline

* `must-state-current` invariant: STATE.a2ml `last-updated` within 30 days.
* CI fails on `last-updated` drift; humans must touch it on every release.
* Component completion percentages are *honest*: 100% means all PROOF-NEEDS
  discharged AND all TEST-NEEDS coverage met. Anything else is < 100%.

## Conformance audit

`tools/scaffold-component.py --audit <repo-path>` produces a pass/fail
report against this checklist. The audit runs as a CI job on every
component repo; failure blocks merge.

## Departures from the standards

A component MAY depart from a specific item if:

1. The departure is documented in the component's
   `TEMPLATE-STANDARDS-AUDIT.adoc` with rationale.
2. An ADR in the wrapper repo's `idaptik-developers` slice records the
   exception.
3. The audit tool is updated to recognise the documented exception.

This is rare. The default is conformance.
