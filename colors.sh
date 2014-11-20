#!/bin/bash

RESET="$(tput sgr0)"
X=0
if [ "$1" == "bg" ]; then
  while [ $X -lt 256 ]; do
    COLOR="$(tput setab $X)"
    echo "$COLOR    $X    "
    let X=X+1
  done
fi

if [ "$1" == "fg" ]; then
  X=0
  while [ $X -lt 256 ]; do
    COLOR="$(tput setaf $X)"
    echo "$COLOR    $X    "
    let X=X+1
  done
fi
echo "$RESET"
