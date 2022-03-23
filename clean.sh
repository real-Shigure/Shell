#!/bin/bash
###ver=5.0.0

PATH="/usr/local/bin:/usr/bin:/sbin:/usr/X11R6/bin:/usr/sbin:/bin:/usr/games"
export PATH

# 20%
CPU_LIMIT=2000
# uint: KB, 50M
RSS_LIMIT=51200

SCRIPT_PATH=/usr/local/sa/agent/kill.sh
BASE_DIR=/usr/local/sa/agent

PROC_NAME=secu-tcs-agent

PS_INFO=$BASE_DIR/secubase/secu-tcs-ps.info
MON_LOG=$BASE_DIR/secubase/secu-tcs-ps.log
LIMIT_FILE=$BASE_DIR/secubase/secu-tcs-ps.lmt
RESTART_FILE=$BASE_DIR/secubase/secu-tcs-restart.cnt

# 检查日志, 如果大小超过限制就删除
if [ -e ${MON_LOG} ]; then
        LOG_FILE_SIZE=`stat --format=%s ${MON_LOG}`
        # limit 10K
        if [ $LOG_FILE_SIZE -gt 10240 ]; then
                rm -f ${MON_LOG}
        fi
fi

# 获取pid为1的进程的mnt namespace inode
PID1_MNT_NS_INODE=""
if [ -L /proc/1/ns/mnt ]; then
        PID1_MNT_NS_INODE=$(readlink /proc/1/ns/mnt)
fi


function DoLog()
{
        CUR_TIME=`date +"%Y-%m-%d %H:%M:%S"`
        echo "[$CUR_TIME] $1" >> $MON_LOG
}

function DoStop()
{
        if [ -z "$PID1_MNT_NS_INODE" ]; then
                LIST_WATCH_DOG_PID=`ps -efw | grep "watchdog\.sh" | grep $BASE_DIR | grep -v grep | awk -F ' ' '{print $2}'`
                for watchdog_pid in $LIST_WATCH_DOG_PID
                do
                        kill -9 $watchdog_pid
                done

                LIST_AGENT_PID=`ps -efw | grep -E "${PROC_NAME}($|[[:space:]]+)" | grep $BASE_DIR | grep -v grep | awk -F ' ' '{print $2}'`
                for agent_pid in $LIST_AGENT_PID
                do
                        kill -9 $agent_pid
                done
        else
                LIST_WATCH_DOG_PID=`ps -efw | grep "watchdog\.sh" | grep $BASE_DIR | grep -v grep | awk -F ' ' '{print $2}'`
                for watchdog_pid in $LIST_WATCH_DOG_PID
                do
                        WATCHDOG_MNT_NS_INODE=$(readlink /proc/${watchdog_pid}/ns/mnt)
                        if [ "$WATCHDOG_MNT_NS_INODE" = "$PID1_MNT_NS_INODE" ]; then
                                kill -9 $watchdog_pid
                        fi
                done

                LIST_AGENT_PID=`ps -efw | grep -E "${PROC_NAME}($|[[:space:]]+)" | grep $BASE_DIR | grep -v grep | awk -F ' ' '{print $2}'`
                for agent_pid in $LIST_AGENT_PID
                do
                        AGENT_MNT_NS_INODE=$(readlink /proc/${agent_pid}/ns/mnt)
                        if [ "$AGENT_MNT_NS_INODE" = "$PID1_MNT_NS_INODE" ]; then
                                kill -9 $agent_pid
                        fi
                done
        fi
}

DoStop
