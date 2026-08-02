# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## What this is

powerbash is a single pure-Bash script (`powerbash.sh`) that implements a powerline-style Bash prompt. There is no build step, package manager, or compiled artifact — the script is sourced directly into a user's shell (via `.bashrc`, `.bashrc.d/`, or `.bash_profile`). Everything the project ships lives in that one file; `tests/`, `dev/`, and `.github/` exist only to check it.

**A per-user install is the supported path.** A `/etc/profile.d/` multi-user install still works and the script guards against being sourced by `dash` there, but docs must not lead with it — it upgrades badly, needs root, and imposes one prompt on every account on the box.

The root `README.md` is deliberately short: install paths and a pointer to the full documentation, which lives on the website (`powerbash.org/docs/`, repo `powerbash/powerbash.github.io`). There is no MkDocs/Read the Docs setup any more — if you add a user-visible setting, the docs change goes in that repo, not here. `CNAME` (`download.powerbash.org`) plus `.nojekyll` configure GitHub Pages for this repo, which is what serves `https://download.powerbash.org/powerbash.sh` — the canonical download URL used by the installer and the docs. It tracks `master`, so anything merged there is live immediately.

## Hard constraints

**Target bash 3.2.** macOS ships bash 3.2.57 as `/bin/bash` and we support it. That rules out `${var^^}` / `${var,,}`, `mapfile`/`readarray`, associative arrays (`declare -A`), and `local -n`. The bash 5.1+ array form of `PROMPT_COMMAND` is used only behind a runtime feature check.

**Assume BSD userland.** macOS `sed`/`grep` lack GNU extensions (`\s`, `-P`, ...). The script currently shells out to no `sed`, `grep`, `awk`, `basename`, `cut`, or `wc` at all — keep it that way; bash parameter expansion covers these cases and avoids a fork per prompt.

**The prompt is a hot path.** `__powerbash_set_ps1` runs on every keystroke-completed command. Avoid subshells (`$(...)`), external commands, and per-render work generally. Anything that only changes when the terminal or config changes belongs in `__powerbash_colors` or `__powerbash_defaults`, which run on toggle rather than on render.

**Never interpolate untrusted text into `PS1` unescaped.** Bash expands `PS1` on every render, so a directory or branch name containing `$(...)`, backticks, or backslash escapes would be executed or would corrupt the prompt's width accounting. Run it through `__powerbash_escape` first — see the segment renderers for the pattern.

**Survive `set -e` and a missing terminal.** The script is sourced into shells we do not control, including `set -e` ones and TTY-less ones. Two rules follow. Use `__powerbash_tput` rather than `tput` — with no `$TERM` (CI, cron, containers) `tput` writes to stderr and exits non-zero, which under `set -e` aborts the sourcing outright. And never assign from a command substitution that is allowed to fail: `x="$(cmd)"` kills the shell before the next line can read `$?`, so write `x="$(cmd)" || rc=$?` instead. `__powerbash_git_display` does this; `git` exits 128 outside a work tree, which is an entirely normal state.

## Commands

`make` on its own lists every target. The ones that matter:

```bash
make check          # lint + suite + suite under bash 3.2. Run this before pushing.
make lint           # shellcheck; must stay at zero findings
make test           # the suite under whatever bash you have
make test BASH=/bin/bash    # ...or a specific one
make test-bash32    # the suite under bash 3.2, in a container
make toolbox        # build the dev container (one time)
make shell          # a shell in it, running the working copy of the prompt
```

**CI calls these same targets**, so one that drifts from what the project does fails on the next push rather than going stale in prose. The container plumbing lives in the recipes themselves; only three things stay files, each because something other than make has to read them: `tests/smoke.sh` (it runs inside `bash:3.2`, an Alpine image with no make in it), `dev/bashrc` (`bash --rcfile` takes a path), and `dev/Containerfile` (`podman build -f` takes a path). Recipes target GNU make 3.81, which is what macOS ships — no `.ONESHELL`, so multi-step recipes are one backslash-continued shell line.

Note the tradeoff: shell inside a recipe is not reachable by shellcheck. Keep recipes to plumbing, and put anything with real logic in a file that `make lint` covers.

