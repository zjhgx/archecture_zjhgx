# ELK安装配置
## Module Overview

以前系统里出现了异常，很大部分都是由业务人员或者用户发现再反馈到研发这边，然后研发查日志定位问题。缺少应用监控系统导致问题发现的不及时，甚至一些问题隐藏了很久才发现，造成了无谓的成本消耗和损失，而且日志文件太大定位起来也不方便。为了提高系统的可用性，及时发现线上异常，快速定位问题，需要对现有应用做一个可用性的监控，能及时报警，暴露问题。<br>

由于应用日志记录了所有的运行信息，我们只需要对日志做一个监控就能对应用的可用性做一个监控。目前公司有Java,Php，Python构成的系统，以后随着服务和应用的增加，虚拟机和容器的运用，监控源势必还会增加。为了对这种需求，一个统一的集中式监控系统是很有必要的。对各系统用同一套方案完成日志采集，日志存储，日志分析，目前有开源的ELK Stack（Elastcsearch, Logstash,Kibana）框架已经得到了不少公司的运用。日志监控框架的意义不仅仅可以监控Tomcat等应用日志，而且可以应用到数据库，http服务器，操作系统等，可以按需求灵活运用，比如可以用来监控Http 500的错误，mysql的连接数等信息，再后来和大数据分析结合.<br>

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
注意点：<br>
* 对于各应用最好采用统一的日志格式，比如时间，有的应用是HH:mm:ss.SSS，而有的是yyyy-MM-dd HH:mm:ss.SSS，这样会给日志解析带来不便

#### Filebeat
用于日志收集和传输：reliability and low latency

###### 安装
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.1.2-linux-x86_64.tar.gz<br>
tar xzvf filebeat-6.1.2-linux-x86_64.tar.gz<br>
sudo ./filebeat -e -c filebeat.yml -d "publish" --strict.perms=false<br>
启动成功：
```
2018/02/23 12:40:33.674269 processor.go:275: DBG [publish] Publish event: {
  "@timestamp": "2018-02-23T12:40:33.674Z",
  "@metadata": {
    "beat": "filebeat",
    "type": "doc",
    "version": "6.1.2"
  },
  "prospector": {
    "type": "log"
  },
  "beat": {
    "name": "vobile-ThinkPad-X1-Carbon-2nd",
    "hostname": "vobile-ThinkPad-X1-Carbon-2nd",
    "version": "6.1.2"
  },
  "source": "/home/vobile/Downloads/logstash-tutorial-dataset",
  "offset": 24464,
  "message": "86.1.76.62 - - [04/Jan/2015:05:30:37 +0000] \"GET /style2.css HTTP/1.1\" 200 4877 \"http://www.semicomplete.com/projects/xdotool/\" \"Mozilla/5.0 (X11; Linux x86_64; rv:24.0) Gecko/20140205 Firefox/24.0 Iceweasel/24.3.0\""
}

```

###### 配置
filebeat.yml,需要把多行异常信息的Event合并成一个Event
```yml
filebeat.prospectors:
- type: log
  enabled: true
  paths:
    - /home/vobile/bin/apache-tomcat-8.0.37/logs/catalina.out 
 # The regexp Pattern that has to be matched. The example pattern matches all lines starting with [
 # multiline.pattern: '^%{HOUR}:?%{MINUTE}(?::?%{SECOND})'
 # TOMCAT_DATESTAMP 20%{YEAR}-%{MONTHNUM}-%{MONTHDAY} %{HOUR}:?%{MINUTE}(?::?%{SECOND}) %{ISO8601_TIMEZONE}不支持啊
   multiline.pattern: '^[0-9]{4}-[0-9]{2}-[0-9]{2}'

  # Defines if the pattern set under pattern should be negated or not. Default is false.
  multiline.negate: true

  # Match can be set to "after" or "before". It is used to define if lines should be append to a pattern
  # that was (not) matched before or after or as long as a pattern is not matched based on negate.
  # Note: After is the equivalent to previous and before is the equivalent to to next in Logstash
  multiline.match: after
name: java-1  
output.logstash:
  hosts: ["localhost:5044"]
```

#### Logstash
Logstash用于提取需要的日志再存入Elasticsearch,其过程就是把日志按格式解析成一个一个字段，然后存入ES可以利用ES根据条件搜索这些字段.

