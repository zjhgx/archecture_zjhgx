
1. Structure
1.1. Module Overview

目前测试/运维/生产环境的配置文件要依赖人工维护，每次配置有改动，需要人工手动更改相应环境的配置文件，缺少一个校验机制。这种做法一是容易产生问题，二是不好维护，特别是随着机器的增多会愈发困难。按照持续集成，持续交付的要求，配置文件应该尽量避免人工操作。本次会增加脚本对配置文件的合并和校验，并在流程上做一些更改，当然离最终的要求还有一段路要走。
1.2. Module Design 

    crm,admin系统精简.properties文件(去除soopay.properties,changfudai_dev.properties,changfudai_release.properties,xhhPhp.properties,env.properties)，把能合并的合并成application.properties，长富贷/贷拉不变。
    一些配置文件是第三方服务自带的，如systemconfig.properties,SignVerProp.propertiees,dubbo.properties.这种不合并。
    增加application.properties作为主要的配置文件，区分.properties文件中各环境通用和依赖的配置项，其中依赖环境的配置项以变量形式表示（注意${}里的value和key是同样的值），如mysql.host = ${mysql.host},增加profiles目录，下面有dev_config.properties, test_config.properties表示各个环境下配置变量的真实值。在用maven build工程时会用真实环境中的值生成真实配置文件。
    测试/运维/生产环境机器的/home/configbak下保留一份各环境的配置文件，里面内容是真实配置值。如测试环境是test_config.properties里面 mysql.host = 192.168.10.80。原先的配置文件如xhh.properties,soopay.properties，env.properties,changfudai_dev.properties, changfudai_release.properties删除

    代码库里增加changes.properties, 开发每次提交代码给测试后，需要把增加/修改的配置在changes.properties里标注，表示哪个配置文件更改了哪些配置，如下表示在application.properties里增/修改了两个配置项jijie.domain，jijie.customer.maxdaliyline,删除了一个配置项david.test4：

     
    [application.properties]
    jijie.domain=http://192.168.5.169:8080,http://localhost:8080
    #hessian server appname
    jijie.customer.maxdaliyline=${jijie.customer.maxdaliyline}
    --david.test4=${david.test4}

    实现config_upgrade.sh在安装程序时自动把changes.properties里的项自动添加到/home/configbak里相应的配置文件，并做格式/完整性上的校验（自动去除空格等非法字符）其中变量合并到test_config.properties, 常量合并到static.properties.  crm/admin的脚本如下

     
    #!/bin/bash
    #set -x
     
    #CONFIG_FILE_PATH=/home/configbak/tourongjia_crm
    CONFIG_FILE_PATH=/home/vobile/project/tourongjia/configbak
    CONFIG_FILE=test_config.properties
    STATIC_CONFIG_FILE=static_config.properties
    #WEB_APP_PATH=/home/JAVACRM/src
    WEB_APP_PATH=/home/vobile/git/javacrm/src
    changes_file="$WEB_APP_PATH/profiles/install/changes.properties"
    file_count=$(awk "/\[.*\]/" $changes_file | wc -l)
    if [ $file_count -eq 0 ]; then
            echo "没有配置文件需要修改"
            exit 0
    fi
     
    echo $file_count
    EXIT_FLAG="0"
    MANUAL_FLAG=0
     
    for i in $(seq $file_count) ; do
            path=$(awk -F '[][]' '/\[.*\]/{F++}{if(F==I)print $2}' I=$i $changes_file)
            echo "[$path]"
            #存储格式化后的配置项
            awk "/\[.*\]/{F++;next}/[^\s]+/{if(F==$i){gsub(/^( |\t)*|( |\t)*$/,\"\");print}}/\[.*\]/"  $changes_file | egrep -v '^#' > /tmp/$$
     
            count=$(cat /tmp/$$ | wc -l)
            if [ $count -eq 0 ]; then
                    echo "$path没有配置项需要修改"
                    continue
            fi
             
            #检查changes.properties的完整性/命名正确性
            while read propertiesline
            do
                    if  ! `grep -q "$propertiesline" "$WEB_APP_PATH/$path"`; then
                            echo "[Error]: can not find '$propertiesline' in \"$WEB_APP_PATH/$path\""
                            EXIT_FLAG="1"
                    else
                            prop_key=`echo $propertiesline | awk -F= '{gsub(/^( |\t)*|( |\t)*$/,"",$1);print $1}'`
                            prop_value=`echo $propertiesline | awk -F= '{gsub(/^( |\t)*|( |\t)*$/,"",$1);print $2}'`
                            if [ $(echo $prop_value | awk -F '[$|{|}]' '{print $3}') ]; then
                                    prop_variable=$(echo $prop_value | awk -F '[$|{|}]' '{print $3}')
                                    if [ "$prop_key" != "$prop_variable" ];then
                                            echo "[Error]: $propertiesline命名错误，请检查"
                                            EXIT_FLAG="1"
                                    fi
                            fi
                    fi     
            done < /tmp/$$
     
            if [ $EXIT_FLAG = "1" ]; then
                    echo "[Error]: changes.properties check fail,script quit"
                    exit 1
            fi
            #合并changes.properties
            for key in $(awk -F= '{print $1}' /tmp/$$) ; do
                    line=$(awk '/^'$key'[ \t]*=/ {print;exit}' /tmp/$$)
                    echo $line
                    change_value=`echo $line | awk -F= '{gsub(/^( |\t)*|( |\t)*$/,"",$2);print $2}'`
                    change_variable_part=`echo $change_value | awk -F '[$|{|}]' '{print $3}'`
                    #如果是变量则需要合并到test_config.properties
                    if [ "$change_variable_part" ]; then
                            exist_config=$(grep  "^$key[ \t]*=" "$CONFIG_FILE_PATH/$CONFIG_FILE" | head -1)
                            # replace old config
                            if [ "$exist_config" ]; then
                                    exist_value=`echo $exist_config | awk -F= '{gsub(/^( |\t)*|( |\t)*$/,"",$2);print $2}'`
                                    if [ "$exist_value" != "$change_value" ]; then
                                            exist_variable_part=`echo $exist_value | awk -F '[$|{|}]' '{print $3}'`
                                            #change.properties是变量，test_config是变量，覆盖原先配置
                                            if [ "$exist_variable_part" ]; then
                                                    sed -i -e "/^$key[ \t]*=/c $line" "$CONFIG_FILE_PATH/$CONFIG_FILE"
                                                    echo "[Info]:  $line已合并到$CONFIG_FILE_PATH/$CONFIG_FILE上,请把$change_value修改成实际值后再次运行脚本"
                                                    MANUAL_FLAG=1;
                                            else
                                            #如果change.properties上是变量,test_config上不是，则说明环境上的配置已经被修改过
                                                    echo "[Warning]: 配置$key在$CONFIG_FILE已被人工更新，配置为$exist_config，如需修改请更新$CONFIG_FILE后再执行一遍脚本"                
                                            fi
                                    else
                                            echo "[Warning]: $line在$CONFIG_FILE_PATH/$CONFIG_FILE上已存在，请把$change_value修改成实际值"
                                            MANUAL_FLAG=1;
     
                                    fi
                            else
                                    echo $line >> "$CONFIG_FILE_PATH/$CONFIG_FILE"
                                    echo "[Info]: $line已合并到$CONFIG_FILE_PATH/$CONFIG_FILE上,请把$change_value修改成实际值"
                                    MANUAL_FLAG=1;
                            fi
                    else
                    #如果是常量则合并到static_config.properties
                            exist_config=$(grep  "^$key[ \t]*=" "$CONFIG_FILE_PATH/$STATIC_CONFIG_FILE" | head -1)
                            if [ "$exist_config" ]; then
                                    exist_value=`echo $exist_config | awk -F= '{gsub(/^( |\t)*|( |\t)*$/,"",$2);print $2}'`
                                    if [ "$exist_value" != "$change_value" ]; then
                                            sed -i -e "/^$key[ \t]*=/c $line" "$CONFIG_FILE_PATH/$STATIC_CONFIG_FILE"
                                            echo "[Info]: $line已合并到$CONFIG_FILE_PATH/$STATIC_CONFIG_FILE"
                                    else
                                            echo "[Warning]: $line在$CONFIG_FILE_PATH/$STATIC_CONFIG_FILE已存在，无需合并"
                                    fi
                            else
                                    echo $line >> "$CONFIG_FILE_PATH/$STATIC_CONFIG_FILE"
                                    echo "[Info]: $line已合并到$CONFIG_FILE_PATH/$STATIC_CONFIG_FILE"
                            fi
     
                    fi
            done
     
            #去除配置项首尾空白符
            blank_count=$(awk '/^[ \t]+|[ \t]+$/' "$CONFIG_FILE_PATH/$CONFIG_FILE" | wc -l )
            if [ $blank_count -gt 0 ]; then
                    sed -i -e 's/^[ \t]*//g' "$CONFIG_FILE_PATH/$CONFIG_FILE"
                    sed -i -e 's/[ \t]*$//g' "$CONFIG_FILE_PATH/$CONFIG_FILE"
                    echo "[Warning]: $CONFIG_FILE上配置项发现非法字符，已删除"
            fi
     
            if [ $MANUAL_FLAG -eq 1 ]; then
                    echo "[Info]: 请修改$CONFIG_FILE_PATH/$STATIC_CONFIG_FILE后重新运行脚本"
                    exit 3
            fi
     
             #检查合并后配置文件的完整性
            for file in $(ls $WEB_APP_PATH | grep '.properties$') ; do
                    for config in $(awk '/^[^#][^ \t]+/' "$WEB_APP_PATH/$file")  ; do
                            key=$(echo $config | awk -F= '{gsub(/^( |\t)*|( |\t)*$/,"",$1);print $1}')
                            t=`grep "^$key[ \t]*=" "$CONFIG_FILE_PATH/$CONFIG_FILE"`
                            if [ ! "$t" ]; then
                                    value=$(echo $config | awk -F= '{gsub(/^( |\t)*|( |\t)*$/,"",$2);print $2}')
                                    variable_part=`echo $value | awk -F '[$|{|}]' '{print $3}'`
                                    if [ "$variable_part" ]; then
                                            echo  "[Error]: $CONFIG_FILE_PATH/$CONFIG_FILE不完整,$key项缺失,请检查"
                                            exit 1
                                    fi
                            fi
                    done
                     
            done
     
    done
     
    echo '[Info]: changes.properties合并完成'
    exit 0
    修改pom.xml提供profile支持,在部署时配置文件中的变量和各个环境中的真实配置信息生成实际的配置项，并做格式/完整性/功能性校验，校验不通过提示出错。
    修改原来的部署脚本增加对上述脚本的支持。
    修改完成后开发在提交代码时需要增加对changes.properties,dev_config.properties(开发环境默认值)的维护
    上述流程中配置文件需要人工介入的部分是如果本次改动有个配置变量，如mysql.host = ${mysql.host},在用脚本合并完配置文件后，需要手动把/home/configbak下的如test_config.properties里的mysql.host 改成实际值，如mysql.host = 192.168.10.80.在部署时会再去校验这些值。

