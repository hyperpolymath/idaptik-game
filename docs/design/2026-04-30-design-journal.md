# Idaptik Migration Design Journal

Living journal of design decisions for the idaptik stabilisation +
modularisation + AffineScript port. Each entry is dated, signed (by
whoever made the call), and time-ordered. Nothing in here is retroactively
rewritten — corrections come as new entries that supersede earlier ones.

The journal is the source of truth for *why* decisions were made. ADRs
formalise the *what*. The two are complementary.

---

## 2026-04-30 — Migration kickoff

**Driver**: 2026-04-30 stabilisation synthesis identified six components in
"drifting" or "rotting" state, with three cross-cutting failure themes
(doc-vs-reality drift, hand-maintained contracts rot, build-config
orphaning). Concurrent driver: porting Rust → Rust+SPARK and
ReScript/TS/JS → AffineScript-compiling-to-typed-wasm. User has flagged
the game is broken and "needs to start working again."

**Call**: Recovery first, modularisation second, port third. Treat the
three as overlapping sequences not a strict pipeline — Recovery PR 1, 2,
3 are blocking; everything else can run in parallel after that.

**Trade-off**: A pure "port everything to AffineScript first" path was
considered and rejected. AffineScript's compiler is honest about
incomplete features (refinement types parse-only, effect-handler WASM
lowering incomplete, trait coherence partial); landing the port on top
of a broken ReScript baseline would conflate "port broke it" with
"baseline was already broken." Recovery first means port success is
attributable.

---

## 2026-04-30 — ADR-001: polyrepo + monorepo wrapper

**Driver**: All three audit failure themes trace structurally to monorepo
shape. Build-config orphaning, hand-maintained boundary contracts, and
doc concentration all decompose under polyrepo.

**Call**: Polyrepo per component, eclipse-drive wrapper at
`hyperpolymath/idaptik`. Mirrors existing `repos-monorepo` pattern.

**Trade-off**: Nine new repos to onboard. Mitigated by RSR template +
contractile + 6a2 boilerplate being scaffold-generated, not
hand-maintained per repo.

**See**: `adr/ADR-001-polyrepo-topology.adoc`.

---

## 2026-04-30 — idaptik-contracts as cross-component coupling layer

**Driver**: Audit theme #2 ("boundary contracts rot when hand-maintained;
generated contracts hold"). The role taxonomy desync is concrete proof:
LobbyChannel had `["hacker", "operator"]`, GameChannel had
`["hacker", "observer"]`, MultiplayerClient had its own string mapping.
Three places, three different answers.

**Call**: Single A2ML source of truth at
`idaptik-contracts/contracts.a2ml`. Codegen emits AffineScript modules,
Elixir module attribute, and typed-wasm region schemas. CI fails if the
generated tree is out of sync with the schema.

**Resolution of the role desync**: Canonical pair is
`Hacker | Counterpart`. Legacy wires `"operator"` and `"observer"` accepted
on the wire as aliases until v0.2.0, then removed.

**See**: `idaptik-contracts/contracts.a2ml`,
`idaptik-contracts/tools/codegen.py`.

---

## 2026-04-30 — ADR-002: VM is a DLC

