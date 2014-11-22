#!/bin/bash
# http://sgros.blogspot.com/2012/07/colors-in-terminal.html
for i in {0..255}; do tput setab $i; echo -n "  $i  "; done; tput setab 0; echo