1.3. Test Case

    校验开发发出的测试申请邮件的配置项改动和代码库src/profiles/install/changes.properties上是一致的。
    如果开发填的是个常量，需要确认是否真的是常量.
    测试时运行/bin/zxlh/javacrm-mvn-config.sh
    运行部署脚本后，代码库里src/profiles/install/changes.properties里的变量自动合并到/home/configbak/tourongjia_crm/test_config.properties，常量自动合并到/home/configbak/tourongjia_crm/static.properties
    changes.properties如果配置项前后有空白符或软回车，合并后自动消除
    changes.properties里的配置项在代码库里相应.properties里找不到，提示错误，中断部署
    changes.properties里配置项是${...},而在代码库里properties里是常量,提示错误，中断部署
    changes.properties里配置项是常量，而在代码库里properties里是变量，提示错误，中断部署
    changes.properties里的配置项的变量命名不正确，提示错误，中断部署
    带--前缀配置项表示删除，会把相应test_config.properties和static_config.properties里的配置删除
    增加的可变配置能添加到test_config.properties末尾，增加的固定配置能添加到static_config.properties末尾，修改的固定配置直接把static_config.properties的配置项修改掉。
    合并后需要修改的变量没有修改成实际值，在部署时提示错误信息，中断部署
    合并后的可变配置项和代码库里的可变配置项对比有缺失，提示错误，中断部署
    在部署后，实际生成的配置文件格式key/value正确无误
    如果代码库里.properties的源文件配置项中存在首尾空白符，软回车，部署后的配置文件中这些字符自动消除
    需要对绑卡、支付等主要流程做回归测试

 
1.4. TODO

    所有系统的配置文件服务化管理

