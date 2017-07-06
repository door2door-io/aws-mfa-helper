#!/bin/bash

export GPG_TTY=$(tty)

echo "$1" | base64 -D | gpg -d ; echo
