# powerbash

Powerline-style Bash prompt in pure Bash script. 


## Features

* Git branch: display current git branch name, or short SHA1 hash when the head is detached
* Git branch: display "+" symbol when current branch is changed but uncommited
* Git branch: display "⇡" symbol and the difference in the number of commits when the current branch is ahead of remote
* Git branch: display "⇣" symbol and the difference in the number of commits when the current branch is behind of remote
* Username displayed
* Hostname displayed only when SSH'd
* Color code for root
* Color code for sudo session
* Color code with exit code for the previously failed command
* Color code with jobs count
* Directory shortening ('/some/.../long/path' or '..me/long/path')
* Fast execution (no noticable delay)
* No need for patched fonts

## Screenshot
![powerbash](/../screenshots/screenshot.png?raw=true "powerbash")

## Installation

Download the Bash script

    curl -L https://raw.githubusercontent.com/napalm255/powerbash/master/powerbash.sh > ~/.powerbash.sh

And source it in your `.bashrc` for your user account

    source ~/.powerbash.sh

or for a global installation create a soft link in /etc/profiles.d

    ln -s /etc/profiles.d/powerbash.sh ./powerbash.sh
