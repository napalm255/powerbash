# powerbash

powerline-style bash prompt in pure bash script.

[![Languages](https://img.shields.io/github/languages/top/napalm255/powerbash)](https://img.shields.io/github/languages/top/napalm255/powerbash)
[![CodeFactor](https://www.codefactor.io/repository/github/napalm255/powerbash/badge)](https://www.codefactor.io/repository/github/napalm255/powerbash)
[![Documentation Status](https://readthedocs.org/projects/powerbash/badge/?version=latest)](https://docs.powerbash.org/en/latest/?badge=latest)
[![CI](https://github.com/napalm255/powerbash/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/napalm255/powerbash/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/napalm255/powerbash/blob/master/LICENSE)


## Features

* `powerbash` command for configuration
* Bash completion support (`powerbash [tab]`)
* Segments, in display order: virtual environment, username, hostname, path,
  git information, jobs count, symbol (`$`/`#`), return code
* Color coded for root, sudo, ssh, jobs count, return code, and virtualenv
* Git information:
  * display current git branch name, or a tag/short SHA1 when the head is detached
  * display "+" symbol when the current branch has uncommitted changes
  * display "⇡" symbol and the number of commits when the branch is ahead of the remote
  * display "⇣" symbol and the number of commits when the branch is behind the remote
* Five directory display modes (see [path](#path))
* Fast execution (no noticeable delay)
* No need for patched fonts
* Runs on Linux, macOS, and WSL — pure bash 3.2+, no external dependencies
  beyond `tput` and (optionally) `git`


## Asciinema
[![asciicast](https://asciinema.org/a/30836.png)](https://asciinema.org/a/30836)


## Requirements

* **bash 3.2 or newer.** This includes the `/bin/bash` that ships with macOS,
  so no Homebrew bash is required. Bash 5.1+ is used automatically when
  available (for array-style `PROMPT_COMMAND`).
* A **UTF-8 locale**, for the `»`, `⇡`, `⇣`, and `▶` glyphs.
* `tput` (from ncurses) for colors, and `git` for the git segment. Both are
  optional in the sense that powerbash degrades gracefully without them.


## Automated Installs

Per-User: `curl -s https://get.powerbash.org | bash`

Global: `curl -s https://get.powerbash.org | sudo bash`


## Per-User Installation

### Using .bashrc.d

Note: the `~/.bashrc.d` loop is provided by the default `~/.bashrc` on
Fedora/RHEL. On Debian, Ubuntu, and macOS there is no such loop, so use the
[.bashrc method](#using-bashrc) instead.

Create the directory and download `powerbash.sh`:

    mkdir -p ~/.bashrc.d
    curl -Ls https://raw.githubusercontent.com/napalm255/powerbash/master/powerbash.sh -o ~/.bashrc.d/powerbash.sh

### Using .bashrc

Create the directory and download `powerbash.sh`:

    mkdir -p ~/.local/share/powerbash
    curl -Ls https://raw.githubusercontent.com/napalm255/powerbash/master/powerbash.sh -o ~/.local/share/powerbash/powerbash.sh

And source it from your shell startup file:

    echo 'source ~/.local/share/powerbash/powerbash.sh' >> ~/.bashrc

On **macOS**, Terminal.app and iTerm2 start *login* shells, which read
`~/.bash_profile` rather than `~/.bashrc`. Use that file instead:

    echo 'source ~/.local/share/powerbash/powerbash.sh' >> ~/.bash_profile

Put the `source` line near the end of the file, so powerbash sees any
`PROMPT_COMMAND` set by other tools and can cooperate with them.

Then restart your shell, or run `source ~/.bashrc` (or `powerbash reload`).


## Global Installation

Linux only — macOS has no `/etc/profile.d` loop.

Download the Bash script:

    sudo curl -Ls https://raw.githubusercontent.com/napalm255/powerbash/master/powerbash.sh -o /etc/profile.d/z_powerbash.sh
    sudo chmod 0644 /etc/profile.d/z_powerbash.sh

Note: powerbash is most consistent when it is the last profile.d script to run.

On Debian and Ubuntu, `/etc/profile.d/` is only sourced for *login* shells;
interactive non-login shells will not pick it up. Fedora/RHEL source it for
both. The script exits immediately when run under a non-bash shell such as
`dash`, so it is safe to place there.


## Usage

Run `powerbash help` at any time for this list, and use `[tab]` completion.

### prompt

    powerbash prompt on       # enable the powerbash prompt
    powerbash prompt off      # minimal '$ ' prompt
    powerbash prompt system   # restore the prompt you had before powerbash

### path

    powerbash path off        # hide the path segment
    powerbash path full       # /full/path/to/no/where
    powerbash path working    # where                     (default)
    powerbash path parted     # /full/.../no/where
    powerbash path short      # ..ull/path/to/no/where
    powerbash path mini       # /f/p/t/n/where

`short` truncates to `POWERBASH_PATH_SHORT_LENGTH` characters (default 20).
Adjust it with:

    powerbash path short add          # lengthen by 1
    powerbash path short add 5        # lengthen by 5
    powerbash path short subtract 5   # shorten by 5 (never below 1)

The current directory always renders as `~` when it is your home directory,
regardless of mode.

### git

    powerbash git on
    powerbash git off
    powerbash git skip /mnt/:/net/   # skip git in these path prefixes
    powerbash git timeout 1          # give up on git after 1 second
    powerbash git timeout 0          # disable the timeout (default)

See [Performance on slow filesystems](#performance-on-slow-filesystems).

### Other segments

    powerbash user on|off              # username
    powerbash host on|off|auto         # hostname (auto = only over ssh)
    powerbash jobs on|off              # background job count
    powerbash symbol on|off            # $ / # prompt symbol
    powerbash rc on|off                # return code, shown when non-zero
    powerbash py virtualenv on|off|icon|short

For `py virtualenv`: `on` shows the icon and full environment name, `short`
shows the icon and the first 5 characters, `icon` shows the icon only.

### term

    powerbash term xterm|xterm-256color|screen|screen-256color

Sets `TERM` and recomputes the color palette.

### Other commands

    powerbash help      # usage
    powerbash version   # version
    powerbash reload    # re-source ~/.bashrc (or ~/.bash_profile)


## Configuration

Every setting is an environment variable. The `powerbash` command simply sets
them, so you can also set them directly in your shell startup file *before*
sourcing `powerbash.sh`.

| Variable | Values | Default |
|---|---|---|
| `POWERBASH_USER` | `on`, `off` | `on` |
| `POWERBASH_HOST` | `on`, `off`, `auto` | `auto` |
| `POWERBASH_PATH` | `off`, `full`, `working`, `parted`, `mini`, `short` | `working` |
| `POWERBASH_PATH_SHORT_LENGTH` | positive integer | `20` |
| `POWERBASH_GIT` | `on`, `off` | `on` |
| `POWERBASH_GIT_SKIP_PATHS` | colon-separated path prefixes | `/mnt/` on WSL, otherwise empty |
| `POWERBASH_GIT_TIMEOUT` | seconds, or empty/`0` to disable | empty |
| `POWERBASH_JOBS` | `on`, `off` | `on` |
| `POWERBASH_SYMBOL` | `on`, `off` | `on` |
| `POWERBASH_RC` | `on`, `off` | `on` |
| `POWERBASH_PY_VIRTUALENV` | `on`, `off`, `icon`, `short` | `on` |

### Saving your settings

Changes made with the `powerbash` command apply to the current shell only.
To make them permanent:

    powerbash config save     # write settings to ~/.config/powerbashrc
    powerbash config load     # re-read that file
    powerbash config default  # delete the file and reset to defaults

`~/.config/powerbashrc` is loaded automatically at startup when it exists. It
is a simple list of `NAME=value` lines; only the variables in the table above
are ever written or read back.


## Performance on slow filesystems

Under WSL, git operations against the Windows filesystem (`/mnt/c`, ...) are
much slower than on the Linux filesystem, and can visibly delay the prompt.
powerbash defaults `POWERBASH_GIT_SKIP_PATHS` to `/mnt/` when it detects WSL,
which suppresses the git segment there at no cost.

Three options, cheapest first:

    powerbash git skip /mnt/    # no git lookup under these prefixes (free)
    powerbash git timeout 1     # run git, but give up after 1 second
    powerbash git off           # disable the git segment entirely

`git timeout` requires `timeout` (GNU coreutils). It is present on most Linux
distributions; on macOS install it with `brew install coreutils`, which
provides `gtimeout`. The timeout adds roughly a millisecond per prompt with
GNU `timeout` — but note that some alternative `timeout` implementations are
far slower to start, in which case prefer `git skip`.


## Uninstall

Remove whichever file you installed:

    rm ~/.bashrc.d/powerbash.sh
    # or
    rm ~/.local/share/powerbash/powerbash.sh   # and the source line in ~/.bashrc
    # or
    sudo rm /etc/profile.d/z_powerbash.sh

Your saved settings persist independently; remove them too if you want a
clean slate:

    rm ~/.config/powerbashrc


## License

MIT — see [LICENSE](https://github.com/napalm255/powerbash/blob/master/LICENSE).
