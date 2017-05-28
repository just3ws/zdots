#!/usr/bin/env zsh

[ -d ./.git ] && git rev-parse --abbrev-ref HEAD
