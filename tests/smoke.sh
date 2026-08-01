#!/usr/bin/env bash
#
# powerbash smoke test.
#
# Sources powerbash.sh and drives it the way a user would: every subcommand
# with every documented value, rejection of everything else, and the two
# injection vectors that reach PS1 (arithmetic and git branch names). Run it
# directly:
#
#   tests/smoke.sh
#
# It is bash 3.2-safe on purpose -- macOS ships 3.2.57 as /bin/bash and the
# same suite runs there and inside the bash:3.2 container (dev/test-bash32.sh).
#
# Everything it touches lives under one mktemp -d, including POWERBASH_CONFIG,
# so it cannot read or clobber the config of whoever is running it.

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/powerbash.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/powerbash-smoke.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
info() { echo "  ok: $*"; }

# Never inherit the caller's terminal state or saved settings.
export POWERBASH_CONFIG="$WORK/powerbashrc"

PS1='x'
# shellcheck source=/dev/null
. "$SCRIPT"

info "sourced $SCRIPT ($(powerbash version))"

# --- every subcommand accepts its documented values ----------------------

powerbash help >/dev/null    || fail "help"
powerbash version >/dev/null || fail "version"

for v in on off system; do
  powerbash prompt "$v" >/dev/null || fail "prompt $v"
done
for v in on off auto; do
  powerbash host "$v" >/dev/null || fail "host $v"
done
for s in user git jobs symbol rc; do
  for v in on off; do
    powerbash "$s" "$v" >/dev/null || fail "$s $v"
  done
done
for v in off full working parted mini short; do
  powerbash path "$v" >/dev/null || fail "path $v"
done
for v in on off icon short; do
  powerbash py virtualenv "$v" >/dev/null || fail "py virtualenv $v"
done
for v in xterm xterm-256color screen screen-256color; do
  powerbash term "$v" >/dev/null || fail "term $v"
done

powerbash path short add 5 >/dev/null      || fail "path short add"
powerbash path short subtract 2 >/dev/null || fail "path short subtract"
powerbash git skip "$WORK/nowhere/"        || fail "git skip"
powerbash git skip "" >/dev/null           || fail "git skip reset"

# `git timeout <n>` deliberately refuses when there is no timeout(1) to run --
# stock macOS has neither timeout nor gtimeout unless coreutils is installed.
# Assert whichever behavior applies, rather than assuming the command exists.
powerbash git timeout 0 >/dev/null || fail "git timeout 0"
if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
  powerbash git timeout 1 >/dev/null || fail "git timeout 1"
  [ "$POWERBASH_GIT_TIMEOUT" = "1" ] || fail "git timeout 1 did not take effect"
  powerbash git timeout 0 >/dev/null || fail "git timeout 0 (reset)"
else
  if powerbash git timeout 1 >/dev/null 2>&1; then
    fail "git timeout 1 accepted with no timeout(1) available"
  fi
fi
if powerbash git timeout abc >/dev/null 2>&1; then fail "git timeout abc accepted"; fi

info "all subcommands accept their documented values"

# --- invalid input is rejected, not silently ignored ---------------------

for bad in \
  "bogus" \
  "path bogus" \
  "py bogus" \
  "py virtualenv bogus" \
  "prompt bogus" \
  "host bogus" \
  "term bogus"
do
  # shellcheck disable=SC2086
  if powerbash $bad >/dev/null 2>&1; then fail "accepted 'powerbash $bad'"; fi
done

info "invalid input is rejected"

# --- arithmetic injection must be refused --------------------------------

rm -f "$WORK/PWNED_ARITH"
powerbash path short add "a[\$(touch $WORK/PWNED_ARITH)]" >/dev/null 2>&1 || true
if [ -e "$WORK/PWNED_ARITH" ]; then fail "arithmetic injection executed"; fi

info "arithmetic injection refused"

# --- renders a non-empty prompt outside a repo ---------------------------

# The loops above left several toggles off; reset what the assertions below
# actually depend on.
powerbash prompt on >/dev/null
powerbash path working >/dev/null
powerbash git on >/dev/null
powerbash symbol on >/dev/null

cd "$WORK"
PS1=''; __powerbash_set_ps1 on
[ -n "$PS1" ] || fail "empty PS1 outside a repo"

info "renders outside a git repo"

# --- renders inside a repo, and a hostile branch name stays inert --------

repo="$WORK/repo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" -c user.email=t@t -c user.name=t commit --allow-empty -qm init

