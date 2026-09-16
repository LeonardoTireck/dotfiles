# Migrate dotfiles deployment to GNU Stow

> Build this with **tlc-implement**.
> Every criterion below becomes a check with a proof, referenced by its number. Nothing under
> `Unresolved` gets settled while building.

## Intent

The current `install.sh` copies complete files and directories into the user’s home and XDG
configuration trees. A no-argument run replaces all five groups, whole-directory replacement hides
user-owned files in backups, and the tracked Zsh configuration can silently skip dependencies when
their machine-specific paths do not exist. The cost is broken shell startup plus avoidable recovery
work; the latest incident left the p10k theme implementation untouched but stopped loading it.

When this ships, the repository-managed configuration appears at the same user-facing paths through
symlinks, while unrelated and generated files remain in place. The deployment command only links
configuration; package installation remains a separate, manually invoked concern. Zsh keeps common
configuration in the shared package and resolves platform-specific dependency locations in small
runtime adapters.

14 criteria in 4 slices · 4 one-way doors · 3 open, of which 0 block

## Criteria

### Package layout and ownership

1. Given an empty temporary home and an `XDG_CONFIG_HOME` directory, when all five explicit groups
   are deployed, then `~/.zshrc`, `~/.p10k.zsh`, `~/.tmux.conf`,
   `~/.tmux/plugins/catppuccin-tmux`, `$XDG_CONFIG_HOME/ghostty/config`,
   `$XDG_CONFIG_HOME/ghostty/themes`, `$XDG_CONFIG_HOME/herdr/config.toml`, and
   `$XDG_CONFIG_HOME/nvim` exist as symlinks resolving into the corresponding repository package.
2. Given `XDG_CONFIG_HOME` is unset, when the configuration-target groups are deployed, then their
   links resolve below `$HOME/.config`; given it is set, no configuration link is created below a
   different hard-coded config directory.
3. Given a package selector is supplied, when deployment runs, then only the selected group’s
   destinations are created or changed; the other four groups’ destinations remain byte-for-byte
   unchanged.
4. Given a managed destination already points to its repository package, when the same deployment
   is run again, then it exits successfully and leaves the existing symlink target unchanged.

### Safe deployment command

5. Given a selected destination is an existing plain file or directory not owned by the repository,
   when deployment is simulated or run, then it reports a conflict and leaves that destination’s
   content unchanged; `--adopt` is never implicit.
6. Given the selected packages and targets, when the documented Stow simulation command is run,
   then it reports the planned link operations and makes no filesystem changes.
7. Given Stow is unavailable, when the deployment command is run, then it exits non-zero before
   changing any destination and identifies Stow as the missing prerequisite.
8. Given `--help`, an unknown option, or a positional argument, when the deployment command runs,
   then help exits `0`, invalid invocation exits `2`, and no destination or backup directory is
   changed.
9. When the deployment command runs under a PATH containing failing stubs for package managers and
   network clients, then none of those commands is invoked and deployment remains local-only.

### Cross-platform Zsh runtime

10. Given the macOS runtime adapter and the Homebrew-provided Powerlevel10k and p10k configuration
    are present, when a fresh interactive Zsh sources the linked configuration, then the `p10k`
    function exists and the linked `~/.p10k.zsh` is the active prompt configuration.
11. Given the macOS runtime adapter and the installed optional shell tools are present, when a fresh
    interactive Zsh sources the linked configuration, then autosuggestions and NVM load, and the
    Homebrew zsh-completions path is present in `fpath` with completion initialization executed.
12. Given a Linux runtime without Homebrew, when a fresh interactive Zsh sources the linked common
    configuration and Linux adapter, then it does not attempt `/opt/homebrew` paths, does not emit
    source errors for absent optional dependencies, and still loads the shared aliases.

### Proof and documentation

13. When the repository test commands run, `sh -n install.sh` and `sh tests/install_test.sh` both
    exit `0`, and the test suite covers symlink targets, selective groups, repeat deployment,
    conflict preservation, simulation, missing Stow, and the macOS/Linux Zsh startup probes.
14. When a user reads `README.md`, it documents the package-to-destination mapping, the exact
    explicit deployment examples, the `$HOME` and `XDG_CONFIG_HOME` targets, Stow as a prerequisite,
    the separate package-installation boundary, simulation/recovery commands, and the fact that
    deployment does not install applications or dependencies.

## Out of scope

- Installing or invoking Homebrew, apt, dnf, pacman, or any other package manager from the
  deployment command - package installation remains a separate workflow.
- Defining a Linux package manifest or implementing a package manager bootstrapper.
- Defining or invoking a Homebrew `Brewfile`; a future manual manifest can be added without changing
  the Stow deployment contract.
- Managing generated application state such as Neovim lock/state files, Herdr sockets/logs, or
  Ghostty runtime state unless it is already a repository-managed configuration path.
- Automatically importing local edits with Stow `--adopt`; first migration remains an explicit,
  reviewed operation.
- Removing or rewriting `github/github-recovery-codes.txt` from Git history until the unresolved
  security decision is answered.

## Observable

| Surface | Decision | Landing |
|---|---|---|
| command `install.sh [selectors]` | selected groups map to the correct home/config targets | 1, 2, 3 |
| command `install.sh [selectors]` | repeat, conflict, simulation, missing prerequisite, and invalid invocation behavior | 4-9 |
| command `stow` simulation | planned operations are visible without filesystem changes | 6 |
| interactive Zsh startup on macOS | p10k, autosuggestions, NVM, and completions load from the macOS adapter | 10, 11 |
| interactive Zsh startup on Linux | common configuration remains usable without Homebrew paths | 12 |
| collection `packages/` | package names and link destinations are stable and selective | 1-4 |
| document `README.md` | users can install, preview, recover, and understand the package boundary | 14 |
| screen or view | n/a - no screen is changed |
| API or webhook | n/a - no API is exposed |

