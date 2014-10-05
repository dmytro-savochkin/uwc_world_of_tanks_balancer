#!/usr/bin/env bash

sudo apt-get install curl <<-EOF
yes
EOF
curl -sSL https://get.rvm.io | bash -s $1