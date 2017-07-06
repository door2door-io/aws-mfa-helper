#!/bin/bash

export GPG_TTY=$(tty)

echo "$1" | base64 -D | keybase pgp decrypt ; echo
