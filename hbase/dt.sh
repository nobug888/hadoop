#!/bin/bash
#dt.sh 日期，可以让集群中所有机器的时间同步到此日期
#如果用户没有传入要同步的日期，同步日期到当前的最新时间
if(($#==0))
then
        xcall sudo ntpdate -u ntp1.aliyun.com
        exit;
fi

#dt.sh 日期，可以让集群中所有机器的时间同步到此日期
for((i=102;i<=104;i++))
do
        echo "--------------同步hadoop$i--------------"
        ssh hadoop$i "sudo date -s '$@'"
done