###### 安装
curl -L -O https://artifacts.elastic.co/downloads/logstash/logstash-6.1.2.tar.gz<br>
tar xzvf logstash-6.1.2.tar.gz

###### 配置
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
filter {
    grok {
#               "message" => ["%{JAVASTACKTRACEPART}","Caused by: (?<cause_exception>.*):(?<cause_errormsg>.*)","(?<exception>((?<!Exception).)*Exception):(?<errormsg>.*)","%{HOUR}:?%{MINUTE}(?::?%{SECOND}) \[(?<thread_id>.*)\] %{LOGLEVEL:level} %{JAVACLASS:class} - (?<exception_msg>.*)"]
#                "message" => "%{HOUR}:?%{MINUTE}(?::?%{SECOND}) \[(?<thread_id>.*)\] %{LOGLEVEL:level} %{JAVACLASS:logger} - (?<exception_msg>((?<!\\n).)*)\\n(?<exception>((?<!Exception).)*Exception):(?<errormsg>((?<!\\n\\t).)*)\\n\\t%{JAVASTACKTRACEPART}(?<strak_trace>((?<!Caused by).)*)\\n(?<causedby_exception>Caused by:.*)"
#               "message" => ["%{HOUR}:?%{MINUTE}(?::?%{SECOND}) \[(?<thread_id>.*)\] %{LOGLEVEL:level} %{JAVACLASS:logger} - (?<exception_msg>((?<!\n).)*)\n(?<exception>((?<!Exception).)*Exception):(?<errormsg>((?<!\n\t).)*)\n\t%{JAVASTACKTRACEPART}(?<stack_trace>((?<!Caused by).)*)\n(?<causedby_exception>Caused by:.*)","^%{TIMESTAMP_ISO8601} \[(?<thread_id>.*)\] %{LOGLEVEL:level}: %{JAVACLASS:logger}#(?<method>.*) : \n(?<exception>.*Exception)\n\t%{JAVASTACKTRACEPART}(?<stack_trace>((?<!Caused by).)*)(?<causedby_exception>(Caused by:)?.*)"]
                "message" => ["%{HOUR}:?%{MINUTE}(?::?%{SECOND}) \[(?<thread_id>.*)\] %{LOGLEVEL:level} %{JAVACLASS:logger} - (?<exception_msg>((?<!\n).)*)\n(?<exception>((?<!Exception).)*Exception):(?<errormsg>((?<!\n\t).)*)\n\t%{JAVASTACKTRACEPART}(?<stack_trace>((?<!Caused by).)*)\n(?<causedby_exception>Caused by:.*)?","^%{TIMESTAMP_ISO8601} \[(?<thread_id>.*)\] %{LOGLEVEL:level}: %{JAVACLASS:logger}#(?<method>.*) : (?<msg>((?<!\n).)*)?\n(?<exception>((?<!Exception).)*)(?<errormsg>((?<!\n).)*)?((?<!\tat).)*\n\t%{JAVASTACKTRACEPART}(?<stack_trace>(.(?!Caused by))*)\n(?<causedby_exception>Caused by.*)?"]
        }
    }

    geoip {
        source => "clientip"
    }
}

output {
#       stdout { codec => rubydebug }
		#如果解析失败说明不是需要的日志
        if "_grokparsefailure" not in [tags] {
                elasticsearch {
                        hosts => [ "localhost:9200" ]
                        user => "elastic"
                        password => "*******"
                }
        }

}

