#!/usr/bin/env zsh

mkdir -p ~/Dropbox/$(whoami)/Bucket/.archives/wmx
rsync --archive --progress ~/wmx/ ~/Dropbox/$(whoami)/Bucket/.archives/wmx
