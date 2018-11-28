# 指定镜像源
FROM centos:centos7.4.1708

# 将工作目录设置为 /assets
WORKDIR /assets

# 将当前目录内容复制到位于 /assets 中的容器中
ADD assets /assets

RUN mkdir -p /packages

ENV ELASTIC_PORT 9200
ENV KIBANA_PORT 5601

ENV USERNAME es

# 安装Java包
RUN sh /assets/entrypoint.sh install_java

# 安装elasticsearch包
RUN sh /assets/entrypoint.sh install_elastic

# 安装kibana包
RUN sh /assets/entrypoint.sh install_kibana

# 配置supervisor
RUN sh /assets/entrypoint.sh configule_efk

# 使端口 9200 可供此容器外的环境使用
EXPOSE ${ELASTIC_PORT}
EXPOSE ${KIBANA_PORT}

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf", "-n"]
