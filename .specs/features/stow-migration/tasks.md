# GNU Stow Dotfile Deployment Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill and follow its Execute flow and Critical
Rules. Each task is implemented, gated, marked complete, and committed before the next task starts.

**Design**: `.specs/features/stow-migration/design.md`
**Status**: Done

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec. Guidelines found: README testing section
> and existing `tests/install_test.sh`; no separate lint or coverage configuration was found.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| POSIX deployment wrapper | integration | Every selector, target split, idempotency, conflict, simulation, missing prerequisite, invalid input, and local-only edge case | `tests/install_test.sh` | `sh tests/install_test.sh` |
| Zsh runtime adapters | integration | macOS present-dependency startup, Linux absent-dependency startup, exact functions/variables/fpath/alias/stderr outcomes | `tests/zsh_test.sh` invoked by installer suite | `sh tests/zsh_test.sh` |
| Package images and documentation | none | Build and syntax validation only | `packages/`, `README.md` | `sh -n install.sh` and `git diff --check` |

## Gate Check Commands

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | Zsh runtime task | `sh tests/zsh_test.sh` |
| Full | Deployment wrapper task | `sh tests/install_test.sh` |
| Build | Package, documentation, or final feature gate | `sh -n install.sh`; `sh tests/install_test.sh`; `git diff --check` |

## Task Breakdown

### Phase 1: Package foundation

#### T1: Create non-Zsh Stow package images

**What**: Move tmux, Ghostty, Herdr, and Neovim configuration trees into `packages/` with Stow-compatible installation-image paths.
**Where**: `packages/`
**Depends on**: None
**Reuses**: `.tmux/`, `ghostty/`, `herdr/`, and `nvim/`
**Requirement**: STOW-01, STOW-02

**Tools**:

- MCP: NONE
- Skill: `tlc-spec-driven`

**Done when**:

- [x] `packages/tmux`, `packages/ghostty`, `packages/herdr`, and `packages/nvim` contain the existing tracked configuration content.
- [x] Dotfile package names map `.tmux.conf` and `.tmux/` through `--dotfiles` without exposing `github/`.
- [x] No configuration contents are changed during the move.
- [x] Gate passes: `git diff --check`.

**Tests**: none
**Gate**: build
**Commit**: `refactor(stow): create application package images`

### Phase 2: Shell runtime

#### T2: Add portable Zsh package and runtime adapters

**What**: Create the linked shared Zsh configuration, macOS/Linux adapters, reviewed p10k configuration, and isolated Zsh startup probes.
**Where**: `packages/zsh/`
**Depends on**: T1
**Reuses**: `terminal/.zshrc`, `/home/Leonardo/.p10k.zsh`, and existing Zsh integration conventions
**Requirement**: ZSH-01, ZSH-02, ZSH-03

**Tools**:

- MCP: NONE
- Skill: `tlc-spec-driven`

**Done when**:

- [x] Shared Zsh configuration retains the existing aliases and loads only the selected platform adapter.
- [x] The macOS adapter resolves Homebrew prefixes without invoking `brew`, loads p10k/autosuggestions/NVM when present, and records completion initialization after `compinit`.
- [x] The Linux adapter avoids Homebrew prefixes and suppresses absent optional dependency errors.
- [x] Reviewed p10k configuration is present as `packages/zsh/dot-p10k.zsh`.
- [x] `tests/zsh_test.sh` proves the macOS and Linux acceptance outcomes.
- [x] Gate passes: `sh tests/zsh_test.sh`.

**Tests**: integration
**Gate**: quick
**Commit**: `feat(zsh): add platform runtime adapters`

### Phase 3: Deployment contract

#### T3: Replace copy installer with Stow wrapper and integration suite

**What**: Replace copy/backup deployment with selector-aware GNU Stow delegation and rewrite the integration suite around symlink, conflict, simulation, prerequisite, and local-only outcomes.
**Where**: `install.sh`
**Depends on**: T2
**Reuses**: Existing selector interface and temporary fixture helpers in `tests/install_test.sh`
**Requirement**: STOW-01, STOW-02, STOW-03, STOW-04, STOW-05, STOW-06, STOW-07, STOW-08, STOW-09, PROOF-01

**Tools**:

- MCP: NONE
- Skill: `tlc-spec-driven`

**Done when**:

- [x] `install.sh` accepts `--simulate`, all five selectors, repeated selectors, and the existing no-argument all-groups behavior.
- [x] Real deployment preflights GNU Stow and selected package roots before changing targets, creates only the XDG target parent when not simulating, and never creates backups.
- [x] Stow receives explicit `--dir`, `--target`, and `--dotfiles` values for the correct selected package sets without `--adopt`.
- [x] `tests/install_test.sh` covers all STOW requirements, invokes the Zsh probes, and preserves the sensitive `github/` group outside deployment.
- [x] `sh -n install.sh` and `sh tests/install_test.sh` both exit `0`.

**Tests**: integration
**Gate**: full
**Commit**: `refactor(stow): delegate deployment to GNU Stow`

### Phase 4: User handoff

#### T4: Document Stow deployment and recovery

