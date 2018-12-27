#!/usr/bin/env bash
RETVAL=0
current_path=`pwd`
file_path=$(dirname $0)

print () {
    echo -e "\033[32m$1\033[0m"
}

install_env() {
    print "install env"
    yum install -y sudo
    yum install -y libcurl-devel gcc
}

install_target() {
    print "install target"
    # curl -L https://toolbelt.treasuredata.com/sh/install-redhat-td-agent2.sh | sh
    bash $file_path/deploy.sh install_td_agent
}

install_plugin () {
    print "install plugin"
    td-agent-gem install fluent-plugin-elasticsearch
    td-agent-gem install fluent-plugin-dio
    td-agent-gem install fluent-plugin-out-http
    td-agent-gem install fluent-plugin-prometheus
}

copy_gem_cache() {
    print "copy gem chache"
    rm -rf /tmp/gem-cache
    cp -r /opt/td-agent/embedded/lib/ruby/gems/2.1.0/cache /tmp/gem-cache
}

install_env
install_target
install_plugin
copy_gem_cache
print "done!"
exit $RETVAL