## Swept

- validation: 1, 2, 3, 5, 7, 8
- failure modes: 5, 7, 8, 9, 12
- idempotency and retry: 4
- authorization: n/a - this is a local single-user filesystem command
- concurrency and ordering: Unresolved 3
- data lifecycle: n/a - no application data or persistent schema is changed
- external-dependency failure: 7, 10, 11, 12
- state transitions: 1, 4, 5
- observability: 6, 7, 8, 13, 14

## Impact

| Front | What changes |
|---|---|
| deployment command | existing `install.sh` changes from copy/backup deployment to a link-only Stow wrapper; callers of its selectors, help, and exit codes are affected |
| repository layout | `term/.zshrc`, `.tmux/`, `ghostty/`, `herdr/`, and `nvim/` move into explicit Stow packages under `packages/` |
| live configuration | managed destinations change from regular files/directories to symlinks into the repository; unrelated runtime files remain outside package ownership |
| Zsh configuration | the monolithic `term/.zshrc` becomes shared configuration plus platform adapters; `.p10k.zsh` becomes repository-managed after review of the restored local file |
| tests | copy and backup assertions in `tests/install_test.sh` change to assert symlink ownership, conflict safety, target selection, and real Zsh startup behavior |
| documentation | README installation, recovery, prerequisite, XDG, and package-boundary instructions change to match Stow |
| stored data | nothing to migrate; one-time live-file migration must preserve the existing backup/safety snapshot before links are created |

## Decided

| Decision | Shape | Alternative rejected |
|---|---|---|
| configuration deployment | GNU Stow packages with symlinks, driven by `install.sh` as a thin wrapper | copy-and-replace installer, because it replaces whole trees and obscures ownership of live files |
| package layout | `packages/` contains one package per current group: `zsh`, `tmux`, `ghostty`, `herdr`, and `nvim` | one undifferentiated home snapshot, because selective group deployment and ownership boundaries would be lost |
| deployment targets | one Stow invocation targets `$HOME` for `zsh`/`tmux`; another targets `${XDG_CONFIG_HOME:-$HOME/.config}` for `ghostty`/`herdr`/`nvim` | embedding `dot-config` under a single `$HOME` target, because it would break the repository’s existing `XDG_CONFIG_HOME` behavior |
| package installation boundary | no package manager or network command is called by `install.sh` or Stow deployment | combined bootstrap/install command, because macOS and Linux package management is intentionally outside this implementation |
| platform-specific runtime handling | shared Zsh configuration sources a platform adapter; the adapter resolves dependency locations at shell startup | Homebrew path handling in Stow or the deployment script, because those tools only own repository-to-target links |
| prompt configuration ownership | reviewed `~/.p10k.zsh` is added as `packages/zsh/dot-p10k.zsh` and linked to `~/.p10k.zsh` | leaving p10k configuration machine-only, because the prompt appearance would not be reproducible from the repository |

## Sources

- Conversation decision (2026-09-16) - **binding**: “Stow is the cross-platform configuration deployment mechanism; package installation is separate; platform-specific dependency discovery lives in small configuration adapters.”
- Conversation clarification (2026-09-16) - **binding**: package installation is not part of this implementation, and Homebrew’s installation paths are not handled by the deployment command or Stow.
- [install.sh](/Users/leonardotireck/Documents/myDotFiles/install.sh) - current selector, XDG target, backup, copy, and rollback behavior being replaced.
- [term/.zshrc](/Users/leonardotireck/Documents/myDotFiles/term/.zshrc) - current path assumptions and optional-source behavior being split into common and platform-specific runtime configuration.
- [README.md](/Users/leonardotireck/Documents/myDotFiles/README.md) - current installation, backup, dependency, and XDG contract that must be amended.
- [tests/install_test.sh](/Users/leonardotireck/Documents/myDotFiles/tests/install_test.sh) - current dependency-free installer coverage to be replaced or extended.
- [GNU Stow manual: invoking Stow](https://www.gnu.org/software/stow/manual/html_node/Invoking-Stow.html) - `--dotfiles`, `--simulate`, `--target`, and the explicit warning attached to `--adopt`.
- [GNU Stow manual: conflicts](https://www.gnu.org/software/stow/manual/html_node/Conflicts.html) - two-phase conflict detection before filesystem operations.

## Unresolved

| # | Kind | Question | Until answered |
|---|---|---|---|
| 1 | open | Should a no-argument `install.sh` run all five packages, or require at least one explicit selector? **Recommended: require an explicit selector and provide a separate `--all`/documented command**, because the incident showed that implicit whole-machine replacement is easy to trigger. | Criteria 1-3 use explicit selectors; no-argument behavior remains unchanged until confirmed. |
| 2 | open | Should this task remove `github/github-recovery-codes.txt` from tracking/history and trigger credential rotation? **Recommended: yes, but authorize it separately because it changes Git history and credentials.** | The file remains outside this task’s criteria and is called out in `Out of scope`. |
| 3 | open | Should concurrent deployment invocations be supported or explicitly unsupported? **Recommended: unsupported and documented for this single-user command.** | No concurrency guarantee is added; sequential invocation is assumed. |
