#!/bin/bash
BASE=/root/.douyin-auth
CHROME=/root/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome

if ! pgrep -f 'Xvfb :99' >/dev/null 2>&1; then
  nohup Xvfb :99 -screen 0 1280x900x24 > $BASE/xvfb.log 2>&1 &
  sleep 3
fi

if ! pgrep -f fluxbox >/dev/null 2>&1; then
  DISPLAY=:99 nohup fluxbox > $BASE/fluxbox.log 2>&1 &
  sleep 2
fi

if ! curl -s --max-time 3 http://127.0.0.1:9222/json/version >/dev/null 2>&1; then
  DISPLAY=:99 nohup "$CHROME" --no-sandbox --disable-dev-shm-usage --disable-gpu --remote-debugging-port=9222 --remote-allow-origins=* --user-data-dir=$BASE/chrome-gui --window-size=1280,860 --window-position=0,0 'https://www.douyin.com/chat?isPopup=1' > $BASE/gui-browser.log 2>&1 &
  sleep 20
fi

echo "services ensured at $(date '+%F %T')"
