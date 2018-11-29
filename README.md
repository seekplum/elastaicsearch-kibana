# Elasticsearch & Kibana 镜像

## 概要
通过shell脚本完成安装环境的准备，并把依赖环境都打包成docker镜像。

## 使用
* 后台运行

> docker run -d \-\-name elastaicsearch-kibana -p 10015:10015 -p 10016:10016 elastaicsearch-kibana

* 调试

> docker run \--\rm -it -p 10015:10015 -p 10016:10016 elastaicsearch-kibana bash