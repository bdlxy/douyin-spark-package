#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE=/root/.douyin-auth
LOG=$BASE/cron.log

echo "===== run at $(date '+%F %T') =====" >> $LOG

bash $BASE/ensure_services.sh >> $LOG 2>&1

cd $BASE
$BASE/venv/bin/python $BASE/send_spark.py >> $LOG 2>&1

echo "exit code: $?" >> $LOG
tail -20 $LOG
