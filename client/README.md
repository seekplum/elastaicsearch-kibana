# 客户端安装软件

## 前言
该脚本时为了在无外网的情况下快速在客户端部署td-agent采集程序。

## 准备条件
* 1.准备yum源用于安装`td-agent`, `libcurl-devel`, `gcc`
* 2.指定elastic服务地址和端口
* 3.准备gem包到对应的`gem-cache`目录

## 无外网自动化安装软件
* td-agent: 收集日志程序
* fluent-plugin-elasticsearch: 把fluentd收集日志发送到elastic
* fluent-plugin-dio: 把日期字符串转成时间戳

## 使用

### 查看帮助
> bash deploy.sh -h

### 安装td-agent和elastic插件
> bash deploy.sh install_td_agent install_elastic_plugin
