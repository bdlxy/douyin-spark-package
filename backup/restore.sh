#!/bin/bash
echo "=== 恢复续火花任务到备份状态 ==="
cp /root/.douyin-auth/backup/send_spark.py.bak /root/.douyin-auth/send_spark.py
cp /root/.douyin-auth/backup/daily_spark.sh.bak /root/.douyin-auth/daily_spark.sh
cp /root/.douyin-auth/backup/ensure_services.sh.bak /root/.douyin-auth/ensure_services.sh
chmod +x /root/.douyin-auth/send_spark.py /root/.douyin-auth/daily_spark.sh /root/.douyin-auth/ensure_services.sh
crontab /root/.douyin-auth/backup/crontab.bak
echo "恢复完成，定时任务已还原，脚本已还原"
crontab -l | grep -v '^#'