# Note the branch names below contain no spaces: git rejects those outright,
# so a name like '$(touch /tmp/x)x' would never reach PS1 and would make this
# a vacuous test. '$(>PWNED)x' and '`>PWNED`x' are valid refs that bash would
# happily execute if the branch name reached PS1 unescaped.
cd "$repo"
# shellcheck disable=SC2016  # the literal $(...) and `...` are the point
for branch in '$(>PWNED_CMDSUB)x' '`>PWNED_BACKTICK`x'; do
  git checkout -q -b "$branch" 2>/dev/null || fail "could not create branch $branch"

  PS1=''; __powerbash_set_ps1 on
  [ -n "$PS1" ] || fail "empty PS1 in repo on $branch"
  case "$PS1" in
    *'»'*) ;;
    *) fail "git segment missing on $branch" ;;
  esac

  # Simulate what bash itself does to PS1 on every render.
  eval "expanded=\"${PS1}\"" >/dev/null 2>&1 || true
  if [ -e "$repo/PWNED_CMDSUB" ];   then fail "branch-name command substitution executed"; fi
  if [ -e "$repo/PWNED_BACKTICK" ]; then fail "branch-name backtick executed"; fi
done

# dirty and ahead/behind markers still render
: > "$repo/dirty"
git -C "$repo" add dirty
PS1=''; __powerbash_set_ps1 on
case "$PS1" in
  *'+'*) ;;
  *) fail "dirty marker missing" ;;
esac

info "renders inside a git repo, branch-name injection inert"

# --- detached HEAD --------------------------------------------------------

git -C "$repo" -c user.email=t@t -c user.name=t commit -qm dirty
git -C "$repo" checkout -q --detach
PS1=''; __powerbash_set_ps1 on
[ -n "$PS1" ] || fail "empty PS1 on detached HEAD"

info "renders on detached HEAD"

# --- config round-trip ----------------------------------------------------

cd "$WORK"
powerbash path short >/dev/null
powerbash config save || fail "config save"
grep -q '^POWERBASH_PATH=short$' "$POWERBASH_CONFIG" || fail "config save contents"

# A tampered config must not be able to export anything outside the allowlist.
echo 'POWERBASH_EVIL=pwned' >> "$POWERBASH_CONFIG"
powerbash config load >/dev/null || fail "config load"
if [ -n "${POWERBASH_EVIL:-}" ]; then fail "config load honored a non-allowlisted setting"; fi

powerbash config default >/dev/null || fail "config default"
if [ -e "$POWERBASH_CONFIG" ]; then fail "config default did not remove the file"; fi
powerbash config load >/dev/null || fail "config load with no file"

info "config save/load/default round-trip"

# --- degrades gracefully with no terminfo --------------------------------

# This is the regression that broke CI: with no $TERM, tput writes to stderr
# and exits non-zero, which under `set -e` aborted sourcing entirely.
noterm_err="$(env -u TERM "$BASH" -e -c "PS1=x; POWERBASH_CONFIG=$WORK/none; . '$SCRIPT'" 2>&1 >/dev/null)"
[ -z "$noterm_err" ] || fail "sourcing with no \$TERM wrote to stderr: $noterm_err"

noterm_ps1="$(env -u TERM "$BASH" -e -c "PS1=x; POWERBASH_CONFIG=$WORK/none; . '$SCRIPT'; PS1=''; __powerbash_set_ps1 on; printf '%s' \"\$PS1\"" 2>/dev/null)"
[ -n "$noterm_ps1" ] || fail "no \$TERM produced an empty PS1"
case "$noterm_ps1" in
  *$'\033'*) fail "no \$TERM still emitted escape sequences" ;;
esac

if command -v tput >/dev/null 2>&1; then
  color_ps1="$(TERM=xterm-256color "$BASH" -e -c "PS1=x; POWERBASH_CONFIG=$WORK/none; . '$SCRIPT'; PS1=''; __powerbash_set_ps1 on; printf '%s' \"\$PS1\"" 2>/dev/null)"
  case "$color_ps1" in
    *$'\033'*) ;;
    *) fail "TERM=xterm-256color produced no escape sequences" ;;
  esac
  info "degrades gracefully with no \$TERM, colors when there is one"
else
  # No ncurses at all (some minimal containers). The no-$TERM path above
  # already covers the degradation case; there is nothing to colorize with.
  info "degrades gracefully with no \$TERM (no tput here, color check skipped)"
