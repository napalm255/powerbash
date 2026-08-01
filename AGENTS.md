# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## What this is

powerbash is a single pure-Bash script (`powerbash.sh`) that implements a powerline-style Bash prompt. There is no build step, package manager, or compiled artifact — the script is sourced directly into a user's shell (via `.bashrc`, `.bashrc.d/`, `.bash_profile`, or a `/etc/profile.d/` global install). Everything the project does lives in that one file.

Docs are a separate concern: `docs/README.md` is built into a static site via MkDocs (`.mkdocs.yml`, readthedocs theme) and published to docs.powerbash.org via Read the Docs (`.readthedocs.yaml`). The root `README.md`... there isn't one — GitHub's rendered README is `docs/README.md` itself (referenced from `.mkdocs.yml` nav). `CNAME` (`download.powerbash.org`) configures GitHub Pages for this repo.

## Hard constraints

**Target bash 3.2.** macOS ships bash 3.2.57 as `/bin/bash` and we support it. That rules out `${var^^}` / `${var,,}`, `mapfile`/`readarray`, associative arrays (`declare -A`), and `local -n`. The bash 5.1+ array form of `PROMPT_COMMAND` is used only behind a runtime feature check.

**Assume BSD userland.** macOS `sed`/`grep` lack GNU extensions (`\s`, `-P`, ...). The script currently shells out to no `sed`, `grep`, `awk`, `basename`, `cut`, or `wc` at all — keep it that way; bash parameter expansion covers these cases and avoids a fork per prompt.

**The prompt is a hot path.** `__powerbash_set_ps1` runs on every keystroke-completed command. Avoid subshells (`$(...)`), external commands, and per-render work generally. Anything that only changes when the terminal or config changes belongs in `__powerbash_colors` or `__powerbash_defaults`, which run on toggle rather than on render.

**Never interpolate untrusted text into `PS1` unescaped.** Bash expands `PS1` on every render, so a directory or branch name containing `$(...)`, backticks, or backslash escapes would be executed or would corrupt the prompt's width accounting. Run it through `__powerbash_escape` first — see the segment renderers for the pattern.

## Commands

Lint the script. `.shellcheckrc` pins `shell=bash` and `quote-safe-variables`, and the script is currently **shellcheck-clean with zero findings** — keep it that way:

```bash
shellcheck powerbash.sh
```

CI (`.github/workflows/shellcheck.yml`) runs shellcheck plus a functional smoke test on `ubuntu-latest` and `macos-latest` for every push and PR. The macOS job runs under `/bin/bash`, which is how bash 3.2 compatibility is actually enforced.

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

