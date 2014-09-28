#!/usr/bin/sh
if ! [ -d .themis ]; then
    git clone https://github.com/thinca/vim-themis .themis
fi

./.themis/bin/themis --recursive
