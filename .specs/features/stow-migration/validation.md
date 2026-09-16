# stow-migration Validation

**Date**: 2026-09-16
**Spec**: `.specs/features/stow-migration/spec.md`
**Diff range**: `a843184..77332a4`
**Verifier**: standalone fresh-eyes fallback after delegated verifier timeout

## Validation: stow-migration - PASS ✅

**Spec-anchored check**: 14/14 acceptance criteria matched their specified outcomes; 0 precision gaps
**Gate**: 3 checks passed, 0 failed, 0 skipped
**Sensor**: 3 mutations injected, 3 killed, 0 survived
**Report**: `.specs/features/stow-migration/validation.md`

The environment does not have GNU Stow installed. The repository test suite uses an isolated
Stow-compatible fixture to verify wrapper behavior and separately verifies the missing-prerequisite
path. The production command remains a GNU Stow delegation wrapper.

## Task Completion

| Task | Status | Evidence |
| --- | --- | --- |
| T1 | ✅ Done | `0280aec` package-image migration |
| T2 | ✅ Done | `fec0a52` Zsh adapters and p10k package |
| T3 | ✅ Done | `d6cd6f0` Stow wrapper and integration suite |
| T4 | ✅ Done | `5297f20` README handoff |
| T5 | ✅ Done | `eead7bd` alias correction and assertion |
| T6 | ✅ Done | `77332a4` selector and directory-conflict coverage |

## Spec-Anchored Acceptance Criteria

| Requirement | Spec-defined outcome | `file:line` + assertion | Result |
| --- | --- | --- | --- |
| STOW-01 | All five selected groups resolve at the required home/XDG package paths. | `tests/install_test.sh:253` - `assert_resolves "$TEST_HOME/.zshrc" "$PROJECT_ROOT/packages/zsh/dot-zshrc"`; `tests/install_test.sh:258` - `assert_resolves "$TEST_CONFIG/ghostty/config" "$PROJECT_ROOT/packages/ghostty/ghostty/config"`; lines 254-261 cover the remaining destinations. | ✅ PASS |
| STOW-02 | Unset XDG uses `$HOME/.config`; set XDG uses the supplied directory. | `tests/install_test.sh:324` - `assert_resolves "$TEST_HOME/.config/herdr/config.toml" ...`; `tests/install_test.sh:325` - `assert_not_exists "$TEST_CONFIG"`; `install.sh:96` - `CONFIG_ROOT=${XDG_CONFIG_HOME:-$HOME/.config}`. | ✅ PASS |
| STOW-03 | Selected groups change only their destinations and repeated selectors remain additive. | `tests/install_test.sh:271` - `run_installer --zsh --ghostty --zsh`; lines 274-278 assert preserved and absent unselected destinations; lines 281-318 cover each selector. | ✅ PASS |
| STOW-04 | Repeating deployment preserves the existing repository symlink target and exits successfully. | `tests/install_test.sh:328-334` - captures `first_target`, reruns, and `assert_equal "$first_target" "$(readlink "$TEST_HOME/.zshrc")"`; line 334 asserts two successful Stow calls. | ✅ PASS |
| STOW-05 | User-owned files and directories produce a conflict and preserve content without adoption. | `tests/install_test.sh:347-353` - conflict output and `grep -Fq 'local zsh'`; `tests/install_test.sh:360-365` - directory marker preservation; `install.sh:120-122` contains no `--adopt`. | ✅ PASS |
| STOW-06 | Simulation reports link operations without creating destinations or state. | `tests/install_test.sh:379-387` - `assert_text_contains "$simulation_output" 'LINK'`, checks `--simulate`, `--verbose`, and absent targets; `install.sh:119-120` delegates simulation. | ✅ PASS |
| STOW-07 | Missing GNU Stow fails before any target changes and identifies the prerequisite. | `install.sh:98-100` - prerequisite preflight; `tests/install_test.sh:394-400` - asserts non-zero, `GNU Stow`, and absent targets. | ✅ PASS |
| STOW-08 | Help exits zero; unknown and positional arguments exit two without changes. | `install.sh:44-79` - parse branches; `tests/install_test.sh:417-443` - help text, status `2`, usage, and unchanged destinations. | ✅ PASS |
| STOW-09 | Package managers and network clients are not invoked. | `tests/install_test.sh:445-455` - forbidden stubs are installed and each marker is asserted absent; `install.sh:1-150` contains only local shell, filesystem, and Stow operations. | ✅ PASS |
| ZSH-01 | macOS startup defines `p10k` and loads linked p10k configuration. | `tests/zsh_test.sh:39-58` - links `.zshrc`/`.p10k.zsh`, creates Homebrew fixtures, and asserts `P10K_FUNCTION=1` and `P10K_MODE=nerdfont-v3`; `packages/zsh/dot-zshrc.d/macos.zsh:10-13` sources the theme. | ✅ PASS |
| ZSH-02 | macOS startup loads autosuggestions/NVM, adds completions to `fpath`, and initializes completion. | `tests/zsh_test.sh:52-60` - asserts `AUTOSUGGESTIONS=1`, `NVM=1`, `COMPLETIONS=1`, and the exact completions path; `packages/zsh/dot-zshrc.d/macos.zsh:17-37` implements the adapter. | ✅ PASS |
| ZSH-03 | Linux startup avoids Homebrew, emits no optional-source errors, and retains aliases. | `tests/zsh_test.sh:63-82` - Linux probe asserts alias output, no forbidden Homebrew marker, and empty stderr; `packages/zsh/dot-zshrc.d/linux.zsh:1-10` checks only user-local paths. | ✅ PASS |
| PROOF-01 | Documented syntax and integration commands exit zero and cover the required behaviors. | `README.md:140-148` documents `sh -n install.sh` and `sh tests/install_test.sh`; final run returned `0` with 18 top-level tests plus 2 nested probes; `tests/install_test.sh:462-504` enumerates the full suite. | ✅ PASS |
| PROOF-02 | README documents mapping, explicit commands, targets, prerequisite boundary, simulation, recovery, and no-install behavior. | `README.md:8-20` prerequisite boundary; `README.md:30-55` commands and simulation; `README.md:57-104` mapping/conflict/recovery; `README.md:106-158` targets and testing. | ✅ PASS |