```
setting value type:

###### 运行
检测配置：bin/logstash -f ../conf/pipline.conf --config.test_and_exit<br>
运行：bin/logstash -f ../conf/pipline.conf --config.reload.automatic<br>
注：ES有执行脚本的能力，因安全因素，不能在root用户下运行，强行运行会报如下错误：<br>
org.elasticsearch.bootstrap.StartupException: java.lang.RuntimeException: can not run elasticsearch as root<br>
解决方案：<br>
groupadd es #增加es组;useradd es -g es -p pwd          #增加es用户并附加到es组  chown -R es:es elasticsearch-6.2.2          #给目录权限 su es          #使用es用户  ./bin/elasticsearch -d          #后台运行es<br>

外网访问<br>

vi conf/elasticsearch.yml<br>

修改network.host: 0.0.0.0<br>

再次启动ES出现如下类似错误<br>

ERROR: [3] bootstrap checks failed
[1]: max number of threads [1024] for user [es] is too low, increase to at least [4096]
[2]: max virtual memory areas vm.max_map_count [65530] is too low, increase to at least [262144]
[3]: system call filters failed to install; check the logs and fix your configuration or disable system call filters at your own risk

>[3] bootstrap checks failed<br>
>[3]: system call filters failed to install; check the logs and fix your configuration or disable system call filters at your own risk<br>
>原因：这是在因为Centos6不支持SecComp，而ES5.2.0默认bootstrap.system_call_filter为true进行检测，所以导致检测失败，失败后直接导致ES不能启动。
>解决：在elasticsearch.yml中配置bootstrap.system_call_filter为false，注意要在Memory下面:
bootstrap.memory_lock: false
bootstrap.system_call_filter: false

>[2]: max virtual memory areas vm.max_map_count [65530] is too low, increase to at least [262144]
>解决：切换到root用户修改配置sysctl.conf 添加下面配置：vm.max_map_count=655360  并执行命令：sysctl -p

>[1]: max number of threads [1024] for user [es] is too low, increase to at least [4096]
>解决：切换到root用户，进入limits.d目录下修改配置文件。vi /etc/security/limits.d/90-nproc.conf 修改如下内容为： * soft nproc 4096  

>max file descriptors [65535] for elasticsearch process is too low, increase to at least [65536]<br>
>解决方案<br>
>1、vi /etc/sysctl.conf<br>
>设置fs.file-max=655350<br>
>保存之后sysctl -p使设置生效<br>

>2、vi /etc/security/limits.conf 新增<br>

>* soft nofile 655350<br>

>* hard nofile 655350<br>

3、重新使用SSH登录，再次启动elasticsearch即可。<br>

外网访问：serverip:9200/<br>

###### 日志解析
Grok filter plugin:Parse arbitrary text and structure it.<br>
Logstash ships with about 120 patterns by default:https://github.com/logstash-plugins/logstash-patterns-core/blob/master/patterns/grok-patterns<br> 
building patterns to match your logs:http://grokdebug.herokuapp.com and http://grokconstructor.appspot.com/<br>
grok pattern:%{SYNTAX:SEMANTIC} SEMANTIC:identifier you give to the piece of text being matched.<br>
>55.3.244.1 GET /index.html 15824 0.043  --  %{IP:client} %{WORD:method} %{URIPATHPARAM:request} %{NUMBER:bytes} %{NUMBER:duration}<br>
>%{NUMBER:num:int}:converts the num semantic from a string to an integer
>regular expressions:https://github.com/kkos/oniguruma/blob/master/doc/RE



#### Elasticsearch
ELK核心

###### 安装
install jdk1.8<br>
curl -L -O https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.1.2.tar.gz<br>
tar -xvf elasticsearch-6.1.2.tar.gz<br>
cd elasticsearch-6.1.2/bin<br>
./elasticsearch

###### 基本概念
* Cluster: a collection of one or more nodes (servers) that together holds your entire data and provides federated indexing and search capabilities across all nodes
* Node: single server that is part of your cluster, stores your data, and participates in the cluster’s indexing and search capabilities
* Index: a collection of documents that have somewhat similar characteristics(这里和关系型数据库里的索引不同，类似于一个库)
* Type: Indices created in Elasticsearch 6.0.0 or later may only contain a single mapping type. Indices created in 5.x with multiple mapping types will continue to function as before in Elasticsearch 6.x. Mapping types will be completely removed in Elasticsearch 7.0.0.
* Document: a basic unit of information that can be indexed
* Shards&Replica: subdivide your index into multiple pieces called shards for large amount of data on the disk of a single node.Each shard is in itself a fully-functional and independent "index" that can be hosted on any node in the cluster.make one or more copies of your index’s shards into what are called replica shards, or replicas for short(high availability,failover mechanism).
	* It allows you to horizontally split/scale your content volume 
	* It allows you to distribute and parallelize operations across shards (potentially on multiple nodes) thus increasing performance/throughput
	* a replica shard is never allocated on the same node as the original/primary shard that it was copied from. 
	* It allows you to scale out your search volume/throughput since searches can be executed on all replicas in parallel.
	* To summarize, each index can be split into multiple shards. An index can also be replicated zero (meaning no replicas) or more times. Once replicated, each index will have primary shards (the original shards that were replicated from) and replica shards (the copies of the primary shards). 

###### 基本用法
* 和elastic交互：RESTful API(curl -X<VERB> '<PROTOCOL>://<HOST>:<PORT>/<PATH>?<QUERY_STRING>' -d '<BODY>'),例如计算集群中文档的数量
```
curl -XGET 'http://localhost:9200/_count?pretty' -d '
{
    "query": {
        "match_all": {}
    }
}
'
返回
{
    "count" : 0,
    "_shards" : {
        "total" : 5,
        "successful" : 5,
        "failed" : 0
    }
}
```
* 索引文档(相当于SQL INSERT)
```
PUT /megacorp/employee/1 (curl -XPUT 的简体)
{
    "first_name" : "John",
    "last_name" :  "Smith",
    "age" :        25,
    "about" :      "I love to go rock climbing",
    "interests": [ "sports", "music" ]
}
megacorp:index
employee:type
1:ID
```
* 检索文档
```
GET /megacorp/employee/1(curl -XGET 的简体，得到ID=1的记录)
返回
{
  "_index" :   "megacorp",
  "_type" :    "employee",
  "_id" :      "1",
  "_version" : 1,
  "found" :    true,
  "_source" :  {
      "first_name" :  "John",
      "last_name" :   "Smith",
      "age" :         25,
      "about" :       "I love to go rock climbing",
      "interests":  [ "sports", "music" ]
  }
}
------------------------------------------------------
GET /megacorp/employee/_search(得到用户所需的全部信息。)
返回
{
   "took":      6,
   "timed_out": false,
   "_shards": { ... },
   "hits": {
      "total":      3,
      "max_score":  1,
      "hits": [
        {
            "_index":         "megacorp",
            "_type":          "employee",
            "_id":            "3",
            "_score":         1,
            "_source": {
               "first_name":  "Douglas",
               "last_name":   "Fir",
               "age":         35,
               "about":       "I like to build cabinets",
               "interests": [ "forestry" ]
            }
         },      
         {
            "_index":         "megacorp",
            "_type":          "employee",
            "_id":            "1",
            "_score":         1,
            "_source": {
               "first_name":  "John",
               "last_name":   "Smith",
               "age":         25,
               "about":       "I love to go rock climbing",
               "interests": [ "sports", "music" ]
            }
         },
         {
            "_index":         "megacorp",
            "_type":          "employee",
            "_id":            "2",
            "_score":         1,
            "_source": {
               "first_name":  "Jane",
               "last_name":   "Smith",
               "age":         32,
               "about":       "I like to collect rock albums",
               "interests": [ "music" ]
            }
         }
      ]
   }
}
------------------------------------------------------
GET /megacorp/employee/_search?q=last_name:Smith(返回所有的Smith)
返回
{
   ...
   "hits": {
      "total":      2,
      "max_score":  0.30685282,
      "hits": [
         {
            ...
            "_source": {
               "first_name":  "John",
               "last_name":   "Smith",
               "age":         25,
               "about":       "I love to go rock climbing",
               "interests": [ "sports", "music" ]
            }
         },
         {
            ...
            "_source": {
               "first_name":  "Jane",
               "last_name":   "Smith",
               "age":         32,
               "about":       "I like to collect rock albums",
               "interests": [ "music" ]
            }
         }
      ]
   }
}
------------------------------------------------------
使用查询表达式:
GET /megacorp/employee/_search
{
    "query" : {
        "match" : {
            "last_name" : "Smith"
        }
    }
}
返回同上
------------------------------------------------------
使用过滤器:
GET /megacorp/employee/_search
{
    "query" : {
        "bool": {
            "must": {
                "match" : {
                    "last_name" : "smith" 
                }
            },
            "filter": {
                "range" : {
                    "age" : { "gt" : 30 } 
                }
            }
        }
    }
}
返回
{
   ...
   "hits": {
      "total":      1,
      "max_score":  0.30685282,相关性得分
      "hits": [
         {
            ...
            "_source": {
               "first_name":  "Jane",
               "last_name":   "Smith",
               "age":         32,
               "about":       "I like to collect rock albums",
               "interests": [ "music" ]
            }
         }
      ]
   }
}
------------------------------------------------------
全文检索
GET /megacorp/employee/_search
{
    "query" : {
        "match" : {
            "about" : "rock climbing"
        }
    }
}
返回
{
   ...
   "hits": {
      "total":      2,
      "max_score":  0.16273327,
      "hits": [
         {
            ...
            "_score":         0.16273327, 
            "_source": {
               "first_name":  "John",
               "last_name":   "Smith",
               "age":         25,
               "about":       "I love to go rock climbing",
               "interests": [ "sports", "music" ]
            }
         },
         {
            ...
            "_score":         0.016878016, 
            "_source": {
               "first_name":  "Jane",
               "last_name":   "Smith",
               "age":         32,
               "about":       "I like to collect rock albums",
               "interests": [ "music" ]
            }
         }
      ]
   }
}
------------------------------------------------------
短语搜索
GET /megacorp/employee/_search
{
    "query" : {
        "match_phrase" : {
            "about" : "rock climbing"
        }
    }
}
返回
{
   ...
   "hits": {
      "total":      1,
      "max_score":  0.23013961,
      "hits": [
         {
            ...
            "_score":         0.23013961,
            "_source": {
               "first_name":  "John",
               "last_name":   "Smith",
               "age":         25,
               "about":       "I love to go rock climbing",
               "interests": [ "sports", "music" ]
            }
         }
      ]
   }
}
------------------------------------------------------
高亮搜索
GET /megacorp/employee/_search
{
    "query" : {
        "match_phrase" : {
            "about" : "rock climbing"
        }
    },
    "highlight": {
        "fields" : {
            "about" : {}
        }
    }
}
返回
{
   ...
   "hits": {
      "total":      1,
      "max_score":  0.23013961,
      "hits": [
         {
            ...
            "_score":         0.23013961,
            "_source": {
               "first_name":  "John",
               "last_name":   "Smith",
               "age":         25,
               "about":       "I love to go rock climbing",
               "interests": [ "sports", "music" ]
            },
            "highlight": {
               "about": [
                  "I love to go <em>rock</em> <em>climbing</em>" 
               ]
            }
         }
      ]
   }
}
------------------------------------------------------
聚合
GET /megacorp/employee/_search
{
  "aggs": {
    "all_interests": {
      "terms": { "field": "interests" }
    }
  }
}
返回
{
   ...
   "hits": { ... },
   "aggregations": {
      "all_interests": {
         "buckets": [
            {
               "key":       "music",
               "doc_count": 2
            },
            {
               "key":       "forestry",
               "doc_count": 1
            },
            {
               "key":       "sports",
               "doc_count": 1
            }
         ]
      }
   }
}

