# powerbash

A powerline-style bash prompt in pure bash — one script, no dependencies, no
patched fonts.

[![CI](https://github.com/napalm255/powerbash/actions/workflows/ci.yml/badge.svg)](https://github.com/napalm255/powerbash/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

```
 napalm  powerbash  » updates +  $
```

Segments, in display order: virtual environment, username, hostname, path, git
branch and state, background job count, `$`/`#` symbol, and the return code of
the last command. Everything is toggled at runtime with the `powerbash` command
and persisted to a small config file.

**Full documentation: [powerbash.org/docs](https://powerbash.org/docs/)**

## Install

powerbash installs into your own account. It does not need root, and a
per-user install is the recommended way to run it.

### Homebrew — recommended

```bash
brew install powerbash/powerbash/powerbash
```

Then add the line the caveats print to `~/.bashrc` (Linux) or `~/.bash_profile`
(macOS). Upgrades come along with the rest of your `brew upgrade`, which is
why this is the path to prefer where you have it.

### Install script

For machines without Homebrew.

```bash
curl -s https://get.powerbash.org | bash
```

Downloads the script to `~/.local/share/powerbash/` and wires it into your
shell startup file. Re-run it any time to upgrade. To remove it:

```bash
curl -s https://get.powerbash.org | bash -s -- uninstall
```

### Manual

```bash
mkdir -p ~/.local/share/powerbash
curl -Ls https://download.powerbash.org/powerbash.sh -o ~/.local/share/powerbash/powerbash.sh
echo 'source ~/.local/share/powerbash/powerbash.sh' >> ~/.bashrc
```

On macOS use `~/.bash_profile` — Terminal.app and iTerm2 start login shells.

A multi-user install into `/etc/profile.d/` is still possible but discouraged;
see [the docs](https://powerbash.org/docs/#global) for why and how.

## Usage

```bash
powerbash help            # every subcommand, also available via [tab]
powerbash path parted     # /full/.../no/where
powerbash git timeout 1   # give up on slow git repos after a second
powerbash config save     # persist the current settings
```

## Requirements

* **bash 3.2 or newer** — including the `/bin/bash` that ships with macOS.
* A **UTF-8 locale**, for the `»`, `⇡`, `⇣`, and `▶` glyphs.
* `tput` for colors and `git` for the git segment. Both optional: powerbash
  degrades to a plain prompt without them.

Runs on Linux, macOS, and WSL.

## Development

```bash
./tests/smoke.sh          # the full suite, runs anywhere
./dev/test-bash32.sh      # the same suite under bash 3.2, in a container
shellcheck powerbash.sh   # must stay at zero findings

./dev/toolbox-setup.sh    # build the dev container (one time)
./dev/toolbox-enter.sh    # a shell running the working copy of the prompt
```

See [AGENTS.md](AGENTS.md) for the architecture and the constraints that shape
the script.

## License

MIT — see [LICENSE](LICENSE).