## Discrimination Sensor

| Mutation | Scratch fault | Killed? |
| --- | --- | --- |
| 1 | Replaced `install.sh:96` XDG fallback with hard-coded `$HOME/.config`. The selector/XDG suite failed. | ✅ Killed |
| 2 | Reversed the `install.sh:139` simulation guard so simulation created the config parent. The read-only simulation test failed. | ✅ Killed |
| 3 | Changed `packages/zsh/dot-zshrc.d/macos.zsh:37` completion marker from `1` to `0`. The macOS startup probe failed. | ✅ Killed |

**Sensor depth**: lightweight, three isolated archive copies
**Result**: 3/3 killed - PASS ✅
**Isolation**: real-tree `git status --porcelain` matched the clean baseline after scratch cleanup.

## Code Quality

| Principle | Status |
| --- | --- |
| Minimum code | ✅ |
| Surgical changes | ✅ |
| No scope creep | ✅ |
| Matches existing patterns | ✅ |
| Spec-anchored outcomes | ✅ |
| Coverage expectation met | ✅ |
| Every test maps to a requirement or listed edge case | ✅ |
| README testing and repository shell conventions followed | ✅ |

## Edge Cases

- [x] Missing selected package fails before a destination changes: `tests/install_test.sh:403-414`.
- [x] User-owned file and directory conflicts preserve content: `tests/install_test.sh:344-365`.
- [x] Normal deployment creates the XDG parent; simulation does not: `install.sh:138-143`, `tests/install_test.sh:377-387`.
- [x] Optional macOS and Linux dependencies remain error-free when absent/present: `tests/zsh_test.sh:32-82`.
- [x] Sensitive `github/` content remains outside package deployment: `tests/install_test.sh:262`.

## Gate Check

- **Commands**: `sh -n install.sh`; `sh tests/install_test.sh`; `git diff --check`
- **Result**: 3 passed, 0 failed, 0 skipped
- **Test count before feature**: 18 top-level installer cases
- **Test count after feature**: 18 top-level installer cases plus 2 nested Zsh probes
- **Delta**: 0 top-level cases, +2 nested platform probes
- **Failures**: none

## Requirement Traceability Update

All 14 requirements are marked `Verified` in `spec.md`; all six tasks are marked complete in
`tasks.md`.

## Summary

**Overall**: ✅ Ready

**Spec-anchored check**: 14/14 criteria matched their specified outcomes; 0 precision gaps
**Sensor**: 3/3 mutations killed
**Gate**: 3/3 checks passed

**What works**: Stow package ownership, selective and repeat deployment, conflict safety, simulation,
missing-prerequisite handling, local-only behavior, portable Zsh startup, and complete README handoff.

**Issues found**: none remaining.

**Next steps**: Install GNU Stow on a target machine, preview with `./install.sh --simulate`, then
deploy explicitly selected packages.
