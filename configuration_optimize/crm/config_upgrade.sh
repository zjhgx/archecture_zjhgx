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
	awk "/\[.*\]/{F++;next}/[^\s]+/{if(F==$i){gsub(/^( |\t)*|( |\t)*$|(\r)/,\"\");print}}/\[.*\]/"  $changes_file | egrep -v '^#' > /tmp/$$

	count=$(cat /tmp/$$ | wc -l)
	if [ $count -eq 0 ]; then
        	echo "$path没有配置项需要修改"
        	continue
	fi
	
	#检查changes.properties的完整性/命名正确性
	#while read line
	for propertiesline in $(awk '/^[^-{2}]/ {print}' /tmp/$$);do
		if  ! `grep -q "$propertiesline" "$WEB_APP_PATH/$path"`; then
			echo "[Error]: can not find $propertiesline in \"$WEB_APP_PATH/$path\"" 
			EXIT_FLAG="1"
		else
			prop_key=`echo $propertiesline | awk -F= '{gsub(/^( |\t)*|( |\t)*$/,"",$1);print $1}'`
			prop_value=`echo $propertiesline | awk -F= '{gsub(/^( |\t)*|( |\t)*$/,"",$1);print $2}'`
			if [ $(echo $prop_value | awk -F '[$|{|}]' '{pirint $3}') ]; then
				prop_variable=$(echo $prop_value | awk -F '[$|{|}]' '{print $3}')
				if [ "$prop_key" != "$prop_variable" ];then
					echo "[Error]: $propertiesline命名错误，请检查"
					EXIT_FLAG="1"
				fi
			fi
		fi	
	done

	if [ $EXIT_FLAG = "1" ]; then
		echo "[Error]: changes.properties check fail,script quit"
		exit 1
	fi
	#合并changes.properties
	for key in $(awk -F "=|-{2}" '/^-{2}/{print $2}/^[^-{2}]/{print $1}' /tmp/$$) ; do
		line=$(awk '/'$key'[ \t]*=/ {print;exit}' /tmp/$$)
		echo $line
		
	        change_value=`echo $line | awk -F= '{gsub(/^( |\t)*|( |\t)*$/,"",$2);print $2}'`
		change_variable_part=`echo $change_value | awk -F '[$|{|}]' '{print $3}'`
		#如果是变量则需要合并到test_config.properties
		if [ "$change_variable_part" ]; then
                        exist_config=$(grep  "^$key[ \t]*=" "$CONFIG_FILE_PATH/$CONFIG_FILE" | head -1)
			#delete config
                        if [ $(echo $line | awk '/^-{2}/ {print}') ]; then
				if [ "$exist_config" ]; then
	                                sed -i "/^$key[ \t]*=/d" "$CONFIG_FILE_PATH/$CONFIG_FILE"
         	                        echo "[Info]: $key项已从$CONFIG_FILE_PATH/$CONFIG_FILE中删除"
                	                continue
				else
					echo "[Warning]: $key项在$CONFIG_FILE_PATH/$CONFIG_FILE中不存在，无需删除"	
				fi
                        fi
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

	        	if [ $(echo $line | awk '/^-{2}/ {print}') ]; then
				if [ "$exist_config" ]; then
                               		sed -i "/^$key[ \t]*=/d" "$CONFIG_FILE_PATH/$STATIC_CONFIG_FILE"       
                                	echo "[Info]: $key项已从$CONFIG_FILE_PATH/$STATIC_CONFIG_FILE中删除"
				else
					echo "[Warning]: $key项在$CONFIG_FILE_PATH/$STATIC_CONFIG_FILE中不存在，无需删除"
				fi
                                continue
                        fi

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


done

#去除配置项首尾空白符
blank_count=$(awk '/^[ \t]+|[ \t]+$|\r/' "$CONFIG_FILE_PATH/$CONFIG_FILE" | wc -l )
if [ $blank_count -gt 0 ]; then
	sed -i -e 's/^[ \t]*//g' "$CONFIG_FILE_PATH/$CONFIG_FILE"
	sed -i -e 's/[ \t]*$//g' "$CONFIG_FILE_PATH/$CONFIG_FILE"
	sed -i -e 's/\r//g' "$CONFIG_FILE_PATH/$CONFIG_FILE"
	echo "[Warning]: $CONFIG_FILE上配置项发现非法字符，已删除"
fi

if [ $MANUAL_FLAG -eq 1 ]; then
	echo "[Info]: 请修改$CONFIG_FILE_PATH/$CONFIG_FILE后重新运行脚本"
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
		else
			value=$(echo $t | awk -F= '{gsub(/^( |\t)*|( |\t)*$/,"",$2);print $2}')
			variable_part=`echo $value | awk -F '[$|{|}]' '{print $3}'`
			if [ "$variable_part" ]; then
				echo  "[Error]: $CONFIG_FILE_PATH/$CONFIG_FILE配置项$key未修改成实际值,请检查"
				exit 1
			fi

		fi
	done
	
done

echo '[Info]: changes.properties合并完成'
exit 0
