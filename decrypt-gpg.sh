#!/bin/bash

export GPG_TTY=$(tty)

GPG=$(which gpg || which gpg2)

echo "$1" | base64 -D | ${GPG} -d ; echo