**Driver**: User clarification that VM is "really just a DLC for the game",
and reviewing actual usage (only game and DLC packs consume the VM; other
components don't).

**Call**: VM types live in idaptik-contracts (cross-component); VM
implementation lives in `idaptik-dlc-vm` as a DLC the game loads. Other
DLC packs (`dlc-iky`, `dlc-reversibley`) collapse from "DLCs that
re-implement VM bits" into "DLCs that import dlc-vm and add data."

**Trade-off**: Game without dlc-vm is not a complete game. Accepted —
this has been true in practice for a long time.

**Procedural-gen corollary**: UMS's procedural-generation pipeline becomes
a DLC factory. UMS produces DLC packs as `dlc-manifest.json` artifacts
the game's existing DLC loader consumes. This is the smallest possible
bridge that unlocks UMS↔game integration with no game-side code changes.

**See**: `adr/ADR-002-vm-is-dlc.adoc`.

---

## 2026-04-30 — Recovery PR set sized for "make it work first"

**Driver**: User stated "it needs to start working again". The audit
already identified the four Tier-0 defects causing the breakage; making
those eight concrete, executable PRs makes recovery a finite job.

**Call**: Eight PRs documented in `docs/RECOVERY.adoc`. Critical path is
PRs 1 (restore shared/ from history), 2 (vm/rescript.json), 3 (orphan
.mjs imports). Estimated ~10 hours to a working game on the existing
ReScript stack. Remaining recovery PRs (4-8) parallel with early port
waves.

**Trade-off considered**: Fold recovery into the port — port shared/
directly to AffineScript without restoring the ReScript sources.
Rejected: AffineScript's compiler maturity makes a port-from-broken
risky. Recovery to ReScript-working baseline is a couple of hours;
porting 27 .res modules to AffineScript with a partial compiler is
multiple days.

**See**: `docs/RECOVERY.adoc`.

---

## 2026-04-30 — Component-repo standards: RSR template + stapeln + contractiles + 6a2

**Driver**: User stated each repo "should be completely capable of
standing alone, with whatever is needed in its container system, so that
you have the stapeln ... sitting on a chainguard image in podman."
Examination of `hyperpolymath/rsr-template-repo` shows ~50 required
top-level files; `idaptik/stapeln.toml` shows the 5-service Chainguard
layered build pattern; `idaptik/contractile.just` shows the
dust/intent/must/trust contractile invariant system; `idaptik/.machine_readable/6a2/`
holds STATE/ECOSYSTEM/META/AGENTIC/NEUROSYM/PLAYBOOK.

**Call**: Every component repo conforms to all four standards:

1. **RSR template** — every required top-level file present
   (LICENSE, SECURITY.md, CODE_OF_CONDUCT.md, CONTRIBUTING.md, README.adoc,
   QUICKSTART-{DEV,USER,MAINTAINER}.adoc, ROADMAP.adoc, EXPLAINME.adoc,
   TOPOLOGY.md, AUDIT.adoc, READINESS.md, PROOF-NEEDS.md, PROOF-STATUS.md,
   TEST-NEEDS.md, TEMPLATE-STANDARDS-AUDIT.adoc, CHANGELOG.md,
   `.editorconfig`, `.gitattributes`, `.gitignore`, `.envrc`,
   `.tool-versions`, `.pre-commit-config.yaml`, `.well-known/`,
   `.github/`, `.gitlab-ci.yml`, `0-AI-MANIFEST.a2ml`,
   `flake.nix`, `flake.lock`, `guix.scm`, `.guix-channel`,
   `.devcontainer/`, `setup.sh`).

2. **Stapeln** — `stapeln.toml` declares the layered Chainguard-based
   container build. Every service uses `cgr.dev/chainguard/{wolfi-base,static,nginx,rust}`
   bases, signs with ML-DSA-87 via cerro-torre, emits an SPDX SBOM, runs
   verification via vordr+svalinn, and runs as nonroot with read-only
   root filesystem. Targets cover {development, staging, production, test}.

3. **Contractiles** — `contractiles/` directory holds:
   - `Dustfile.a2ml` (recovery/rollback actions)
   - `Intentfile.a2ml` (declared future intent)
   - `Mustfile.a2ml` (physical state invariants — license, README,
     compiles-clean, tests-pass, SPDX headers, no banned files)
   - `Trustfile.a2ml` (integrity/provenance — secrets-not-committed,
     container-images-pinned, license content)
   `contractile.just` is auto-generated from these by
   `contractile gen-just --dir contractiles`.

4. **6a2 machine-readable state** — `.machine_readable/6a2/` holds:
   - `STATE.a2ml` (component completion %, build status, current phase)
   - `ECOSYSTEM.a2ml` (relational data: depends-on, used-by)
   - `META.a2ml` (project metadata that doesn't fit STATE)
   - `AGENTIC.a2ml` (agent-facing capability declarations)
   - `NEUROSYM.a2ml` (neurosymbolic integration points)
   - `PLAYBOOK.a2ml` (operational runbooks)

**Implementation**: Scaffold generator at
`tools/scaffold-component.py` produces a conformant new repo from a
component-name + description + role tuple. The four standards are *not*
copy-pasted per repo — they are generated from one parameterised
template per standard. Drift between component repos becomes a
"regenerate from template" PR, not nine independent edits.

**Trade-off**: Heavy boilerplate per repo. Mitigated by the scaffold
generator. The boilerplate is non-negotiable per user standards.

**See**: `tools/scaffold-component.py` (forthcoming),
component-repo READMEs.

---

## 2026-04-30 — Design journal location and discipline

**Driver**: User stated "make sure you are documenting design decisions
in a journal as we go held in the docs/design folder off root."

**Call**: Journal lives at `docs/design/YYYY-MM-DD-design-journal.md`
in this working tree, and is reproduced into each component repo's
`docs/design/` for any decision that affects that component. The
wrapper repo carries the canonical journal; component repos carry
their slice. ADRs link back to the relevant journal entry.

**Format**: Each entry has a date heading, a "Driver" (what forced the
decision), a "Call" (the decision), and either a "Trade-off" or a
"See" pointer. Entries are appended chronologically and never rewritten.
Corrections come as new entries citing the entry they supersede.

**Why journal AND ADR**: ADRs are the formal record of decisions — what
they are, what they replace, what they imply. The journal is the
running narrative — why each decision was forced at this time, what was
considered and rejected, what the user said. ADRs answer "what is the
rule"; journal answers "how did we get here." Both are needed because
the audit's failure theme #1 (doc-vs-reality drift) requires that
*reasoning* be auditable, not just *outcomes*.

---

## 2026-04-30 — Wave 1 VM port complete

**Driver**: Continuation of "go" directive. The VM port is the proof-of-pattern
for the rest of the AffineScript migration; finishing it inside one session
demonstrates the per-instruction modularity rule and surfaces concrete
upstream pressure points against the AffineScript compiler.

**Call**: All 23 instructions ported to per-instruction modules under
`idaptik-dlc-vm/src/instructions/`:

* Tier 0 (13): Add, Sub, Swap, Xor, Negate, Flip, Noop, Rol, Ror, And, Or,
  Mul, Div.
* Tier 1 (3): IfZero, IfPos, Loop.
* Tier 2 (4): Push, Pop, Load, Store.
* Tier 3 (1): Call.
* Tier 4 (2): Send, Recv.

`Step.affine` exhaustively dispatches; `Vm.affine` is the public API.
`dlc-manifest.json` declares the DLC contract.

**Trade-off**: Two compiler-gap markers in the code that we accept:

1. *TRefined predicates*. `And` and `Or` ancilla preconditions, and `Pop`'s
   `read_reg(reg) == 0` precondition, are runtime asserts today. These
   become type-level when the AffineScript compiler's TRefined predicate
   reduction lands (currently parse-only). Filed as upstream pressure in
   STATE.a2ml's `[upstream-pressure]` section.

2. *Effect-handler WASM lowering*. `State.affine` declares the VmState
   effect signature; the StateBackend handler is signature-only because
   AffineScript's effect-handler lowering to typed-wasm is incomplete.
   Same upstream-pressure filing.

Both gaps have the same shape: the language is honest about them in its
own README, and the VM port is the test case that puts them on the
critical path.

**Refactor opportunity taken**: `Sub.affine` is now `Add.backward` (and
vice versa). `Pop.affine` is `Push.backward` (and vice versa). `Ror.affine`
is `Rol.backward`. The ReScript port duplicated these implementations
because the language couldn't easily express "this instruction's forward
is that instruction's backward" — closures over different captured
state. The AffineScript port collapses the duplication: one place to fix
each direction, one place to change.

**See**: `idaptik-dlc-vm/src/instructions/*.affine`,
`idaptik-dlc-vm/src/Step.affine`, `idaptik-dlc-vm/src/Vm.affine`,
`idaptik-dlc-vm/dlc-manifest.json`,
`idaptik-dlc-vm/.machine_readable/6a2/STATE.a2ml`
(authoritative, includes upstream-pressure list).

---

## 2026-04-30 — Component scaffolds reified (3 deep, 5 minimum-viable)

**Driver**: Continuation of "go" directive. The whole-repo modularisation
needed at least one fully-scaffolded reference (idaptik-contracts) plus
one full second instance (idaptik-dlc-vm) plus minimum-viable scaffolds
for the rest so the polyrepo shape is concrete rather than aspirational.

**Call**:

| Repo | Depth | Files |
|------|-------|-------|
| `idaptik-contracts` | full | schema, codegen (3 targets), 4 contractiles, 6 6a2 files |
| `idaptik-dlc-vm` | full | 23 instructions + Step + Vm + dlc-manifest + stapeln + Containerfile + Justfile + 2 contractiles + 1 6a2 + README |
| `idaptik-game` | critical-floor | README + stapeln + Containerfile + Justfile + 2 contractiles + 2 6a2 |
| `idaptik-escape-hatch` | critical-floor | README + Cargo.toml + 1 SPARK spec + 1 6a2 |
| `idaptik-shared` | minimum | README + Justfile + 1 6a2 |
| `idaptik-ums` | minimum | README + 1 6a2 |
| `idaptik-sync` | minimum | README + 1 6a2 |
| `idaptik-dlc-iky` | minimum | README |
| `idaptik-dlc-reversibley` | minimum | README |
| `idaptik-wrapper` | full | TOPOLOGY + .gitmodules + Justfile + README |

**Trade-off**: Minimum-viable repos (shared, ums, sync, dlc-iky,
dlc-reversibley) lack the RSR template floor today. They depend on
`tools/scaffold-component.py` being run once Python is locally
available — which the toolchain probe showed it isn't. The scaffolds
are *partially* present (the most critical files for understanding the
intent) but require one batch run of the scaffold tool to reach
conformance.

This was the right trade because: a fully-typed-out template at every
repo would have produced ~256 boilerplate files in the session at the
cost of less actual content (Wave 1 VM port, contracts schema, recovery
plan). The boilerplate is *generated*, not *authored*; producing it
manually would burn signal for noise.

**See**: each repo's directory under `C:/dev/idaptik-port/`,
`docs/design/STANDARDS.md` for the four-floor specification,
`tools/scaffold-component.py` for the generator.

---

## 2026-04-30 — Recovery is decoupled from the polyrepo split

**Driver**: User stated "it needs to start working again" with urgency.
Conflating "make the existing monorepo work again" with "split into
polyrepo" risks the urgent goal slipping behind the architectural goal.

**Call**: Recovery PRs (1-8 in `docs/RECOVERY.adoc`) target the *current*
`hyperpolymath/idaptik` monorepo. They restore `shared/`, wire
`vm/rescript.json`, fix orphan `.mjs` imports, and unbreak UMS↔game.
They do *not* depend on any polyrepo repo existing.

The polyrepo split (the work in `idaptik-port/`) is a separate sequence
that begins with a working baseline. The two sequences are sequenced
but not coupled: each component repo starts empty until its
corresponding subdir of the working monorepo is mature enough to extract.

**Trade-off**: Two parallel work streams during the transition. Mitigated
by the fact that the polyrepo work is mostly *additive* (new repos with
new content) while recovery is *subtractive* (the current monorepo
should shrink as components extract).

---

## Open questions (to be closed in subsequent entries)

* **AffineScript compiler maturity for game port**. Wave 1 (dlc-vm)
  surfaces dependent-types/refinement gaps as upstream pressure. Wave 3
  (game) hits effect-handler-WASM gaps. Decision deferred until Wave 1
  produces concrete signal.

* **Rust+SPARK scope**. Per ADR-002 + user clarification, Rust may be
  near-zero in the final state (escape-hatch is the only Rust). Decision
  whether SPARK contracts apply to escape-hatch's parser kernels (yes)
  or to a hypothetical Rust dependency in idaptik-contracts codegen
  (probably no — Python is the codegen language for now). Defer until
  escape-hatch repo scaffold lands.

* **Cadre router future**. Existing cadre-router (Stage 6 complete in
  STATE.a2ml) is wired into navigation as a `.wasm` blob. Should it
  become its own component repo or fold into idaptik-game? Defer.

* **VeriSimDB and Burble integration**. Both have stapeln entries in
  the current monorepo but are external repos. Confirm they stay external;
  document the stapeln dependency contract in the wrapper TOPOLOGY.

* **Existing AffineScript title-screen/router** (per STATE.a2ml: stages 4-6
  complete). The game already has a small AffineScript surface
  (titlescreen.wasm 512B, router.wasm 915B). The port is therefore
  *expansion* of an existing AffineScript footprint, not a from-scratch
  addition. Sequencing implication: subsequent waves can study these
  for the in-tree ReScript↔AffineScript bridge pattern.