```

###### 一些命令
*  List All Indices:curl 'localhost:9200/_cat/indices?v' --- curl -XGET -u elastic 'localhost:9200/_cat/indices?v&pretty'<br>
* 集群健康状态： curl -XGET 'http://localhost:9200/_cluster/health?pretty' -u elastic
* 一个index库健康状态： curl -XGET 'http://localhost:9200/_cluster/health/zh?pretty'

###### 遇到的问题
* FORBIDDEN/12/index read-only / allow delete (api)  flood stage disk watermark: 
>elasticsearch log: [2018-02-07T17:35:39,088][WARN ][o.e.c.r.a.DiskThresholdMonitor] [MgFs-Nt] flood stage disk watermark [95%] exceeded on [MgFs-NtaRUiriAD4fK1mMg][MgFs-Nt][/home/vobile/bin/elasticsearch-6.1.2/data/nodes/0] free: 6.8gb[3.2%], all indices on this node will marked read-only<br>
>kibana log: log   [09:54:52.877] [error][status][plugin:xpack_main@6.1.2] Status changed from yellow to red - [cluster_block_exception] blocked by: [FORBIDDEN/12/index read-only / allow delete (api)];<br>
>kibana status red<br>

curl -XPUT -H "Content-Type: application/json" -u elastic 'localhost:9200/_settings' -d '{"index.blocks.read_only_allow_delete": null}' 后，FORBIDDEN/12消失
>log   [14:21:34.547] [info][status][plugin:elasticsearch@6.1.2] Status changed from red to green - Ready

* 当我把磁盘一个大文件删除后,此时磁盘剩余空间12%，然后日志变成:
>start elasticsearch, ES log:[2018-02-08T16:46:28,453][INFO ][o.e.c.r.a.DiskThresholdMonitor] [MgFs-Nt] low disk watermark [85%] exceeded on [MgFs-NtaRUiriAD4fK1mMg][MgFs-Nt][/home/vobile/bin/elasticsearch-6.1.2/data/nodes/0] free: 25.5gb[12%], replicas will not be assigned to this node<br>
>start kibana,ES log:[2018-02-08T15:49:32,422][WARN ][r.suppressed             ] path: /.kibana/doc/config%3A6.1.2, params: {index=.kibana, id=config:6.1.2, type=doc}
org.elasticsearch.action.NoShardAvailableActionException: No shard available for [get [.kibana][doc][config:6.1.2]: routing [null]]<br>
[2018-02-08T15:52:07,550][WARN ][r.suppressed             ] path: /.kibana/_search, params: {size=0, index=.kibana, from=0}
org.elasticsearch.action.search.SearchPhaseExecutionException: all shards failed

* 然后根据https://stackoverflow.com/questions/33369955/low-disk-watermark-exceeded-on，在 elasticsearch.yml中加入下面配置信息后警告消失。
```
cluster.routing.allocation.disk.threshold_enabled: true
cluster.routing.allocation.disk.watermark.low: 4gb
cluster.routing.allocation.disk.watermark.high: 2gb
cluster.routing.allocation.disk.watermark.flood_stage: 1gb
```

* curl -XGET 'http://localhost:9200/_cluster/health?pretty' -u elastic, 发现status red
```
{，
  "cluster_name" : "elasticsearch",
  "status" : "red",
  "timed_out" : false,
  "number_of_nodes" : 1,
  "number_of_data_nodes" : 1,
  "active_primary_shards" : 12,
  "active_shards" : 12,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 23,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0,
  "task_max_waiting_in_queue_millis" : 0,
  "active_shards_percent_as_number" : 34.285714285714285
}
```
curl -XGET -u elastic 'localhost:9200/_cat/indices?v&pretty'，发现.kibana和.logstash-2018.02.02 status red
```
health status index                           uuid                   pri rep docs.count docs.deleted store.size pri.store.size
yellow open   .monitoring-es-6-2018.02.07     0N8SVrOwTt2NF2w0sgpYgg   1   1      45127           29     16.1mb         16.1mb
yellow open   .monitoring-alerts-6            gJXWcTbbSB2clp2gvJOsvg   1   1          1            0     18.8kb         18.8kb
yellow open   .watches                        613nDLaEQIy_inAtCim6Iw   1   1          5            0    890.3kb        890.3kb
yellow open   .watcher-history-7-2018.02.08   tMXP2_3ARDifg5y6Yc7Nrw   1   1       1345            0      2.6mb          2.6mb
yellow open   .triggered_watches              mrefM8jkRqiMLDMuvy83nA   1   1          0            0    122.7kb        122.7kb
red    open   .kibana                         aKh0ZX6ISa2D1YpgQWnmWg   1   1                                                  
yellow open   .watcher-history-7-2018.02.07   3MzdkjvcS2yR0aguXZLcKA   1   1       3907            0      3.5mb          3.5mb
yellow open   .monitoring-es-6-2018.02.06     fysALZxsS2e8xu_EycPwHA   1   1       1277           66    797.1kb        797.1kb
red    open   logstash-2018.02.02             RT_XzqDhTLKndk-RlgPspg   5   1                                                  
green  open   .security-6                     UwJZiEZPQiGA935sq0FL9A   1   0          3            0      9.8kb          9.8kb
yellow open   .monitoring-es-6-2018.02.08     mYHEcCxvQ_GfVV9WCmKvTQ   1   1      17272            0     16.9mb         16.9mb
yellow open   .monitoring-kibana-6-2018.02.07 e6YF_Hu9QGe7L39p6eF3fg   1   1          2            0     28.1kb         28.1kb
yellow open   .watcher-history-7-2018.02.06   5prFs1VbRPKchn4TRxAIlQ   1   1        158            0    326.8kb        326.8kb

