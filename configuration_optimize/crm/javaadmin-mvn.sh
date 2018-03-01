#!/bin/bash
#

cd /home/LXJAVAADMIN

outlog='/var/log/lx-admin.log'
cat /dev/null >/tmp/gitlog.txt

echo -e "\n### Script exe at `date +%F/%T` by `who am i|awk '{print $1" "$2" "$5}'` ###\n" >> $outlog

read -p "【测试更新--LX-ADMIN】请输入需要切换的分支:" BRANCH

git pull origin

if [ "$BRANCH" == "" ] ;then
        git checkout master >/tmp/gitlog.txt
        git pull origin master >/tmp/gitlog.txt
  elif  echo $BRANCH ;then
        git checkout $BRANCH
        git pull origin $BRANCH >/tmp/gitlog.txt
  else
        echo "输入内容不符合要求,程序退出."
        exit 1
fi

if [ $? -eq 0 ]
 then
   cat /tmp/gitlog.txt | tee -a $outlog
   echo  -e "\e[32;1m OK\e[0m GIT update" |tee -a $outlog
 else   
   cat /tmp/gitlog.txt | tee -a $outlog
   echo  -e "\e[31;5m Fail\e[0m GIT update" |tee -a $outlog
   exit 1
fi
\cp -rf /home/configbak_admin/attachment-config.xml /home/LXJAVAADMIN/src/main/resources/attachment/
\cp -f /home/configbak_admin/production_config.properties /home/LXJAVAADMIN/src/main/resources/profiles
#\cp -rf /home/configbak/cms-dao/jdbc.properties cms-dao/src/main/resources/config/pro/
#
#\cp -rf /home/configbak/cms-clifilter/jdbc.properties cms-clifilter/src/main/resources/config/spring/pro/
#\cp -rf /home/configbak/cms-common/redis.properties cms-common/src/main/resources/config/pro/
#\cp -rf /home/configbak/cms-common/system.properties cms-common/src/main/resources/config/pro/

mvn clean install -P production -Dmaven.test.skip=true >>/tmp/gitlog.txt

cat /tmp/gitlog.txt |tee -a $admlogs

egrep -q 'BUILD SUCCESS' /tmp/gitlog.txt

blank_count=$(awk '/^[ \t]+|[ \t]+$|\r/' "/home/LXJAVAADMIN/target/lexiao-admin/WEB-INF/classes/application.properties" | wc -l )
if [ $blank_count -gt 0 ]; then
                sed -i -e 's/^[ \t]*//g' "/home/LXJAVAADMIN/target/lexiao-admin/WEB-INF/classes/application.properties"
                sed -i -e 's/[ \t]*$//g' "/home/LXJAVAADMIN/target/lexiao-admin/WEB-INF/classes/application.properties"
                sed -i -e 's/\r//g' "/home/LXJAVAADMIN/target/lexiao-admin/WEB-INF/classes/application.properties"
                echo "[Warning]: /home/LXJAVAADMIN/target/lexiao-admin/WEB-INF/classes/application.properties上配置项发现非法字符，已删除"
fi



if [ $? -eq 0 ]
 then
   echo  -e "\e[32;1m OK\e[0m mvn build" |tee -a $admlogs
 else
   echo  -e "\e[31;5m Fail\e[0m mvn build" |tee -a $admlogs
   exit 1
fi

/usr/local/tomcat8080/bin/shutdown.sh >/dev/null

echo "sleeping 5 Seconds for stop tomcat8080 ........"
sleep 5

AA=`netstat -tnpl | grep -w 8080 |awk '{print $7}'| awk -F/ '{print $1}'`
if [ "$AA" = "" ]
  then
    echo  -e "\e[32;1m OK\e[0m stop tomcat" |tee -a $admlogs
  else
  kill -9 "$AA"
  sleep 5
fi

mypid=$(netstat -tnpl | grep -w 8080 |awk '{print $7}'|awk -F"/" '{print $1}')
netstat -tnpl | grep -q -w 8080 && kill -9 $mypid

rm -rf /usr/local/tomcat8080/work/Catalina/localhost/* && echo  -e "\e[32;1m OK\e[0m del work tmp dir" |tee -a $admlogs || echo  -e "\e[31;5m FAIL\e[0m del tmp dir" |tee -a $admlogs

rm -rf /usr/local/tomcat8080/webapps/ROOT
if [ $? -eq 0 ]
 then
   echo  -e "\e[32;1m OK\e[0m delete tomcat8080's dir" |tee -a $admlogs
 else
   echo  -e "\e[31;5m Fail\e[0m delete tomcat8080's dir" |tee -a $admlogs
fi

\cp -rf /home/LXJAVAADMIN/target/lexiao-admin /usr/local/tomcat8080/webapps/

if [ $? -eq 0 ]
 then
   echo  -e "\e[32;1m OK\e[0m copy tomcat8080's dir" |tee -a $admlogs
 else
   echo  -e "\e[31;5m Fail\e[0m copy  tomcat8080's dir" |tee -a $admlogs
fi

/usr/local/tomcat8080/bin/startup.sh >/dev/null

echo "sleeping 5 seconds for start tomcat8080 ........"
sleep 5

if [ `netstat -tnpl | grep -w 8080 | wc -l` -gt 0 ]
  then
    echo  -e "\e[32;1m OK\e[0m start localhost tomcat8080" |tee -a $admlogs
  else
    echo  -e "\e[31;5m Fail\e[0m start localhost tomcat8080" |tee -a $admlogs
fi

