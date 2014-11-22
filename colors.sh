#!/bin/bash
for i in {0..255}; do tput setab $i; echo -n " $i "; done; tput setab 0; echo
