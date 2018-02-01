# ELK安装配置
## Module Overview

以前系统里出现了异常，很大部分都是由业务人员或者用户发现再反馈到研发这边，然后研发查日志定位问题。缺少应用监控系统导致问题发现的不及时，甚至一些问题隐藏了很久才发现，造成了无谓的成本消耗和损失，而且日志文件太大定位起来也不方便。为了提高系统的可用性，及时发现线上异常，快速定位问题，需要对现有应用做一个可用性的监控，能及时报警，暴露问题。<br>
由于应用日志记录了所有的运行信息，我们只需要对日志做一个监控就能对应用的可用性做一个监控。目前公司有Java，Php，Python构成的系统，以后随着服务和应用的增加，虚拟机和容器的运用，监控源势必还会增加。为了对这种需求，一个统一的集中式监控系统是很有必要的。对各系统用同一套方案完成日志采集，日志存储，日志分析，目前有开源的ELK Stack（Elastcsearch, Logstash,Kibana）框架已经得到了不少公司的运用。日志监控框架的意义不仅仅可以监控Tomcat等应用日志，而且可以应用到数据库，http服务器，操作系统等，可以按需求灵活运用，比如可以用来监控Http 500的错误，mysql的连接数等信息，再后来和大数据分析结合.<br>
ELK是Elastic的三个开源产品，其中Logstash（server-side data processing pipeline）用于日志的收集，传输;Elasticsearch（highly scalable open-source full-text search and analytics engine）用于数据存储，分析;Kibana（analytics and visualization platform ）用于前端展示。下面是这个框架的特点

* 配置简单：采用业界通用配置语法设计
* 检索性能高效：Elasticsearch可以达到百亿级数据查询的秒级响应
* 集群线性扩展：Elasticssearch集群和Logstash集群都是可以线性扩展的
* 前端展示绚丽：Kibana可以在Elasticsearch的索引中查找，生成各种图表
* 三个工具紧密结合：由同一个公司提供，无缝衔接，便于安装使用
* 强大的日志搜索分析：除了报警，引入框架的目的其实更多是为了做分析统计工作，ELK可以和Hadoop集成做更专业的数据分析
* 因为Logstash需要在每台机器上都部署，而网上有文章说Logstash的资源开销大，可以换成Fluent/Flume/beat等开源框架代替

上面ELK的方案是一套比较完善的，重的方案。针对目前现状，也可以先采用一套轻的，快速的方案过渡一下。具体到Java项目，思路如下：

* 用log4j自带的email功能通知异常发生。自定义一些Appender和Logger，在特定异常发生时发邮件通知。比较适用于定时任务，好处是实时通知，不足的地方是不适用于接口等发送频率很高的场景，否则占用服务器资源而且邮件会堆积。需要针对不同的场景定义很多不同的log appender。
* 可以实现一个shell脚本定时读取应用日志，提取特定错误信息，然后发邮件通知。

## Module Design

###  临时方案

* 对于需要实时性比较高的异常通知，可以在异常发生时，把异常日志用log4j的邮件Appender发给特定人员,比较适合一天几次的定时任务
```Java
    <appender name="MAIL"  class="org.apache.log4j.net.SMTPAppender">  
        <param name="Threshold" value="ERROR" />  
          <!-- 缓存文件大小，日志达到0K时发送Email,单位k -->  
        <param name="BufferSize" value="0" />  
        <param name="From" value="zjhgx163@163.com" />  
        <param name="SMTPHost" value="smtp.163.com" />  
        <param name="Subject" value="hugaoxiang-log4jMessage" />  
        <param name="To" value="hugaoxiang@ichuangshun.com" />  
        <param name="SMTPUsername" value="zjhgx163@163.com" />  
        <param name="SMTPPassword" value="xxxxxxxxxxxxx" />  
        <param name="SMTPDebug" value="false" />          
        <layout class="org.apache.log4j.PatternLayout">  
            <param name="ConversionPattern"  value="[framework]%d - %c -%-4r[%t]%-5p %c %x -%m%n" />  
        </layout>
        <filter class="org.apache.log4j.varia.LevelRangeFilter">
            <param name="LevelMax" value="ERROR" />
            <param name="LevelMin" value="ERROR" />
        </filter>        
    </appender>
```

* 对于其他异常，可以写一个定时执行的shell脚本去监控Tomcat的日志文件（比如一小时一次），如果脚本发现有异常，那就发邮件通知
* 脚本需要记住扫描到的日志行数，下次执行时继续往下扫描
* Linux需要安装mailutils
```Shell
  -- grep 'Error' /usr/local/javaapp/tomcat8080/logs/catalina.out > error.log
```  

###  统一方案

ELK+Beats
流程图：
![]( https://github.com/zjhgx/archecture_zjhgx/blob/master/ELK/%E6%97%A5%E5%BF%97%E7%9B%91%E6%8E%A7%E6%B5%81%E7%A8%8B.png )

#### Filebeat
用于日志收集和传输：reliability and low latency

##### 安装
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.1.2-linux-x86_64.tar.gz<br>
tar xzvf filebeat-6.1.2-linux-x86_64.tar.gz

##### 配置
filebeat.yml
```yml
filebeat.prospectors:
- type: log
  enabled: true
  paths:
    - /path/to/file/logstash-tutorial.log 
output.logstash:
  hosts: ["localhost:5044"]
```

##### 运行
sudo ./filebeat -e -c filebeat.yml -d "publish"

#### Logstash
Logstash用于提取需要的日志再存入Elasticsearch

##### 安装
curl -L -O https://artifacts.elastic.co/downloads/logstash/logstash-6.1.2.tar.gz<br>
tar xzvf logstash-6.1.2.tar.gz

##### 配置
新建文件/conf/pipline.conf
```
# The # character at the beginning of a line indicates a comment. Use
# comments to describe your configuration.
input {
 beats {
        port => "5044"
    }
}
# The filter part of this file is commented out to indicate that it is
# optional.
# filter {
#
# }
output {
	stdout { codec => rubydebug }
}
```

##### 运行
检测配置：bin/logstash -f first-pipeline.conf --config.test_and_exit<br>
运行：bin/logstash -f first-pipeline.conf --config.reload.automatic

##### 过滤
Grok filter plugin:Parse arbitrary text and structure it.<br>
Logstash ships with about 120 patterns by default:https://github.com/logstash-plugins/logstash-patterns-core/blob/master/patterns/grok-patterns<br> 
building patterns to match your logs:http://grokdebug.herokuapp.com and http://grokconstructor.appspot.com/<br>
grok pattern:%{SYNTAX:SEMANTIC} SEMANTIC:identifier you give to the piece of text being matched.<br>
>例： 3.44 55.3.244.1  %{NUMBER:duration} %{IP:client}<br>
>%{NUMBER:num:int}:converts the num semantic from a string to an integer




#### Elasticsearch

#### Kibana

##### X-Pack     

X-Pack提供了ELK的增强工具，报警是其中之一功能，按照官网的说法，可以定义一些watcher scheduler定时在Elasticsearch中检索，根据结果和触发条件选择Action发出提醒

```
PUT _xpack/watcher/watch/log_error_watch
{
  "trigger" : {
    "schedule" : { "interval" : "10s" } 
  },
  "input" : {
    "search" : {
      "request" : {
        "indices" : [ "logs" ],
        "body" : {
          "query" : {
            "match" : { "message": "error" }
          }
        }
      }
    }
  }
}
```

##### Kafka
如果数据量大，可以加入Kafka