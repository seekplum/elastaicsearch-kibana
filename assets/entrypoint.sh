#!/usr/bin/env bash
export USERNAME=es
export ELASTIC_PORT=10015
export KIBANA_PORT=10016

download_java() {
  if [ ! -f "/packages/jdk-8u181-linux-x64.rpm" ];then
    wget -O /packages/jdk-8u181-linux-x64.rpm https://download.oracle.com/otn/java/jdk/8u181-b13/96a7b8442fe848ef90c96a2fad6ed6d1/jdk-8u181-linux-x64.rpm?AuthParam=1543413393_894d6cfda13de149ae7f09980303ae1a
  fi
}

download_elastic() {
  if [ ! -f "/packages/elasticsearch-6.4.1.tar.gz" ];then
    wget -O /packages/elasticsearch-6.4.1.tar.gz https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.4.1.tar.gz
  fi
}

download_kibana() {
  if [ ! -f "/packages/kibana-6.4.1-linux-x86_64.tar.gz" ];then
    wget -O /packages/kibana-6.4.1-linux-x86_64.tar.gz https://artifacts.elastic.co/downloads/kibana/kibana-6.4.1-linux-x86_64.tar.gz
  fi
}

create_user() {
  id $USERNAME || useradd -m $USERNAME
}

set_map_count() {
  sed -ie "/vm.max_map_count*=*/d" /etc/sysctl.conf
  echo "vm.max_map_count=262144" >> /etc/sysctl.conf
  sysctl -p
}

set_limits() {
  sed -ie "/\* soft nofile 65536/d" /etc/security/limits.conf
  sed -ie "/\* hard nofile 131072/d" /etc/security/limits.conf
  sed -ie "/\* soft nproc 16384/d" /etc/security/limits.conf
  sed -ie "/\* hard nproc 16384/d" /etc/security/limits.conf

  cat >>/etc/security/limits.conf <<EOF
* soft nofile 65536
* hard nofile 131072
* soft nproc 16384
* hard nproc 16384
EOF
}

install_java() {
  download_java
  
  rpm -qa | grep -i java | xargs rpm -e --nodeps

  rpm -ivh /packages/jdk-8u181-linux-x64.rpm
}

tar_elastic(){
  tar zxvf /packages/elasticsearch-6.4.1.tar.gz -C /home/$USERNAME

  sed -ie "s/.*http.port:.*/http.port: $ELASTIC_PORT/" /home/$USERNAME/elasticsearch-6.4.1/config/elasticsearch.yml
  sed -ie "s/.*network.host:.*/network.host: 0.0.0.0/" /home/$USERNAME/elasticsearch-6.4.1/config/elasticsearch.yml

  chown -R $USERNAME:$USERNAME /home/$USERNAME/elasticsearch-6.4.1/
}

install_elastic() {
  create_user
  download_elastic
  set_limits
  set_map_count
  tar_elastic
}

install_kibana() {
  tar zxvf /packages/kibana-6.4.1-linux-x86_64.tar.gz -C /home/$USERNAME

  sed -ie "s/.*server.port:.*/server.port: $KIBANA_PORT/" /home/$USERNAME/kibana-6.4.1-linux-x86_64/config/kibana.yml
  sed -ie "s/.*server.host:.*/server.host: \"0.0.0.0\"/" /home/$USERNAME/kibana-6.4.1-linux-x86_64/config/kibana.yml
  sed -ie "s/.*elasticsearch.url:.*/elasticsearch.url: \"http:\/\/localhost:$ELASTIC_PORT\"/" /home/$USERNAME/kibana-6.4.1-linux-x86_64/config/kibana.yml

  chown -R $USERNAME:$USERNAME /home/$USERNAME/kibana-6.4.1-linux-x86_64
}

install_supervisor() {
  easy_install --index-url=http://pypi.douban.com/simple  pip
  pip install supervisor

  mkdir -p /home/$USERNAME/sock/
  mkdir -p /home/$USERNAME/logs/
  mkdir -p /etc/conf.d/

  cat >/etc/supervisord.conf<<EOF
[unix_http_server]
file=/home/$USERNAME/sock/sendoh_supervisor.sock   ; (the path to the socket file)

[supervisord]
logfile=/home/$USERNAME/logs/supervisord.log ; (main log file;default $CWD/supervisord.log)
logfile_maxbytes=50MB        ; (max main logfile bytes b4 rotation;default 50MB)
logfile_backups=10           ; (num of main logfile rotation backups;default 10)
loglevel=info                ; (log level;default info; others: debug,warn,trace)
pidfile=/home/$USERNAME/sock/sendoh_supervisord.pid ; (supervisord pidfile;default supervisord.pid)
nodaemon=false               ; (start in foreground if true;default false)
minfds=65536
minprocs=32768
user=$USERNAME

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///home/$USERNAME/sock/sendoh_supervisor.sock ; use a unix:// URL  for a unix socket

[include]
files = conf.d/*.conf
EOF
}

configule_efk() {
  install_supervisor

  cat >/etc/conf.d/supervisor_efk.conf<<EOF
[program:elasticsearch]
command=/home/$USERNAME/elasticsearch-6.4.1/bin/elasticsearch
user=$USERNAME
minfds=65536
minprocs=32768
process_name=%(program_name)s ; process_name expr (default %(program_name)s)
numprocs=1                    ; number of processes copies to start (def 1)
redirect_stderr=true          ; redirect proc stderr to stdout (default false)
stdout_logfile=/home/$USERNAME/logs/elasticsearch.log
stdout_logfile_maxbytes=1MB   ; max # logfile bytes b4 rotation (default 50MB)
stdout_logfile_backups=10     ; # of stdout logfile backups (default 10)
stdout_capture_maxbytes=1MB   ; number of bytes in 'capturemode' (default 0)
stdout_events_enabled=false   ; emit events on stdout writes (default false)
directory=/home/$USERNAME/elasticsearch-6.4.1

[program:kibana]
command=/home/$USERNAME/kibana-6.4.1-linux-x86_64/bin/kibana
process_name=%(program_name)s ; process_name expr (default %(program_name)s)
user=es
numprocs=1                    ; number of processes copies to start (def 1)
redirect_stderr=true          ; redirect proc stderr to stdout (default false)
stdout_logfile=/home/$USERNAME/logs/kibana.log
stdout_logfile_maxbytes=1MB   ; max # logfile bytes b4 rotation (default 50MB)
stdout_logfile_backups=10     ; # of stdout logfile backups (default 10)
stdout_capture_maxbytes=1MB   ; number of bytes in 'capturemode' (default 0)
stdout_events_enabled=false   ; emit events on stdout writes (default false)
directory=/home/$USERNAME/kibana-6.4.1-linux-x86_64
EOF
}

# 打印帮助信息
print_help() {
    echo "Usage: bash $0 { install_java | install_elastic | install_kibana | configule_efk }"
    echo "e.g: bash $0 install_java"
}

check_params() {
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
          install_java)
            install_java
            ;;
          install_elastic)
            install_elastic
            ;;
          install_kibana)
            install_kibana
            ;;
          configule_efk)
            configule_efk
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
