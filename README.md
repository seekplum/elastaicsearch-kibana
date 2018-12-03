# Elasticsearch & Kibana 镜像

## 概要
通过shell脚本完成安装环境的准备，并把依赖环境都打包成docker镜像。

## 使用
* 后台运行

> docker run -d \-\-name elasticsearch-kibana -p 10015:10015 -p 10016:10016 seekplum/elasticsearch-kibana

* 调试

> docker run \--\rm -it -p 10015:10015 -p 10016:10016 seekplum/elasticsearch-kibana bash

## 注意
* 1.jdk包在线下载非常缓慢，在build镜像时建议先下载放入 `packages/jdk-8u181-linux-x64.rpm` 中, [官方下载地址](https://download.oracle.com/otn/java/jdk/8u181-b13/96a7b8442fe848ef90c96a2fad6ed6d1/jdk-8u181-linux-x64.rpm)
