# 指定镜像源
FROM centos:centos7.4.1708

RUN mkdir -p /packages

RUN yum install -y wget

# 将当前目录内容复制到位于 /assets 中的容器中
ADD assets /assets
ADD packages /packages

# 设置环境变量
ENV ELASTIC_PORT 10015
ENV KIBANA_PORT 10016

ENV USERNAME es

# 设置工作目录
WORKDIR /home/${USERNAME}

# 安装Java包
RUN sh /assets/entrypoint.sh install_java

# 安装elasticsearch包
RUN sh /assets/entrypoint.sh install_elastic

# 安装kibana包
RUN sh /assets/entrypoint.sh install_kibana

# 配置supervisor
RUN sh /assets/entrypoint.sh configule_efk

# 设置容器对外开放端口
EXPOSE ${ELASTIC_PORT}
EXPOSE ${KIBANA_PORT}

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf", "-n"]
