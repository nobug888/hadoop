#!/bin/bash
#校验 1.校验参数的个数

var=""
case $1 in
"start")
	var="start"
	;;
"stop")
	var="stop"
	;;
"restart")
	var="restart"
	;;
"status")
	var="status"
	;;
*)
	echo "参数内容错误！！！"
	#如果参数不对就不要向下执行了
	exit
	;;
esac


	for host in hadoop102 hadoop103 hadoop104
	do
		echo "================$host=================="
		ssh $host zkServer.sh $var
	done