`.shellcheckrc` pins `shell=bash` and `quote-safe-variables`, and everything is currently **shellcheck-clean with zero findings**. `tests/smoke.sh` drives every subcommand, asserts invalid input is rejected, checks both PS1 injection vectors, covers the no-`$TERM` path, and covers a later script assigning over `PROMPT_COMMAND`. It is bash 3.2-safe and hermetic (one `mktemp -d`, `POWERBASH_CONFIG` redirected into it), so it never reads or writes the caller's real config.

CI (`.github/workflows/ci.yml`) runs `make lint`, then `make test` on `ubuntu-latest` and `macos-latest` twice — once with no `$TERM`, once with `TERM=xterm-256color` — plus `make test-bash32` and a `dash` job asserting non-bash shells get silence. The macOS runner pins `BASH=/bin/bash`, which is 3.2.57 there; `make test-bash32` covers 3.2 on musl. `make check` is all of that except the macOS and `dash` jobs, which need runners you do not have locally.

Outside the container, exercise a change by sourcing the script in place:

```bash
source powerbash.sh
powerbash prompt on
powerbash path parted
powerbash config save   # writes ~/.config/powerbashrc
```

## Architecture

Everything is namespaced under `__powerbash_*` (private helpers) and the single public entrypoint `powerbash()` (the CLI). Reading `powerbash.sh` top to bottom:

1. **Guards** — the script returns immediately unless `$BASH_VERSION` is set (so `/etc/profile.d/` installs are inert under `dash`) and `$PS1` is non-empty (non-interactive shells). `__powerbash_tput` is defined here at top level rather than inside `__powerbash`, because `__powerbash` calls it while assigning `RESET`, before it has defined any of its own nested functions.
2. **`powerbash()`** — the user-facing subcommand dispatcher (`help`, `version`, `reload`, `prompt`, `config`, `py`, `user`, `host`, `path`, `git`, `jobs`, `symbol`, `rc`, `term`). Most subcommands export a `POWERBASH_*` variable; those variables *are* the config, there is no separate config object. The exceptions: `reload` re-sources a startup file, `prompt` rewrites `PROMPT_COMMAND`, `config` does file I/O, and `term` exports `TERM`. Every invalid input path prints usage and returns 1.
3. **`__powerbash_complete()`** — bash-completion function registered at the bottom of the file via `complete -F __powerbash_complete powerbash`. Its three-level option lists (`option_list` at COMP_CWORD 1/2/3) must be kept in sync by hand with the `case` branches in `powerbash()` — adding a new subcommand or flag means updating both places. Level-3 completion keys off the *previous word* (`virtualenv`, `short`), so a future subcommand reusing those words would collide.
4. **`__powerbash()`** — the setup function, run once at source time. It defines the symbol variables, resolves `timeout`/`gtimeout` once, and defines every other function. These nested definitions are not closures — bash promotes them to plain globals when `__powerbash` runs, which is exactly why they survive the `unset -f __powerbash` that follows.
5. **`__powerbash_defaults`** — applies the default value for each setting that is unset. Called once at startup (after the config file is loaded, so the file wins) and again after `config default`. Defaults are *not* re-evaluated per render. It also picks the WSL-specific `POWERBASH_GIT_SKIP_PATHS` default.
6. **`__powerbash_escape`** — neutralizes `\`, `$`, and `` ` `` in anything destined for `PS1`. Returns via the global `__powerbash_esc` rather than stdout, because a `$(...)` call site would fork a subshell on every render.
7. **`__powerbash_config`** — `save`/`load`/`default` over `~/.config/powerbashrc`. Only the names listed in `__POWERBASH_SETTINGS` are ever written or read back, so a hand-edited or tampered file cannot export arbitrary variables. `save` creates the parent directory if needed.
8. **Segment renderers** (`__powerbash_py_virtualenv_display`, `__powerbash_user_display`, `__powerbash_host_display`, `__powerbash_path_display` + its `_parted`/`_short`/`_mini` variants, `__powerbash_git_display`, `__powerbash_jobs_display`, `__powerbash_symbol_display`, `__powerbash_rc_display`) — each checks its toggle, bails early, and **appends to `PS1` directly**. They do not print for capture; a `$(...)` per segment would fork eight subshells per prompt. Two consequences that are easy to get wrong: renderers must keep all working state `local` and must never assign to a config global (there is no subshell to contain the write), and they must `return 0` on bail-out paths so the prompt still works under `set -e`.
9. **`__powerbash_git_display`** is the most involved segment. It checks `POWERBASH_GIT_SKIP_PATHS` first (a free prefix match, no fork), then makes a single `git status --porcelain=v2 --branch` call — optionally wrapped in `timeout` — that yields branch name, dirty state, and ahead/behind counts together. The status is captured with `|| rc=$?` because that call fails routinely (128 outside a work tree) and a bare assignment would kill a `set -e` shell. Exit code 124 means the timeout fired. Any other non-zero exit falls back to locating the work tree with `git worktree list --porcelain`, which reads repository metadata and so still works from inside `.git/` or a linked worktree's admin dir where `git rev-parse --show-toplevel` fails identically; this is keyed off the exit code rather than matching a localized error string. Detached HEAD falls back to `git describe --tags --always`. The branch name is escaped before it reaches `PS1`.
10. **`__powerbash_set_ps1`** — captures `$?` first (the comment is not decorative), then calls the renderers in fixed order: virtualenv, user, host, path, git, jobs, symbol, rc.
11. **`__powerbash_set_prompt_command`** installs the render function into `PROMPT_COMMAND` and recomputes colors on `on`. It handles four cases: unset, bash 5.1+ array form, string form already containing powerbash (replace in place), and string form belonging to someone else (prepend). It **prepends** rather than appends so that `$?` is still the user's command status and not the exit code of whatever else is registered — appending silently breaks the return-code segment for anyone running direnv or `vte_prompt_command`.

    The unset case has two arms, and the array one is load-bearing rather than cosmetic. Other tools commonly branch on `declare -p PROMPT_COMMAND`: handed an array they append, handed a string they **assign over it** and every hook registered earlier disappears. `/etc/profile.d/vte.sh` does exactly that (`PROMPT_COMMAND="__vte_prompt_command"`), which is why a `/etc/profile.d` install has historically needed the `z_` prefix to sort after it. Creating an array — guarded by `__POWERBASH_PC_ARRAY`, resolved once from `BASH_VERSINFO` — makes those tools append instead, so powerbash survives regardless of order *and* keeps index 0. Below bash 5.1 the array form is not just unhelpful but actively wrong: bash expands `PROMPT_COMMAND` as a plain string there, running element 0 and silently dropping every other hook. Never create one without the version guard. `tests/smoke.sh` reproduces vte.sh's assignment verbatim in both orders; if you touch this function, that section is the one that will catch you.

