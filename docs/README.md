# powerbash

powerline-style bash prompt in pure bash script.


[![Languages](https://img.shields.io/github/languages/top/napalm255/powerbash)](https://img.shields.io/github/languages/top/napalm255/powerbash)
[![CodeFactor](https://www.codefactor.io/repository/github/napalm255/powerbash/badge)](https://www.codefactor.io/repository/github/napalm255/powerbash)
[![Documentation Status](https://readthedocs.org/projects/powerbash/badge/?version=latest)](http://docs.powerbash.org/en/latest/?badge=latest)

## Features

* 'powerbash' command for configuration
* Bash completion support (powerbash [tab])
* Displays username, hostname, path, git information, jobs count, symbol ($/#), return code
* Color code for root, sudo, jobs count, return code
* Git information:
  * display current git branch name, or short SHA1 hash when the head is detached
  * display "+" symbol when current branch is changed but uncommited
  * display "⇡" symbol and the difference in the number of commits when the current branch is ahead of remote
  * display "⇣" symbol and the difference in the number of commits when the current branch is behind of remote
* Three directory shortening modes (/full/path/to/no/where):
  * /full/.../no/where
  * ..o/no/where
  * /f/p/t/n/where
* Fast execution (no noticable delay)
* No need for patched fonts

## Asciinema
[![asciicast](https://asciinema.org/a/30836.png)](https://asciinema.org/a/30836)

## Automated Installs

Global: `curl -s https://get.powerbash.org | sudo bash`

User: `curl -s https://get.powerbash.org | bash`

## Per-User Installation

Download the Bash script

    curl -Ls https://raw.githubusercontent.com/napalm255/powerbash/master/powerbash.sh > ~/.powerbash.sh

And source it in '~/.bashrc' for your user account

    source ~/.powerbash.sh

## Global Installation

Download the Bash script

    sudo curl -Ls https://raw.githubusercontent.com/napalm255/powerbash/master/powerbash.sh -o /etc/profile.d/z_powerbash.sh

Note:

    powerbash is most consistent when it is the last profile.d script to run.

