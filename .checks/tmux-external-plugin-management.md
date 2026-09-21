# External TPM Bootstrap for tmux Plugins

Sources:

- `.specs/features/tmux-external-plugin-management/spec.md` - binding requirements, boundaries, edge cases, and acceptance criteria
- [TPM installation and plugin-management workflow](https://github.com/tmux-plugins/tpm#installation) - binding external bootstrap path and `prefix + I` behavior
- [tmux-resurrect installation with TPM](https://github.com/tmux-plugins/tmux-resurrect#installation-with-tmux-plugin-manager) - binding plugin declaration and acquisition workflow

## Out of scope

- Automatic TPM installation by `install.sh` - the installer keeps its local-only, no-network contract.
- Vendoring TPM or `tmux-resurrect` - TPM owns upstream plugin lifecycle.
- Automatic plugin updates or tmux-resurrect save-file synchronization - those remain external TPM/user-data concerns.
- Changes to tmux-resurrect behavior, save location, or key bindings - this feature only defines acquisition and loading.

## Landing

The change touches the tmux configuration, the local Stow installer contract, and the root README. It reuses GNU Stow for repository-owned files and TPM for upstream plugin checkouts instead of duplicating either lifecycle.

| One-way door | Literal shape | Alternative rejected |
| --- | --- | --- |
| Catppuccin ownership boundary | `run '~/.tmux/plugins/catppuccin-tmux/catppuccin.tmux'`; no Catppuccin `@plugin` declaration | TPM-managed Catppuccin checkout - it duplicates the repository-owned source and makes ownership ambiguous |
| TPM bootstrap boundary | README instructs `git clone ... "$HOME/.tmux/plugins/tpm"` before `./install.sh --tmux` and `prefix + I` | Installer bootstrap - it would violate the existing no-network/no-package-manager contract |
| Stow plugin-root topology | tmux deployment uses Stow `--no-folding`, leaving `$HOME/.tmux/` real and linking repository-owned files below it | Default directory folding - it would make external TPM checkouts resolve inside the repository through a `$HOME/.tmux` symlink |

- Nothing else in this change is hard to reverse.

## Checks

### S1 - External ownership, loading, and local deployment · 2 source files · 5,937 bytes · ~1.5k

**C1** - The repository contains neither a `tpm/` nor a `tmux-resurrect/` source directory under the tmux plugin package.
Proof: `sh tests/tmux_external_plugin_management_test.sh no_vendored_plugin_sources`

**C2** - The tmux configuration declares exactly `tmux-plugins/tpm` and `tmux-plugins/tmux-resurrect` as TPM plugins.
Proof: `sh tests/tmux_external_plugin_management_test.sh external_plugin_declarations`

**C3** - The tmux configuration loads the repository-owned Catppuccin entrypoint from `~/.tmux/plugins/catppuccin-tmux/catppuccin.tmux` without declaring Catppuccin as a TPM plugin.
Proof: `sh tests/tmux_external_plugin_management_test.sh local_catppuccin_entrypoint`

**C4** - `run '~/.tmux/plugins/tpm/tpm'` is the final non-comment tmux configuration command.
Proof: `sh tests/tmux_external_plugin_management_test.sh tpm_is_final_command`

**C5** - A successful `./install.sh --tmux` deploys `.tmux.conf` and a real `$HOME/.tmux/` directory containing the Stow-managed Catppuccin package into an isolated `$HOME`.
Proof: `sh tests/tmux_external_plugin_management_test.sh stow_deploys_tmux_package`

**C6** - The tmux deployment invokes no Git, network client, or package-manager command.
Proof: `sh tests/tmux_external_plugin_management_test.sh stow_is_local_only`

**C7** - With TPM present at `$HOME/.tmux/plugins/tpm`, loading the deployed configuration exposes the TPM prefix control in a running tmux server.
Proof: `sh tests/tmux_external_plugin_management_test.sh tpm_runtime_controls`

**C8** - Pressing the configured `prefix + I` control creates the external `tmux-resurrect` checkout and records the tmux environment refresh in the isolated TPM fixture.
Proof: `sh tests/tmux_external_plugin_management_test.sh tpm_runtime_controls` (binding); `sh tests/tmux_external_plugin_management_test.sh prefix_i_installs_external_plugin` (attached-client install/reload action); `sh tests/tmux_external_plugin_management_test.sh real_tpm_fetches_external_plugin` (real TPM fetch)

**C9** - Repeating tmux deployment succeeds without duplicate plugin paths, and deployment does not remove an existing external `tmux-resurrect` checkout.
Proof: `sh tests/tmux_external_plugin_management_test.sh deployment_is_idempotent`

**C10** - A conflicting user-owned `.tmux.conf` or Catppuccin entrypoint remains unchanged while Stow reports a non-zero conflict.
Proof: `sh tests/tmux_external_plugin_management_test.sh stow_preserves_conflicts`

**C16** - Repeating `prefix + I` retains exactly one external `tmux-resurrect` checkout while reloading the tmux environment again.
Proof: `sh tests/tmux_external_plugin_management_test.sh prefix_i_installs_external_plugin`

**C17** - Removing `tmux-resurrect` from the plugin list and redeploying does not delete an existing external checkout.
Proof: `sh tests/tmux_external_plugin_management_test.sh plugin_removal_preserves_external_checkout`

**C18** - With the real TPM installed, `prefix + I` fetches `tmux-resurrect` into the external plugin directory without creating a repository copy.
Proof: `sh tests/tmux_external_plugin_management_test.sh real_tpm_fetches_external_plugin`

### S2 - Documented bootstrap sequence · 1 source file · 7,222 bytes · ~1.8k

**C11** - The README instructs users to install TPM at `$HOME/.tmux/plugins/tpm` before starting or reloading tmux.
Proof: `sh tests/tmux_bootstrap_docs_test.sh tpm_prerequisite_order`

**C12** - The README instructs users to inspect and migrate Stow conflicts before running `./install.sh --tmux`.
Proof: `sh tests/tmux_bootstrap_docs_test.sh stow_conflict_order`

**C13** - The README instructs users to press `prefix + I` to install the declared TPM plugins, including `tmux-resurrect`.
Proof: `sh tests/tmux_bootstrap_docs_test.sh plugin_install_step`

**C14** - The README identifies missing TPM as a prerequisite and does not imply that `install.sh` installs TPM automatically.
Proof: `sh tests/tmux_bootstrap_docs_test.sh missing_tpm_is_prerequisite`

**C15** - The README identifies repository-owned Catppuccin files as Stow-managed and upstream plugin checkouts as TPM-managed.
Proof: `sh tests/tmux_bootstrap_docs_test.sh ownership_boundary_is_documented`

## Swept

- validation: C1-C5, C11-C15
- failure modes: C6, C10, C14
- idempotency and retry: C8, C9, C16, C17
- authorization: existing installer `HOME` requirement and no-`sudo` deployment guidance; no authorization boundary exists
- concurrency and ordering: C4, C7, C11-C13
- data lifecycle: C9; tmux-resurrect save files remain user data outside the repository
- external-dependency failure: C6, C14, C18; TPM installation and plugin fetch remain explicit user actions
- state transitions: C7-C9 and C16-C18 cover TPM bootstrap, plugin installation, reload, retention, and removal from the list
- observability: C10; GNU Stow's existing conflict output remains the diagnostic contract

## Coverage

| Set (size) | Member -> proof | Unproven |
| --- | --- | --- |
| forbidden vendored plugin directories (2) | `tpm` and `tmux-resurrect` -> C1 | - |
| TPM plugin declarations (2) | `tmux-plugins/tpm` and `tmux-plugins/tmux-resurrect` -> C2 | - |
| tmux loading commands (2) | local Catppuccin entrypoint -> C3; final TPM initializer -> C4 | - |
| Stow deployment targets (2) | `$HOME/.tmux.conf` and `$HOME/.tmux/` -> C5 | - |
| prohibited installer command classes (3) | Git, network client, package manager -> C6 | - |
| runtime controls (3) | TPM prefix binding -> C7; fixture install/reload -> C8; real TPM fetch -> C18 | - |
| deployment lifecycle (5) | repeat -> C9; repeated `prefix + I` -> C16; removed plugin -> C17; `.tmux.conf` conflict -> C10; Catppuccin entrypoint conflict -> C10 | - |
| documented bootstrap steps (5) | TPM prerequisite/order -> C11; conflict migration -> C12; plugin install -> C13; missing TPM -> C14; ownership boundary -> C15 | - |

- No checks claim a status code, route, or response shape.
- No other check claims more than the single case its proof exercises.

## Handoff

S1 + S2 = 13,159 bytes of existing source, approximately 3.3k tokens, well under the 150k batch budget. Both slices stay in one batch because they touch the same tmux bootstrap surface; no handoff boundary is planned.
