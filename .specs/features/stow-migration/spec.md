# GNU Stow Dotfile Deployment Specification

## Problem Statement

The repository currently copies complete configuration files and directories into a user's home
and XDG configuration trees. Copying hides ownership, replaces whole directories, creates backup
state, and leaves the shared Zsh configuration dependent on machine-specific paths.

The repository SHALL deploy the same user-facing configuration paths through GNU Stow symlinks,
preserve unrelated files, and keep package installation outside the deployment command.

## Goals

- [ ] Deploy five selective GNU Stow packages with stable home and XDG targets.
- [ ] Preserve conflicts and unrelated files while making repeated deployment safe.
- [ ] Load prompt, completion, autosuggestion, and NVM dependencies through portable Zsh adapters.
- [ ] Prove the deployment contract with shell integration tests and executable documentation.

## Out of Scope

| Feature | Reason |
| --- | --- |
| Installing GNU Stow, Homebrew, apt, or other packages | Package installation is a separate manual workflow. |
| Linux package manifest or bootstrapper | No package-manager policy is defined for this repository. |
| Homebrew `Brewfile` | A future manual manifest can be added independently. |
| Stow `--adopt` migration | Local edits must be reviewed explicitly before entering the repository. |
| Generated application state | Only repository-managed configuration paths are in scope. |
| Removing recovery codes from Git history | Credential and history changes require separate authorization. |
| Concurrent deployment coordination | This remains a single-user command with sequential invocation assumed. |

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| No-argument invocation | Preserve the current behavior and deploy all five packages. | Existing callers depend on the no-argument command; explicit selectors remain available for safe selective deployment. | Assumed from current contract |
| Simulation entry point | `install.sh --simulate` delegates to Stow simulation and performs no local directory creation. | Users can preview the same selector contract without accidentally changing targets. | Assumed for this implementation |
| Stow version | GNU Stow 2.x with `--dir`, `--target`, `--dotfiles`, `--simulate`, and two-phase conflict detection. | These options are documented by GNU Stow and are the smallest stable interface needed here. | Confirmed by official manual |
| macOS dependency discovery | Prefer `HOMEBREW_PREFIX`, then `/opt/homebrew` and `/usr/local`, without invoking `brew`. | Apple Silicon and Intel Homebrew use different conventional prefixes; runtime discovery must remain local-only. | Assumed from platform conventions |
| Existing local configuration during first migration | Stow reports a conflict and leaves it untouched; the user performs any reviewed migration separately. | Automatic adoption or backup would reintroduce hidden ownership changes. | Confirmed by migration intent |
| Concurrent invocations | Unsupported; invocations are expected to run sequentially. | This is a local single-user command and no locking requirement was defined. | Assumed from migration document |

**Open questions:** none - all resolved or logged above.

## User Stories

### P1: Selective symlink deployment ⭐ MVP

**User Story**: As a dotfiles user, I want each configuration group deployed as a Stow package to
its existing user-facing path so that repository ownership is visible and selective deployment is
safe.

**Why P1**: This is the core migration and enables every other criterion.

**Acceptance Criteria**:

1. WHEN all five groups are explicitly selected with an empty temporary home and XDG configuration directory, THEN the deployment SHALL create symlinked paths for `~/.zshrc`, `~/.p10k.zsh`, `~/.tmux.conf`, `~/.tmux/plugins/catppuccin-tmux`, `$XDG_CONFIG_HOME/ghostty/config`, `$XDG_CONFIG_HOME/ghostty/themes`, `$XDG_CONFIG_HOME/herdr/config.toml`, and `$XDG_CONFIG_HOME/nvim`, with each path resolving into its corresponding repository package. (STOW-01)
2. WHEN `XDG_CONFIG_HOME` is unset, THEN configuration links SHALL resolve below `$HOME/.config`; WHEN it is set, THEN no configuration link SHALL be created below another hard-coded configuration directory. (STOW-02)
3. WHEN one or more package selectors are supplied, THEN the deployment SHALL create or change destinations only for the selected groups and SHALL leave the other four groups byte-for-byte unchanged. (STOW-03)
4. WHEN a managed destination already resolves to its repository package, THEN repeating the same deployment SHALL exit `0` and leave that symlink target unchanged. (STOW-04)

**Independent Test**: Run the wrapper with isolated HOME/XDG directories and inspect symlink targets
after an all-group run, selective run, and repeat run.

### P1: Safe local deployment ⭐ MVP

**User Story**: As a user migrating an existing machine, I want conflicts and prerequisites handled
before filesystem changes so that the command cannot silently replace local configuration.

**Why P1**: Safe failure behavior prevents the migration from repeating the current incident.

**Acceptance Criteria**:

