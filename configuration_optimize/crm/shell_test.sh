#!/bin/bash
#set -x


#去除空格
echo "    a bc    " | awk 'gsub(/^ *| *$/,"")'

match_flag=echo `grep -q "^spring" "/home/vobile/test/sedTest.yml"`

echo `$match_flag|wc -l`

if `grep -q "^spring" "/home/vobile/test/sedTest.yml"`; then
	echo "matching"
fi


if $match_flag; then
	echo "match"
else
	echo "not match"
fi

if [ `grep -q "^spring" "/home/vobile/test/sedTest.yml"` ]; then

	echo "matched 1"
fi


if [ $match_flag ]; then

        echo "matched 2"
fi

./subshell_test.sh
echo $?


#提取字符串
test_str='aaa=${dsdsdsds}'

echo $test_str
echo ${test_str#*\$\{}| echo %\}