```
>根据https://www.zhihu.com/question/34415340/answer/58590135，有primary shard未分配，curl -XGET 'http://localhost:9200/_cat/shards' -u elastic，发现
```
.kibana                         0 p UNASSIGNED                         
.kibana                         0 r UNASSIGNED                         

logstash-2018.02.02             3 p UNASSIGNED                         
logstash-2018.02.02             3 r UNASSIGNED                         
logstash-2018.02.02             1 p UNASSIGNED
```
>curl -XDELETE 'http://localhost:9200/logstash-2018.02.02' -u elastic 删掉logstash-2018.02.02这个索引，
>curl -XDELETE 'http://localhost:9200/.kibana' -u elastic 删掉.kibana这个索引，状态终于从red变成yellow。打开http://localhost:5601，终于正常了，过程真是血泪。.kibana这个索引是什么时候加进去的？
 
* elasticsearch启动时警告：<br>
[2018-02-08T18:07:44,034][WARN ][o.e.b.BootstrapChecks    ] [MgFs-Nt] max file descriptors [4096] for elasticsearch process is too low, increase to at least [65536]<br>
[2018-02-08T18:07:44,035][WARN ][o.e.b.BootstrapChecks    ] [MgFs-Nt] max virtual memory areas vm.max_map_count [65530] is too low, increase to at least [262144]<br>
>根据https://www.elastic.co/guide/en/elasticsearch/reference/current/file-descriptors.html,先输入以下命令警告消除。
```
sudo su  
ulimit -n 65536
sysctl -w vm.max_map_count=262144 
su vobile
```

>根据https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html，


#### Kibana
前端展示

###### install
Kibana should be configured to run against an Elasticsearch node of the same version. This is the officially supported configuration.<br>
wget https://artifacts.elastic.co/downloads/kibana/kibana-6.1.2-linux-x86_64.tar.gz<br>
sha1sum kibana-6.1.2-linux-x86_64.tar.gz<br>
tar -xzf kibana-6.1.2-linux-x86_64.tar.gz<br>
cd kibana-6.1.2-linux-x86_64/<br>
./bin/kibana<br>
打开localhost:5601<br>

###### 一些命令


localhost:5601/status

###### 使用
1. load data
2. define index patterns
3. 

#### X-Pack     
X-Pack提供了ELK的增强工具，报警是其中之一功能，按照官网的说法，可以定义一些watcher scheduler定时在Elasticsearch中检索，根据结果和触发条件选择Action发出提醒<br>
主要功能：<br>
* Security
* Monitoring
* Alerting and Notification
* Reporting
* Graph
* Machine Learning

部分功能要升级到高级的licence,试用一个月，需要付费：https://www.elastic.co/subscriptions<br>
启动ES日志:[info][license][xpack] Imported license information from Elasticsearch for the [monitoring] cluster: mode: trial | status: active | expiry date: 2018-03-08T20:40:42+08:00

###### 安装
https://www.elastic.co/downloads/x-pack<br>

 1.Install X-Pack into Elasticsearch<br>
 https://artifacts.elastic.co/downloads/packs/x-pack/x-pack-6.1.2.zip<br>
 bin/elasticsearch-plugin install file:///path/to/file/x-pack-6.1.2.zip(optional)<br>
 bin/elasticsearch-plugin install x-pack<br>
 2.Config TLS/SSL<br>
 * 如果没有配置ssl，启动kibana有警告：![]( https://github.com/zjhgx/archecture_zjhgx/blob/master/ELK/no_ssl.png )

 3.Start Elasticsearch:bin/elasticsearch<br>
 4.Generate default passwords:bin/x-pack/setup-passwords auto  bin/x-pack/setup-passwords interactive<br>
   Built-in Users:<br>
 * elastic:A built-in superuser see:https://www.elastic.co/guide/en/x-pack/6.1/built-in-roles.html 7114217 
 * kibana:The user Kibana uses to connect and communicate with Elasticsearch. kibana
 * logstash_system: The user Logstash uses when storing monitoring information in Elasticsearch. logstash<br>
 
 5.Install X-Pack into Kibana:bin/kibana-plugin install x-pack or bin/kibana-plugin install file:///path/to/file/x-pack-6.1.2.zip<br>
 6.Add credentials to the kibana.yml file:<br>
 * elasticsearch.username: "kibana"
 * elasticsearch.password:  "<pwd>"<br>
 
 7.Start Kibana:bin/kibana<br>
 8.
 * Navigate to Kibana at http://localhost:5601/<br>
 * Log in as the built-in elastic user with the auto-generated password from step 3<br>
 
 
###### security
* AUTHENTICATION:password
* AUTHORIZATION:Manage Users and Roles
* ENCRYPTION:SSL/TLS encryption,IP filtering.Prevent Snooping, Tampering, and Sniffing.
* LAYERED SECURITY:Field- and document-level security
* AUDIT LOGGING:easily maintain a complete record of all system and user activity

###### Alerting on Cluster and Index Events
* Schedule: A schedule for running a query and checking the condition. 
* Query: The query to run as input to the condition. Watches support the full Elasticsearch query language, including aggregations. 
* Condition: A condition that determines whether or not to execute the actions. 
* Actions: One or more actions, such as sending email, pushing data to 3rd party systems through a webhook, or indexing the results of the query. 

###### watcher

###### api
* Put Watch API(registers a new watch in Watcher)
```
Request: 
PUT _xpack/watcher/watch/<watch_id>