5. IF a selected destination is an existing plain file or directory not owned by the repository, THEN the deployment SHALL report a conflict, exit non-zero, and leave that destination's content unchanged; `--adopt` SHALL never be implicit. (STOW-05)
6. WHEN the documented simulation command is run for selected packages, THEN it SHALL report planned link operations and SHALL make no filesystem changes. (STOW-06)
7. IF GNU Stow is unavailable, THEN the deployment SHALL report GNU Stow as the missing prerequisite, exit non-zero, and SHALL change no destination. (STOW-07)
8. WHEN `--help` is supplied, THEN the command SHALL print usage and exit `0`; IF an unknown option or positional argument is supplied, THEN it SHALL print usage, exit `2`, and change no destination or backup directory. (STOW-08)
9. WHEN deployment runs with failing stubs for package managers and network clients earlier in `PATH`, THEN the command SHALL invoke none of those stubs and SHALL remain local-only. (STOW-09)

**Independent Test**: Run the wrapper against isolated fixtures containing conflicts, missing Stow,
simulation mode, invalid arguments, and forbidden command stubs.

### P1: Portable Zsh startup ⭐ MVP

**User Story**: As a macOS or Linux user, I want shared Zsh configuration with platform-specific
dependency adapters so that prompt and shell conveniences load without invalid path errors.

**Why P1**: The migration is incomplete if the linked shell configuration breaks startup.

**Acceptance Criteria**:

10. WHEN the macOS adapter and Homebrew-provided Powerlevel10k and p10k configuration are present, THEN a fresh interactive Zsh sourcing the linked configuration SHALL define `p10k` and SHALL load the linked `~/.p10k.zsh` configuration. (ZSH-01)
11. WHEN the macOS adapter and installed optional shell tools are present, THEN a fresh interactive Zsh sourcing the linked configuration SHALL load autosuggestions and NVM, SHALL add the Homebrew zsh-completions path to `fpath`, and SHALL execute completion initialization. (ZSH-02)
12. WHEN the Linux adapter is selected without Homebrew, THEN a fresh interactive Zsh sourcing the linked common configuration SHALL avoid Homebrew path attempts, SHALL emit no source errors for absent optional dependencies, and SHALL retain the shared aliases. (ZSH-03)

**Independent Test**: Source linked configuration in isolated interactive Zsh processes with macOS
and Linux adapter fixtures and assert functions, variables, `fpath`, completion state, aliases, and
stderr.

### P1: Proven handoff ⭐ MVP

**User Story**: As a repository maintainer, I want tests and documentation to state the Stow
contract so that future changes do not restore copy-and-replace deployment.

**Why P1**: The deployment mechanism is user-facing and must remain discoverable and testable.

**Acceptance Criteria**:

13. WHEN the repository test commands are run, THEN `sh -n install.sh` and `sh tests/install_test.sh` SHALL both exit `0`, and the suite SHALL cover symlink targets, selective groups, repeat deployment, conflict preservation, simulation, missing Stow, and macOS/Linux Zsh startup probes. (PROOF-01)
14. WHEN a user reads `README.md`, THEN it SHALL document the package-to-destination mapping, explicit deployment examples, `$HOME` and `XDG_CONFIG_HOME` targets, Stow as a prerequisite, the separate package-installation boundary, simulation and recovery commands, and the fact that deployment does not install applications or dependencies. (PROOF-02)

**Independent Test**: Run both documented test commands and search the README for every required
deployment, prerequisite, boundary, simulation, and recovery instruction.

## Edge Cases

- IF a package source is missing, THEN Stow preflight SHALL fail before a selected destination is changed.
- IF a target contains a user-owned file or directory, THEN conflict handling SHALL preserve it.
- IF configuration targets do not exist, THEN normal deployment SHALL create only the required target parent directories.
- IF simulation is requested, THEN even target-parent creation SHALL be skipped.
- IF optional macOS or Linux dependencies are absent, THEN Zsh startup SHALL remain error-free.

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| STOW-01 | P1: Selective symlink deployment | Design | Verified |
| STOW-02 | P1: Selective symlink deployment | Design | Verified |
| STOW-03 | P1: Selective symlink deployment | Design | Verified |
| STOW-04 | P1: Selective symlink deployment | Design | Verified |
| STOW-05 | P1: Safe local deployment | Design | Verified |
| STOW-06 | P1: Safe local deployment | Design | Verified |
| STOW-07 | P1: Safe local deployment | Design | Verified |
| STOW-08 | P1: Safe local deployment | Design | Verified |
| STOW-09 | P1: Safe local deployment | Design | Verified |
| ZSH-01 | P1: Portable Zsh startup | Design | Verified |
| ZSH-02 | P1: Portable Zsh startup | Design | Verified |
| ZSH-03 | P1: Portable Zsh startup | Design | Verified |
| PROOF-01 | P1: Proven handoff | Design | Verified |
| PROOF-02 | P1: Proven handoff | Design | Verified |

**Coverage**: 14 total, 14 mapped to tasks, 0 pending.

## Success Criteria

- [x] `install.sh` exposes the same five selectors, adds simulation, and delegates all link work to GNU Stow.
- [x] User-owned target content remains unchanged on conflicts and no backup tree is created by deployment.
- [x] Linked macOS and Linux Zsh startup probes pass in isolated fixtures.
- [x] The documented shell syntax and integration test commands exit `0`.
