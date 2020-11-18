#!/bin/sh


REGISTRATION_CENTER_IP="xx.xx.xx.xx"


##服务配置
SERVICE_IP="xx.xx.xx.xx"
PORT="xxxx"
NODE_NUM="1"
SERVICE_NAME="service-name"
SERVICE_ID="$SERVICE_NAME""_$PORT""_node$NODE_NUM"



#删除consul上指定节点
deregister(){
	curl -X PUT http://$REGISTRATION_CENTER_IP:8500/v1/agent/service/deregister/$SERVICE_ID
	echo "$SERVICE_ID节点删除成功。。"
}



#注册节点
register(){
    config="{\"ID\":\"$SERVICE_ID\",\"Name\":\"$SERVICE_NAME\",\"Address\":\"$SERVICE_IP\",\"Port\":$PORT,\"Check\":{\"HTTP\":\"http://$SERVICE_IP:$PORT/check\",\"Interval\":\"5s\"}}"
    echo "===>$config"
	curl -X PUT -d $config http://$REGISTRATION_CENTER_IP:8500/v1/agent/service/register
	echo "$SERVICE_ID节点注册成功。。"

}


#节点健康检查
health_check(){
	result=`curl http://$REGISTRATION_CENTER_IP:8500/v1/health/checks/$SERVICE_NAME`

	if [ $result = "[]" ]; then
    	echo "fail"
    else
    	echo "ok"
	fi
}



#查询节点
check(){
	node=$(curl http://$REGISTRATION_CENTER_IP:8500/v1/catalog/service/$SERVICE_NAME)
	echo $node
}


is_exist(){
        pid=$(netstat -tunlp | grep $PORT | awk '{print $7}' | awk -F"/" '{print $1}')
        #PID不存在返回0，存在返回1，判断为空时，要在[]的左边和右边（内部）都加上空格
        if [ -n "$pid" ]
        then
                echo "$PORT端口进程正在运行。 PID=$pid"
                return "$pid"
        else
                echo "$PORT端口进程不存在。"
                return 0
        fi
}

#启动方法
start(){
        #先判断是否在运行
        is_exist
        #$? 显示最后命令的退出状态，0无错误，其他有错误；或函数返回值
        if [ $? -eq "0" ]
        then
                nohup python3 $1 &
                #检验服务是否启动成功
                sleep 10
                pid=$(ps -ef | grep $1 | grep -v -E 'grep|/bin/sh' | awk '{print $2}')
                if [ -n $pid ]
                then
                    echo "$1, 端口$PORT服务成功启动。"
                else
                    echo "$1, 端口$PORT服务启动失败。"
                fi
        else
                echo "$1, 端口$PORT已经在运行, PID=$pid"
        fi
}

#停止方法
stop(){
        #先判断是否在运行
        is_exist
        if [ $? -eq "0" ]
        then
                echo "$1, 端口$PORT is not running."
        else
                kill -9 $?
                #检验服务是否停止成功
                is_exist
                if [ $? -eq "0" ]
                then
                    echo "服务成功关闭。"
                fi
        fi
}

#重启
restart(){
        echo "$1, 端口$PORT更新开始。。。"
         # 节点注销
        deregister
        health=$(health_check)
        if [ $health = "fail" ]
        then
            echo "$SERVICE_ID节点已注销成功"
            stop $1
            sleep 5
            echo "$1, 端口$PORT开始重启..."
            start
            echo "服务成功重启。"
            # 节点重新注册
            register
            sleep 2
            health=$(health_check)
            if [ $health = "ok" ]
            then
                echo "$SERVICE_ID节点重新注册成功！"
            else
                echo "$SERVICE_ID节点重新注册失败！请查找原因！"
            fi
        else
            echo "$SERVICE_ID节点已注销失败"
        fi
}



case $2 in
"start")
        #因为start方法中使用了$1变量，在调用时需要把参数传入，不然无法获取到
        start $1
        ;;
"stop")
        stop $1
        ;;
"restart")
        restart $1
        ;;
"ps")
        is_exist
        ;;
"deregister")
        deregister
        ;;
"register")
        register
        ;;
"check")
        check
        ;;
"health_check")
        health_check
        ;;
*)
        echo "Usage: ./api_service.sh    服务启动文件名   start|stop|restart|ps|register|deregister|check|health_check"
        # test测试环境，release正式环境
        ;;
esac
