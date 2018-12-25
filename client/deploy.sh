#!/usr/bin/env bash
ELASTIC_HOST=192.168.1.78
ELASTIC_PORT=10015

ELASTIC_HOST1=10.10.100.38
ELASTIC_PORT1=10015

HOSTNAME=`hostname`

YUM_HOST=10.10.100.38
YUM_PORT=8080
GEM_PATH=/tmp/gem-cache
FLUENTD_PORT=24444

GRID_BASE=/opt/ogrid
GRID_HOME=/opt/grid/products/11.2.0
ORACLE_BASE=/opt/oracle
ORACLE_HOME=/opt/oracle/products/11.2.0
ORACLE_SID=+ASM1

DATABASE_NAME=orcl
INSTANCE_NAME=orcl1


TD_AGENT_PATH=/etc/td-agent
TD_AGENT_CONF=$TD_AGENT_PATH/conf.d
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
    mkdir -p $TD_AGENT_CONF

    cat >>$TD_AGENT_PATH/td-agent.conf<<EOF

@include conf.d/*.conf

<system>
  rpc_endpoint 127.0.0.1:$FLUENTD_PORT
</system>

EOF

    sed -i "s/TD_AGENT_USER=td-agent/TD_AGENT_USER=root/g" $TD_AGENT
    sed -i "s/TD_AGENT_GROUP=td-agent/TD_AGENT_GROUP=root/g" $TD_AGENT
  fi
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


configuration_crs_log() {
  print configuration_crs_log

  ip=$(get_loacl_ip)

  cat >$TD_AGENT_CONF/crs.conf <<EOF
<source>
  @type tail
  path $GRID_HOME/log/$HOSTNAME/alert$HOSTNAME.log
  pos_file $TD_AGENT_LOG_PATH/crs/crs.log.pos
  tag crs.log

  format multiline
  multiline_flush_interval 5s
  format_firstline /\d{4}-\d{1,2}-\d{1,2}/
  format1 /^(?<log_time>\d{4}-\d{1,2}-\d{1,2} \d{1,2}:\d{1,2}:\d{1,2})\.(?<line>\d+):(?<message>.*)/
  time_format %Y-%m-%d %H:%M:%S
</source>

<filter crs.log>
  @type record_transformer
  <record>
    hostname \${hostname}
    ip $ip
    log_type crs
  </record>
</filter>

<filter crs.log>
  @type dio
  keys log_time
</filter>

<match crs.log>
  @type copy
  @include crs.conf.d/*.conf
</match>
EOF

  mkdir -p $TD_AGENT_CONF/crs.conf.d
  cat >$TD_AGENT_CONF/crs.conf.d/$ELASTIC_HOST.conf <<EOF
<store>
  @type elasticsearch
  host $ELASTIC_HOST
  port $ELASTIC_PORT

  time_key time
  flush_interval 2s
  buffer_queue_limit 4096
  buffer_chunk_limit 1024m
  num_threads 4
  logstash_format true
</store>
EOF

  cat >$TD_AGENT_CONF/crs.conf.d/$ELASTIC_HOST1.conf <<EOF
<store>
  @type elasticsearch
  host $ELASTIC_HOST1
  port $ELASTIC_PORT1

  time_key time
  flush_interval 2s
  buffer_queue_limit 4096
  buffer_chunk_limit 1024m
  num_threads 4
  logstash_format true
</store>
EOF
}

configuration_asm_log() {
  print configuration_asm_log

	ip=$(get_loacl_ip)

  cat >$TD_AGENT_CONF/asm.conf <<EOF
<source>
  @type tail
  path $GRID_BASE/diag/asm/+asm/$ORACLE_SID/trace/alert_$ORACLE_SID.log
  pos_file $TD_AGENT_LOG_PATH/asm/asm.log.pos
  tag asm.log

  format multiline
  multiline_flush_interval 5s
  format_firstline /\w{3} \w{3} \d{2} \d{2}:\d{2}:\d{2} \d{4}/
  format1 /^\w{3} (?<log_time>\w{3} \d{2} \d{2}:\d{2}:\d{2} \d{4})(?<message>.*)/
  time_format %a %B %d %H:%M:%S %Y
</source>

<filter asm.log>
  @type record_transformer
  <record>
    hostname \${hostname}
    ip $ip
    log_type asm
  </record>
</filter>

<filter asm.log>
  @type dio
  keys log_time
</filter>

<match asm.log>
  @type elasticsearch
  host $ELASTIC_HOST
  port $ELASTIC_PORT


  time_format %a %B %d %H:%M:%S %Y
  time_key time
  flush_interval 2s
  buffer_queue_limit 4096
  buffer_chunk_limit 1024m
  num_threads 4
  logstash_format true
</match>
EOF
}


configuration_instance_log() {
  print configuration_instance_log
  ip=$(get_loacl_ip)

  cat >$TD_AGENT_CONF/instance.conf <<EOF
<source>
  @type tail
  path $ORACLE_BASE/diag/rdbms/$DATABASE_NAME/$INSTANCE_NAME/trace/alert_$INSTANCE_NAME.log
  pos_file $TD_AGENT_LOG_PATH/instance/instance.log.pos
  tag instance.log

  format multiline
  multiline_flush_interval 5s
  format_firstline /\w{3} \w{3} \d{2} \d{2}:\d{2}:\d{2} \d{4}/
  format1 /^\w{3} (?<log_time>\w{3} \d{2} \d{2}:\d{2}:\d{2} \d{4})(?<message>.*)/
  time_format %a %B %d %H:%M:%S %Y
</source>

<filter instance.log>
  @type record_transformer
  <record>
    hostname \${hostname}
    ip $ip
    log_type instance
  </record>
</filter>

<filter instance.log>
  @type dio
  keys log_time
</filter>

<match instance.log>
  @type elasticsearch
  host $ELASTIC_HOST
  port $ELASTIC_PORT

  
  time_format %a %B %d %H:%M:%S %Y
  time_key time
  flush_interval 2s
  buffer_queue_limit 4096
  buffer_chunk_limit 1024m
  num_threads 4
  logstash_format true
</match>
EOF
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
    echo "Usage: bash $0 { all | install_td_agent | install_elastic_plugin | install_date_plugin | configuration_crs_log | configuration_asm_log | configuration_instance_log }"
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

            configuration_crs_log
            configuration_asm_log
            configuration_instance_log
            ;;
          install_td_agent)
            install_td_agent
            ;;
          install_date_plugin)
            install_date_plugin
            ;;
          install_elastic_plugin)
            install_elastic_plugin
            ;;
          configuration_crs_log)
            configuration_crs_log
            ;;
          configuration_asm_log)
            configuration_asm_log
            ;;
          configuration_instance_log)
            configuration_instance_log
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