**What**: Update README installation, package mapping, prerequisites, simulation, recovery, XDG, and package-installation boundary instructions.
**Where**: `README.md`
**Depends on**: T3
**Reuses**: Existing quick-start and testing sections
**Requirement**: PROOF-02

**Tools**:

- MCP: NONE
- Skill: `tlc-spec-driven`

**Done when**:

- [x] README maps all five packages to their `$HOME` or `${XDG_CONFIG_HOME:-$HOME/.config}` destinations.
- [x] README documents explicit selector examples, `--simulate`, GNU Stow as a prerequisite, and no package-manager/network behavior.
- [x] README documents Stow delete commands as the recovery path and explains that local conflicts require explicit review.
- [x] Gate passes: `sh -n install.sh`, `sh tests/install_test.sh`, and `git diff --check`.

**Tests**: none
**Gate**: build
**Commit**: `docs(stow): document symlink deployment workflow`

### Phase 5: Corrective verification

#### T5: Preserve shared history alias expansion

**What**: Correct the shared Zsh history alias escaping and add an exact startup assertion for its value.
**Where**: `packages/zsh/dot-zshrc`
**Depends on**: T4
**Reuses**: Zsh startup probe in `tests/zsh_test.sh`
**Requirement**: ZSH-03

**Tools**:

- MCP: NONE
- Skill: `tlc-spec-driven`

**Done when**:

- [x] The `myhistory` alias preserves the `$2` field expansion when loaded by Zsh.
- [x] The startup probe asserts the exact alias value.
- [x] Gate passes: `sh tests/zsh_test.sh`.

**Tests**: integration
**Gate**: quick
**Commit**: `fix(zsh): preserve history alias expansion`

### Phase 6: Coverage hardening

#### T6: Restore selector and directory conflict coverage

**What**: Add focused tests for each selector, grouped Stow targets, repeated selectors, and user-owned directory conflicts.
**Where**: `tests/install_test.sh`
**Depends on**: T5
**Reuses**: Existing temporary Stow fixture and symlink assertions
**Requirement**: STOW-03, STOW-05, PROOF-01

**Tools**:

- MCP: NONE
- Skill: `tlc-spec-driven`

**Done when**:

- [x] Each of the five selectors has a focused isolated deployment assertion.
- [x] Repeated selectors invoke Stow once and leave the link correct.
- [x] A user-owned directory conflict preserves its marker content and prevents replacement.
- [x] The full suite reports 18 passing top-level tests and nested macOS/Linux probes.

**Tests**: integration
**Gate**: full
**Commit**: `test(stow): harden selector and conflict coverage`

## Execution Plan

Phases execute sequentially. Each phase completes before the next begins.

### Phase 1: Package foundation

```text
T1
```

### Phase 2: Shell runtime

```text
T2
```

### Phase 3: Deployment contract

```text
T3
```

### Phase 4: User handoff

```text
T4
```

### Phase 5: Corrective verification

```text
T5
```

### Phase 6: Coverage hardening

```text
T6
```

## Phase Execution Map

```text
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
T1      → T2      → T3      → T4      → T5      → T6
```

All task dependencies point backward across phases. Tasks execute sequentially; no sub-agent batch
is needed because the feature contains six tasks.

## Validation Tables

### Granularity

| Task | Scope | Status |
| --- | --- | --- |
| T1 | One package-layout migration | ✅ Granular |
| T2 | One Zsh runtime package and its probes | ✅ Cohesive |
| T3 | One deployment wrapper and its integration suite | ✅ Cohesive |
| T4 | One documentation handoff | ✅ Granular |
| T5 | One Zsh alias correction and assertion | ✅ Cohesive |
| T6 | One integration coverage hardening pass | ✅ Cohesive |

### Diagram-definition cross-check

| Task | Depends on | Diagram shows | Status |
| --- | --- | --- | --- |
| T1 | None | None | ✅ Match |
| T2 | T1 | T1 → T2 | ✅ Match |
| T3 | T2 | T2 → T3 | ✅ Match |
| T4 | T3 | T3 → T4 | ✅ Match |
| T5 | T4 | T4 → T5 | ✅ Match |
| T6 | T5 | T5 → T6 | ✅ Match |

### Test co-location validation

| Task | Code layer | Matrix requires | Task says | Status |
| --- | --- | --- | --- | --- |
| T1 | Package images | none | none | ✅ OK |
| T2 | Zsh runtime adapters | integration | integration | ✅ OK |
| T3 | POSIX deployment wrapper | integration | integration | ✅ OK |
| T4 | Documentation | none | none | ✅ OK |
| T5 | Zsh runtime adapters | integration | integration | ✅ OK |
| T6 | POSIX deployment wrapper | integration | integration | ✅ OK |

## Requirement Traceability

| Requirement | Task | Status |
| --- | --- | --- |
| STOW-01, STOW-02 | T1, T3 | Verified |
| STOW-03, STOW-04, STOW-05, STOW-06, STOW-07, STOW-08, STOW-09 | T3, T6 | Verified |
| ZSH-01, ZSH-02, ZSH-03 | T2, T3, T5 | Verified |
| PROOF-01 | T3, T6 | Verified |
| PROOF-02 | T4 | Verified |
