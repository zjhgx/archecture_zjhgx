

admlogs='/var/log/tourongjia_crm.log'
tompath='/usr/local/javaapp/tomcat8080'

echo -e "\n###################   `date +%F_%T`   ###############\n" >>$admlogs
cd /home/JAVACRM

cat /dev/null >/tmp/gitlog.txt
echo -e "\n### Script exe at `date +%F/%T` by `who am i|awk '{print $1" "$2" "$5}'` ###\n" >>$admlogs

git remote update origin --prune

read -p "【javacrm测试更新--JAVACRM】请输入需要切换的分支:" BRANCH
if [ "$BRANCH" == "" ] ;then
		git checkout test >/tmp/gitlog.txt
        git pull origin test >/tmp/gitlog.txt
  elif  echo $BRANCH ;then
		git checkout $BRANCH
        git pull origin $BRANCH >/tmp/gitlog.txt
  else
        echo "输入内容不符合要求,程序退出."
        exit 1
fi

if [ $? -eq 0 ]
 then
   cat /tmp/gitlog.txt | tee -a $admlogs
   echo  -e "\e[32;1m OK\e[0m GIT update" |tee -a $admlogs
 else
   cat /tmp/gitlog.txt | tee -a $admlogs
   echo  -e "\e[31;5m Fail\e[0m GIT update" |tee -a $admlogs
   exit 1
fi


cat /dev/null >/tmp/gitlog.txt
source /etc/profile

/bin/zxlh/config_upgrade.sh

if [ $? -ne 0 ]; then
	exit 1	
fi
\cp -f /home/configbak/tourongjia_crm/test_config.properties             /home/JAVACRM/src/profiles	

mvn clean package -P test -DskipTests=true >>/tmp/gitlog.txt 2>>/tmp/gitlog.txt
cat /tmp/gitlog.txt |tee -a $admlogs

egrep -q 'BUILD SUCCESS' /tmp/gitlog.txt

blank_count=$(awk '/^[ \t]+|[ \t]+$|\r/' "/home/JAVACRM/target/trj-crm/WEB-INF/classes/application.properties" | wc -l )
echo $blank_count
if [ $blank_count -gt 0 ]; then
                sed -i -e 's/^[ \t]*//g' "/home/JAVACRM/target/trj-crm/WEB-INF/classes/application.properties"
                sed -i -e 's/[ \t]*$//g' "/home/JAVACRM/target/trj-crm/WEB-INF/classes/application.properties"
                sed -i -e 's/\r//g' "/home/JAVACRM/target/trj-crm/WEB-INF/classes/application.properties"
                echo "[Warning]: /home/JAVACRM/target/trj-crm/WEB-INF/classes/application.properties上配置项发现非法字符，已删除"
fi


if [ $? -eq 0 ]
 then
   echo  -e "\e[32;1m OK\e[0m mvn build" |tee -a $admlogs
 else
   echo  -e "\e[31;5m Fail\e[0m mvn build" |tee -a $admlogs
   exit 1
fi

#$tompath/bin/shutdown.sh >/dev/null
ps -ef | grep /tomcat8080/ | awk '{print $2}' | xargs kill -9

echo "sleeping 5 Seconds for stop tomcat8080 ........"
sleep 5

AA=`netstat -tnpl | grep 8080 |awk '{print $7}'| awk -F/ '{print $1}'`
if [ "$AA" = "" ]
  then
    echo  -e "\e[32;1m OK\e[0m stop tomcat" |tee -a $admlogs
  else
  kill -9 "$AA"
  sleep 5
fi

mypid=$(netstat -tnpl | grep 60880 |awk '{print $7}'|awk -F"/" '{print $1}')
netstat -tnpl | grep -q 60880 && kill -9 $mypid

rm -rf $tompath/work/Catalina/localhost/* && echo  -e "\e[32;1m OK\e[0m del work tmp dir" |tee -a $admlogs || echo  -e "\e[31;5m FAIL\e[0m del tmp dir" |tee -a $admlogs
rm -rf $tompath/webapps/ROOT/*
if [ $? -eq 0 ]
 then
   echo  -e "\e[32;1m OK\e[0m delete tomcat8080's dir" |tee -a $admlogs
 else
   echo  -e "\e[31;5m Fail\e[0m delete tomcat8080's dir" |tee -a $admlogs
fi

#\rm -f target/trj-crm/WEB-INF/classes/com/upg/loan/jkWebService/core/impl/UserProfessionDaoImpl.class
\cp -ra target/trj-crm/* $tompath/webapps/ROOT/

if [ $? -eq 0 ]
 then
   echo  -e "\e[32;1m OK\e[0m copy tomcat8080's dir" |tee -a $admlogs
 else
   echo  -e "\e[31;5m Fail\e[0m copy  tomcat8080's dir" |tee -a $admlogs
fi

\cp -f /home/configbak/tourongjia_crm/web.xml              $tompath/webapps/ROOT/WEB-INF/

\cp -f /home/configbak/tourongjia_crm/attachment-config.xml $tompath/webapps/ROOT/WEB-INF/classes/

\cp -f /home/configbak/tourongjia_crm/dubbo/*              $tompath/webapps/ROOT/WEB-INF/classes/dubbo/


$tompath/bin/startup.sh >/dev/null

echo "sleeping 5 seconds for start tomcat8080 ........"
sleep 5

if [ `netstat -tnpl | grep 8080 | wc -l` -gt 0 ]
  then
    echo  -e "\e[32;1m OK\e[0m start localhost tomcat8080" |tee -a $admlogs
  else
    echo  -e "\e[31;5m Fail\e[0m start localhost tomcat8080" |tee -a $admlogs
fi