PUT _xpack/watcher/watch/log_error_watch
{
  "trigger" : { "schedule" : { "interval" : "20s" }},
  "input" : {
    "search" : {
      "request" : {
        "indices" : [ "logstash-2018.03.01" ],
        "body" : {
          "query" : {
            "match" : { "level": "ERROR" }
          }
        }
      }
    }
  },
  "condition" : {
    "compare" : { "ctx.payload.hits.total" : { "gt" : 0 }}
  },
  "actions" : {
    "send_email" : { 
      "email" : { 
      	"from": "hugaoxiang@ichuangshun.com",
        "to" : "zjhgx163@163.com",
        "subject" : "Watcher Notification", 
        "body" : "{{message}{ctx.payload.hits.total}} error logs found" 
      }
    }
  }
}
```

* Get Watch API
```
Request: 
GET _xpack/watcher/watch/<watch_id>

Response:
{
  "found": true,
  "_id": "my_watch",
  "status": { 
    "version": 1,
    "state": {
      "active": true,
      "timestamp": "2015-05-26T18:21:08.630Z"
    },
    "actions": {
      "test_index": {
        "ack": {
          "timestamp": "2015-05-26T18:21:08.630Z",
          "state": "awaits_successful_execution"
        }
      }
    }
  },
  "watch": {
    "input": {
      "simple": {
        "payload": {
          "send": "yes"
        }
      }
    },
    "condition": {
      "always": {}
    },
    "trigger": {
      "schedule": {
        "hourly": {
          "minute": [0, 5]
        }
      }
    },
    "actions": {
      "test_index": {
        "index": {
          "index": "test",
          "doc_type": "test2"
        }
      }
    }
  }
}

