#!/usr/bin/env bash

yum install -y sudo

curl -L https://toolbelt.treasuredata.com/sh/install-redhat-td-agent2.sh | sh

yum install -y libcurl-devel gcc

td-agent-gem install fluent-plugin-dio

td-agent-gem install fluent-plugin-elasticsearch

rm -rf /tmp/gem-cache

cp -r /opt/td-agent/embedded/lib/ruby/gems/2.1.0/cache /tmp/gem-cache