### Adding a new toggle/segment

Pick a `POWERBASH_<NAME>` env var, add a case arm in `powerbash()` to export it, add its default to `__powerbash_defaults`, add the name to `__POWERBASH_SETTINGS` if it should persist, add the matching completion entries in `__powerbash_complete`, write a `__powerbash_<name>_display` renderer following the existing bail-early/local-only/`PS1+=` shape, and wire it into `__powerbash_set_ps1` in the position it should appear. Then add it to `tests/smoke.sh`, to `__powerbash_usage`, and to the configuration table in the docs (`powerbash/powerbash.github.io`, `docs/index.html`).

### Distribution

Four repos, all fed from this one:

| Repo | Serves | Contains |
|---|---|---|
| `napalm255/powerbash` | `download.powerbash.org/powerbash.sh` | the script; tags drive releases |
| `powerbash/powerbash.github.io` | `powerbash.org` | landing page and the full docs; hand-written HTML/CSS, no build |
| `powerbash/get-powerbash` | `get.powerbash.org` | the `curl \| bash` installer (its `index.html` *is* the script) |
| `powerbash/homebrew-powerbash` | the Homebrew tap | `Formula/powerbash.rb`, **generated** — never hand-edit |

There is still no packaging step for the script itself. Pushing a `v*` tag runs `.github/workflows/release.yml`, which checks `POWERBASH_VERSION` against the tag, cuts the GitHub release, hashes the tag tarball, and commits a regenerated formula to the tap. Bump `POWERBASH_VERSION` in the same commit as the change, not at tag time.

Two consequences for every edit to `powerbash.sh`: it is live on `download.powerbash.org` the moment it merges to `master`, ahead of any release — so `master` must always be sourceable. And existing users carry `POWERBASH_*` env vars and saved `~/.config/powerbashrc` files across upgrades, so settings must stay backward-compatible.
