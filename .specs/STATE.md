# Project State

## Decisions

| ID | Decision | Status |
| --- | --- | --- |
| AD-001 | GNU Stow is the repository's configuration deployment mechanism; package installation remains a separate workflow. | active |
| AD-002 | `packages/` contains one Stow package for each supported group: `zsh`, `tmux`, `ghostty`, `herdr`, and `nvim`. | active |
| AD-003 | `zsh` and `tmux` target `$HOME`; `ghostty`, `herdr`, and `nvim` target `${XDG_CONFIG_HOME:-$HOME/.config}`. | active |
| AD-004 | The deployment wrapper never invokes package managers or network clients, and never uses Stow `--adopt` implicitly. | active |
| AD-005 | Shared Zsh configuration sources a platform adapter; adapters discover optional dependency paths at shell startup. | active |

## Handoff

- Feature: `stow-migration`
- Status: stow-migration complete
- Next step: none
- Validation: `.specs/features/stow-migration/validation.md` PASS
- Branch: `main`
- Remote changes: none; local commits only