1. **Guards** — the script returns immediately unless `$BASH_VERSION` is set (so `/etc/profile.d/` installs are inert under `dash`) and `$PS1` is non-empty (non-interactive shells).
2. **`powerbash()`** — the user-facing subcommand dispatcher (`help`, `version`, `reload`, `prompt`, `config`, `py`, `user`, `host`, `path`, `git`, `jobs`, `symbol`, `rc`, `term`). Most subcommands export a `POWERBASH_*` variable; those variables *are* the config, there is no separate config object. The exceptions: `reload` re-sources a startup file, `prompt` rewrites `PROMPT_COMMAND`, `config` does file I/O, and `term` exports `TERM`. Every invalid input path prints usage and returns 1.
3. **`__powerbash_complete()`** — bash-completion function registered at the bottom of the file via `complete -F __powerbash_complete powerbash`. Its three-level option lists (`option_list` at COMP_CWORD 1/2/3) must be kept in sync by hand with the `case` branches in `powerbash()` — adding a new subcommand or flag means updating both places. Level-3 completion keys off the *previous word* (`virtualenv`, `short`), so a future subcommand reusing those words would collide.
4. **`__powerbash()`** — the setup function, run once at source time. It defines the symbol variables, resolves `timeout`/`gtimeout` once, and defines every other function. These nested definitions are not closures — bash promotes them to plain globals when `__powerbash` runs, which is exactly why they survive the `unset -f __powerbash` that follows.
5. **`__powerbash_defaults`** — applies the default value for each setting that is unset. Called once at startup (after the config file is loaded, so the file wins) and again after `config default`. Defaults are *not* re-evaluated per render. It also picks the WSL-specific `POWERBASH_GIT_SKIP_PATHS` default.
6. **`__powerbash_escape`** — neutralizes `\`, `$`, and `` ` `` in anything destined for `PS1`. Returns via the global `__powerbash_esc` rather than stdout, because a `$(...)` call site would fork a subshell on every render.
7. **`__powerbash_config`** — `save`/`load`/`default` over `~/.config/powerbashrc`. Only the names listed in `__POWERBASH_SETTINGS` are ever written or read back, so a hand-edited or tampered file cannot export arbitrary variables. `save` creates the parent directory if needed.
8. **Segment renderers** (`__powerbash_py_virtualenv_display`, `__powerbash_user_display`, `__powerbash_host_display`, `__powerbash_path_display` + its `_parted`/`_short`/`_mini` variants, `__powerbash_git_display`, `__powerbash_jobs_display`, `__powerbash_symbol_display`, `__powerbash_rc_display`) — each checks its toggle, bails early, and **appends to `PS1` directly**. They do not print for capture; a `$(...)` per segment would fork eight subshells per prompt. Two consequences that are easy to get wrong: renderers must keep all working state `local` and must never assign to a config global (there is no subshell to contain the write), and they must `return 0` on bail-out paths so the prompt still works under `set -e`.
9. **`__powerbash_git_display`** is the most involved segment. It checks `POWERBASH_GIT_SKIP_PATHS` first (a free prefix match, no fork), then makes a single `git status --porcelain=v2 --branch` call — optionally wrapped in `timeout` — that yields branch name, dirty state, and ahead/behind counts together. Exit code 124 means the timeout fired. A non-zero exit falls back to `git -C "$(git rev-parse --show-toplevel)"`, which handles linked worktrees; this is keyed off the exit code rather than matching a localized error string. Detached HEAD falls back to `git describe --tags --always`. The branch name is escaped before it reaches `PS1`.
10. **`__powerbash_set_ps1`** — captures `$?` first (the comment is not decorative), then calls the renderers in fixed order: virtualenv, user, host, path, git, jobs, symbol, rc.
11. **`__powerbash_set_prompt_command`** installs the render function into `PROMPT_COMMAND` and recomputes colors on `on`. It handles four cases: unset, bash 5.1+ array form, string form already containing powerbash (replace in place), and string form belonging to someone else (prepend). It **prepends** rather than appends so that `$?` is still the user's command status and not the exit code of whatever else is registered — appending silently breaks the return-code segment for anyone running direnv or `vte_prompt_command`.

### Adding a new toggle/segment

Pick a `POWERBASH_<NAME>` env var, add a case arm in `powerbash()` to export it, add its default to `__powerbash_defaults`, add the name to `__POWERBASH_SETTINGS` if it should persist, add the matching completion entries in `__powerbash_complete`, write a `__powerbash_<name>_display` renderer following the existing bail-early/local-only/`PS1+=` shape, and wire it into `__powerbash_set_ps1` in the position it should appear. Document it in the `docs/README.md` configuration table and in `__powerbash_usage`.

### Distribution

There's no packaging step — installation instructions in `docs/README.md` are literally `curl`-ing the raw script from GitHub (`master` branch) into `.bashrc.d/`, a user directory sourced from `.bashrc`/`.bash_profile`, or `/etc/profile.d/`. `docs/README.md` also advertises `curl -s https://get.powerbash.org | bash`, which is not backed by anything in this repository. Changes to `powerbash.sh` on `master` are live for the raw-URL install methods immediately, so keep the script self-contained and backward-compatible with existing `POWERBASH_*` env vars and saved `~/.config/powerbashrc` files.
