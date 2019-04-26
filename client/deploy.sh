#!/usr/bin/env bash
RETVAL=0
current_path=`pwd`
file_path=$(dirname $0)

YUM_HOST=127.0.0.1
YUM_PORT=8080
GEM_PATH=$file_path/gem-cache
FLUENTD_PORT=24444

PROMETHEUS_PORT=24231

TD_AGENT_PATH=/etc/td-agent
TD_AGENT_CONF_PATH=$TD_AGENT_PATH/td-agent.conf
TD_AGENT_CONFD=$TD_AGENT_PATH/conf.d
TD_AGENT=/etc/init.d/td-agent

TD_AGENT_LOG_PATH=/var/log/td-agent


install_td_agent() {
  print install_td_agent
  $TD_AGENT stop >/dev/null 2&>1

	cat >/etc/yum.repos.d/loacl-rpms.repo <<EOF
[td-agent]
name=Server
baseurl=http://$YUM_HOST:$YUM_PORT
enable=1
gpgcheck=0
EOF

  number=$(rpm -qa | grep td-agent | wc -l)
  if [ ! $number -gt 0 ];then
    yum install -y td-agent
  fi
  cat >>$TD_AGENT_CONF_PATH<<EOF

@include conf.d/*.conf

<system>
  rpc_endpoint 127.0.0.1:$FLUENTD_PORT
</system>

<source>
  @type prometheus
  bind 0.0.0.0
  port $PROMETHEUS_PORT
  metrics_path /metrics
</source>
<source>
  @type prometheus_output_monitor
  interval 10
  <labels>
    hostname \${hostname}
  </labels>
</source>
EOF

  mkdir -p $TD_AGENT_CONFD
  sed -i "s/TD_AGENT_USER=td-agent/TD_AGENT_USER=root/g" $TD_AGENT
  sed -i "s/TD_AGENT_GROUP=td-agent/TD_AGENT_GROUP=root\nRUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR=0.9/g" $TD_AGENT
}

install_libcurl() {
  number=$(rpm -qa | grep ^libcurl-devel | wc -l)
  if [ ! $number -gt 0 ];then
      yum install -y libcurl-devel
  fi
}

install_gcc() {
  number=$(rpm -qa | grep ^gcc | wc -l)
  if [ ! $number -gt 0 ];then
      yum install -y gcc
  fi
}


install_elastic_plugin() {
  print install_elastic_plugin
  install_libcurl
  install_gcc

	if [ ! -f $GEM_PATH/fluent-plugin-elasticsearch*.gem ];then
		echo -e "\033[31mno such directory $GEM_PATH\033[0m"
	else
      number=$(td-agent-gem list | grep fluent-plugin-elasticsearch | wc -l)
      if [ ! $number -gt 0 ];then
            cd $GEM_PATH && td-agent-gem install fluent-plugin-elasticsearch*.gem --local
      fi
	fi
}

install_prometheus_plugin() {
  print install_prometheus_plugin
  if [ ! -f $GEM_PATH/fluent-plugin-prometheus*.gem ];then
    echo -e "\033[31mno such directory $GEM_PATH/fluent-plugin-prometheus*.gem\033[0m"
  else
    number=$(td-agent-gem list | grep fluent-plugin-prometheus | wc -l)
    if [ ! $number -gt 0 ];then
        cd $GEM_PATH && td-agent-gem install fluent-plugin-prometheus*.gem --local
    fi
  fi
}


install_http_plugin() {
  print fluent-plugin-out-http
  if [ ! -f $GEM_PATH/fluent-plugin-out-http*.gem ];then
    echo -e "\033[31mno such directory $GEM_PATH/fluent-plugin-out-http*.gem\033[0m"
  else
    number=$(td-agent-gem list | grep fluent-plugin-out-http | wc -l)
    if [ ! $number -gt 0 ];then
        cd $GEM_PATH && td-agent-gem install fluent-plugin-out-http*.gem --local
    fi
  fi
}

install_date_plugin() {
  print install_date_plugin
  install_libcurl
  install_gcc

  if [ ! -f $GEM_PATH/fluent-plugin-dio*.gem ];then
    echo -e "\033[31mno such directory $GEM_PATH/fluent-plugin-dio*.gem\033[0m"
  else
    number=$(td-agent-gem list | grep fluent-plugin-dio | wc -l)
    if [ ! $number -gt 0 ];then
        cd $GEM_PATH && td-agent-gem install fluent-plugin-dio*.gem --local
    fi
  fi
}

get_loacl_ip() {
	ip=`ip a | grep inet | grep -v "127.0.0.1" | grep -v "::1" | grep -v "ib" | grep -v "docker" | grep -v "inet6 "| grep -v ":" | awk '{print$2}' | awk -F "/" '{print $1}'`
	echo $ip
}

print () {
    echo -e "\033[32m$1\033[0m"
}

# 打印帮助信息
print_help() {
    echo "Usage: bash $0 { all | install_td_agent | install_plugin }"
    echo -e "\033[32me.g: bash $0 install_td_agent\033[0m"
}

check_params() {
	if [ $# == 0 ]; then
		print_help
		exit 0
    fi

    for argument in $*
    do
       if [ "${argument}" == "-h" ] || [ "${argument}" == "--help" ]; then
           print_help
           exit 0
       fi
    done
}

main() {
    for func_name in $*
    do
        case "${func_name}" in
          all)
            install_td_agent

            install_elastic_plugin
            install_date_plugin
            install_prometheus_plugin
            install_http_plugin
            ;;
          install_plugin)
            install_elastic_plugin
            install_date_plugin
            install_prometheus_plugin
            install_http_plugin
            ;;
          install_td_agent)
            install_td_agent
            ;;
          install_elastic_plugin)
            install_elastic_plugin
            ;;
          install_date_plugin)
            install_date_plugin
            ;;
          install_prometheus_plugin)
            install_prometheus_plugin
            ;;
          install_http_plugin)
            install_http_plugin
            ;;
          *)  # 匹配都失败执行
            print_help
            exit 1
        esac
    done  
}

check_params $*
main $*
exit $?