```
* Delete Watch API
```
Request:
DELETE _xpack/watcher/watch/<watch_id>

Response:
{
   "found": true,
   "_id": "my_watch",
   "_version": 2
}
```
* Execute Watch API
```
Request:
POST _xpack/watcher/watch/<watch_id>/_execute
{
  "trigger_data" : { 
     "triggered_time" : "now",
     "scheduled_time" : "now"
  },
  "alternative_input" : { 
    "foo" : "bar"
  },
  "ignore_condition" : true, 
  "action_modes" : {
    "my-action" : "force_simulate" 
  },
  "record_execution" : true 
}

Response:

```

###### Email Actions
Sending Email from Amazon SES<br>
1.verify email address or email domain:<br> 
2.create your SMTP credentials<br>
目前只能发送email到已经认证过的地址<br>
https://console.aws.amazon.com/ses/home?region=us-east-1#verified-senders-email<br>
* 配置 elasticsearch.yml
```
xpack.notification.email.account:
    ses_account:
        smtp:
            auth: true
            starttls.enable: true
            starttls.required: true
            host: email-smtp.us-east-1.amazonaws.com
            port: 587
            user: AKIAIN3TN53NLWEUUUGA
            password: AulAaEep1p63NIyl/lmg4bYSguZ3Y7tpayufPpkcglly

```
user和password是生成的SMTP credentials

##### Kafka
如果数据量大，可以加入Kafka

## TODO
* 多个节点，主分片，备分片
* logstash传过来的的每一天一个index？
* 多个数据源区分
* 报警策略：新产生的错误才报警？历史的错误忽略
* 异常的日志需要合并保存到ES，目前以行为单位查看起来不是很完整
