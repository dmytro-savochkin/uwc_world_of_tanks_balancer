#!/usr/bin/env bash

sudo apt-get -y install curl
curl -sSL https://get.rvm.io | bash -s stable
source /usr/local/rvm/scripts/rvm
rvm use --install 2.0.0
shift
gem install bundler
gem install rake
gem install sinatra
gem install haml
gem install json
bundle install
