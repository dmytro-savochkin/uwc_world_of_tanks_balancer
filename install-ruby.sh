#!/usr/bin/env bash

sudo apt-get -y install curl
\curl -L https://get.rvm.io | bash -s stable --ruby
sudo rvm install ruby-2.0.0-p576
rvm use ruby-2.0.0-p576
gem install bundler
gem install rake
gem install sinatra
gem install haml
gem install json
bundle install