fi

# --- survives a later script that assigns over PROMPT_COMMAND -------------

# The real-world case: GNOME Terminal's /etc/profile.d/vte.sh appends when
# PROMPT_COMMAND is an array and *assigns over it* when it is a string, so
# anything registered earlier as a string is silently evicted. Verbatim from
# vte.sh, so this keeps testing what that file actually does.
cat > "$WORK/vte-sim.sh" <<'VTE'
__vte_precmd() { :; }
__vte_osc7() { :; }
__vte_prompt_command() { :; }
if [[ "$(declare -p PROMPT_COMMAND 2>&1)" =~ "declare -a" ]]; then
    PROMPT_COMMAND+=(__vte_precmd)
    PROMPT_COMMAND+=(__vte_osc7)
else
    PROMPT_COMMAND="__vte_prompt_command"
fi
VTE

# bash runs every element of an array PROMPT_COMMAND only as of 5.1; below
# that powerbash must still produce a string, and ordering is the only
# defense (hence the z_ prefix on the /etc/profile.d install).
pc_array="no"
if [ "${BASH_VERSINFO[0]}" -gt 5 ] ||
   { [ "${BASH_VERSINFO[0]}" -eq 5 ] && [ "${BASH_VERSINFO[1]}" -ge 1 ]; }; then
  pc_array="yes"
fi

# Sourced last -- the ordering the docs recommend. Must hold on every bash.
after="$("$BASH" -c "PS1=x; POWERBASH_CONFIG=$WORK/none; . '$WORK/vte-sim.sh'; . '$SCRIPT'; declare -p PROMPT_COMMAND" 2>/dev/null)"
case "$after" in
  *__powerbash_set_ps1*) ;;
  *) fail "sourcing after a PROMPT_COMMAND setter dropped powerbash: $after" ;;
esac
case "$after" in
  *__vte_prompt_command*|*__vte_precmd*) ;;
  *) fail "sourcing after a PROMPT_COMMAND setter dropped the other hook: $after" ;;
esac

# Sourced first -- what an unprefixed /etc/profile.d install does. On 5.1+
# the array we install makes the other script append instead of assign.
before="$("$BASH" -c "PS1=x; POWERBASH_CONFIG=$WORK/none; . '$SCRIPT'; . '$WORK/vte-sim.sh'; declare -p PROMPT_COMMAND; printf 'IDX0=%s' \"\${PROMPT_COMMAND[0]}\"" 2>/dev/null)"
if [ "$pc_array" = "yes" ]; then
  case "$before" in
    *__powerbash_set_ps1*) ;;
    *) fail "a later PROMPT_COMMAND assignment evicted powerbash: $before" ;;
  esac
  # Index 0 is not cosmetic: it is what makes \$? the user's command status
  # rather than the exit code of whatever else is registered.
  case "$before" in
    *"IDX0=__powerbash_set_ps1 on") ;;
    *) fail "powerbash is no longer first in PROMPT_COMMAND: $before" ;;
  esac
  info "survives a later PROMPT_COMMAND assignment, in either order"
else
  # No array support: the string form is all that can be produced, so being
  # sourced last is the only defense. Assert we still produce that string.
  case "$before" in
    declare\ --\ PROMPT_COMMAND*) ;;
    *) fail "bash $BASH_VERSION should get a string PROMPT_COMMAND: $before" ;;
  esac
  info "survives a later PROMPT_COMMAND assignment when sourced last (no array support here)"
fi

# --- toggles still work alongside a foreign hook --------------------------

foreign="$("$BASH" -c "
  PS1=x; POWERBASH_CONFIG=$WORK/none
  __other_hook() { :; }
  PROMPT_COMMAND=(__other_hook)
  . '$SCRIPT'
  for m in off system on; do powerbash prompt \$m >/dev/null; done
  declare -p PROMPT_COMMAND" 2>/dev/null)"
if [ "$pc_array" = "yes" ]; then
  case "$foreign" in
    *'[0]="__powerbash_set_ps1 on"'*) ;;
    *) fail "prompt toggles lost powerbash's slot: $foreign" ;;
  esac
  case "$foreign" in
    *__other_hook*) ;;
    *) fail "prompt toggles dropped a foreign hook: $foreign" ;;
  esac
  info "prompt off/system/on round-trip without disturbing other hooks"
fi

echo "all checks passed (bash $BASH_VERSION on $(uname -s))"
