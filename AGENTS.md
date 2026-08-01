# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

powerbash is a single pure-Bash script (`powerbash.sh`) that implements a powerline-style Bash prompt. There is no build step, package manager, or compiled artifact — the script is sourced directly into a user's shell (via `.bashrc`, `.bashrc.d/`, or a `/etc/profile.d/` global install). Everything the project does lives in that one file.

Docs are a separate concern: `docs/README.md` is built into a static site via MkDocs (`.mkdocs.yml`, readthedocs theme) and published to docs.powerbash.org via Read the Docs (`.readthedocs.yaml`). The root `README.md`... there isn't one — GitHub's rendered README is `docs/README.md` itself (referenced from `.mkdocs.yml` nav).

## Commands

Lint the script (shellcheck is the only real "test" here — there is no test suite). `.shellcheckrc` pins `shell=bash` and `quote-safe-variables`, and GitHub Actions (`.github/workflows/shellcheck.yml`) runs the same command on every push/PR:

```bash
shellcheck powerbash.sh
```

Manually exercise a change by sourcing the script in an interactive shell and driving the `powerbash` command:

```bash
source powerbash.sh
powerbash prompt on
powerbash path parted
powerbash config save   # writes ~/.config/powerbashrc
```

Preview the docs site locally (requires `mkdocs` installed):

```bash
mkdocs serve -f .mkdocs.yml
```

## Architecture

Everything is namespaced under `__powerbash_*` (private helpers) and the single public entrypoint `powerbash()` (the CLI). Reading `powerbash.sh` top to bottom:

1. **`powerbash()`** — the user-facing subcommand dispatcher (`reload`, `prompt`, `config`, `py`, `user`, `git`, `jobs`, `symbol`, `rc`, `host`, `path`, `term`). Each subcommand mutates a `POWERBASH_*` environment variable that the prompt renderer reads on every render — there is no separate config object, the env vars *are* the config.
2. **`__powerbash_complete()`** — bash-completion function registered at the bottom of the file via `complete -F __powerbash_complete powerbash`. Its three-level option lists (`option_list` at COMP_CWORD 1/2/3) must be kept in sync by hand with the `case` branches in `powerbash()` — adding a new subcommand or flag means updating both places.
3. **`__powerbash()`** — the main setup function, run once at source time. It defines all the segment-rendering helpers as closures (`__powerbash_*_display`) and the `__powerbash_colors` function, then calls `__powerbash_set_prompt_command on` to install itself. `__powerbash_colors` (which shells out to `tput` several times) is only invoked from `__powerbash_set_prompt_command` (on setup and on `powerbash prompt on`) and from the `term)` case in `powerbash()` — never from `__powerbash_set_ps1`, since terminal color depth doesn't change per-render and recomputing it on every prompt would mean several `tput` forks per keystroke of prompt draw.
4. **Segment renderers** (`__powerbash_user_display`, `__powerbash_host_display`, `__powerbash_path_display` + its `_parted`/`_short`/`_mini` variants, `__powerbash_git_display`, `__powerbash_jobs_display`, `__powerbash_symbol_display`, `__powerbash_rc_display`, `__powerbash_py_virtualenv_display`) — each reads its own `POWERBASH_*` toggle, applies a "sane default" if unset, and either prints its segment or returns empty. `__powerbash_set_ps1` concatenates them in a fixed order to build `PS1`. Every renderer follows the same shape: check the toggle, bail early, print with the segment's color + `$RESET`.
5. **`__powerbash_git_display`** is the most involved segment: a single `git status --porcelain=v2 --branch` call gets branch name, dirty-tree state, and ahead/behind counts vs. the upstream in one shell-out, parsed line-by-line in bash. Detached HEAD (`branch.head` is `(detached)`) falls back to a second call, `git describe --tags --always`, for a friendly label. A worktree fallback (`git worktree list`) handles the case where the cwd isn't a normal work tree and the first `git status` call fails.
6. **`__powerbash_set_prompt_command`** installs the render function into `PROMPT_COMMAND`, handling three cases explicitly: unset, bash 5.1+ array form, and legacy string form (via `sed` replacement) — this is intentional so powerbash coexists with other tools that also append to `PROMPT_COMMAND` (e.g. direnv).
7. **Config persistence** — `__powerbash_config` save/load/default reads and writes all `POWERBASH_*` env vars as `KEY=VALUE` lines to `~/.config/powerbashrc`, loaded automatically at the bottom of the script if present.

### Adding a new toggle/segment

The consistent pattern across the file: pick a `POWERBASH_<NAME>` env var, add a case arm in `powerbash()` to set it, add the matching completion entries in `__powerbash_complete`, write a `__powerbash_<name>_display` renderer following the existing bail-early/default/print shape, and wire it into `__powerbash_set_ps1`'s `PS1+=` chain in the position it should appear.

### Distribution

There's no packaging step — installation instructions in `docs/README.md` are literally `curl`-ing the raw script from GitHub (`master` branch) into `.bashrc.d/`, `.bashrc`, or `/etc/profile.d/`. Changes to `powerbash.sh` on `master` are live for these install methods immediately, so keep the script self-contained and backward-compatible with existing `POWERBASH_*` env vars / saved `~/.config/powerbashrc` files.
