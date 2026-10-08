[douyin-spark-setup.md](https://github.com/user-attachments/files/33214107/douyin-spark-setup.md)
# 抖音续火花自动发送方案

每天 09:00 自动检测抖音消息列表中的置顶会话，向所有置顶会话发送固定消息。

## 环境要求

- Ubuntu 24.04 LTS（x86_64）
- Python 3.12+
- 至少 2GB 内存（含 2GB swap）
- 已登录的抖音账号（浏览器登录态）

## 依赖安装

### 系统依赖

```bash
apt-get update -y
apt-get install -y python3-venv python3-dev xvfb fluxbox x11vnc websockify novnc scrot
```

### Python 虚拟环境与依赖

```bash
mkdir -p /root/.douyin-auth
python3 -m venv /root/.douyin-auth/venv
/root/.douyin-auth/venv/bin/pip install --upgrade pip -q
/root/.douyin-auth/venv/bin/pip install -q playwright qrcode pillow opencv-python-headless
```

### 浏览器内核

```bash
export PLAYWRIGHT_DOWNLOAD_HOST=https://cdn.npmmirror.com/binaries/playwright
/root/.douyin-auth/venv/bin/python -m playwright install-deps chromium
/root/.douyin-auth/venv/bin/python -m playwright install chromium
```

## 脚本清单

所有脚本位于 `/root/.douyin-auth/` 目录下。

### 1. send_spark.py — 发送逻辑主脚本

```python
import asyncio
from playwright.async_api import async_playwright

BASE = "/root/.douyin-auth"
MSG = "【续火花脚本消息】"
LOG = BASE + "/send_log.txt"

# ===== 可调节配置 =====
PINNED_COUNT_TO_SEND = 0  # 0 表示自动检测所有置顶会话，全部发送
# =====================


def log(m):
    print(m, flush=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(m + "\n")


async def send_to_one(page, item, idx):
    try:
        title = (await item.inner_text()).replace("\n", " / ")[:50]
    except Exception:
        title = "?"
    log("TARGET_%d:%s" % (idx, title))
    await item.click()
    await page.wait_for_timeout(4000)
    boxes = page.locator('[contenteditable="true"]')
    bcnt = await boxes.count()
    if bcnt == 0:
        log("NO_INPUT_%d" % idx)
        await page.screenshot(path=BASE + ("/notify_no_input_%d.png" % idx))
        return False
    box = boxes.last
    await box.click()
    await page.wait_for_timeout(800)
    await page.keyboard.insert_text(MSG)
    await page.wait_for_timeout(1000)
    await page.keyboard.press("Enter")
    await page.wait_for_timeout(3500)
    log("SENT_OK_%d" % idx)
    return True


async def main():
    async with async_playwright() as p:
        browser = await p.chromium.connect_over_cdp("http://127.0.0.1:9222")
        ctx = browser.contexts[0]
        page = None
        for pg in ctx.pages:
            if "chat" in pg.url:
                page = pg
                break
        if page is None:
            for pg in ctx.pages:
                if "douyin.com" in pg.url and "verify" not in pg.url:
                    page = pg
                    break
        if page is None:
            log("NO_PAGE")
            return
        await page.bring_to_front()
        await page.wait_for_timeout(3000)
        log("URL:" + page.url)

        if "chat" not in page.url:
            try:
                await page.goto("https://www.douyin.com/chat?isPopup=1", wait_until="domcontentloaded", timeout=30000)
                await page.wait_for_timeout(5000)
                log("OPENED_CHAT")
            except Exception as e:
                log("OPEN_CHAT_ERR:" + str(e)[:120])

        pinned = page.locator('[class*="isStickOnTop"]')
        total = await pinned.count()
        log("PINNED_TOTAL:%d" % total)
        if total == 0:
            log("NO_PINNED")
            await page.screenshot(path=BASE + "/notify_no_pinned.png")
            return

        send_n = total if PINNED_COUNT_TO_SEND == 0 else min(PINNED_COUNT_TO_SEND, total)
        log("WILL_SEND_TO:%d" % send_n)
        success = 0
        for i in range(send_n):
            item = pinned.nth(i)
            ok = await send_to_one(page, item, i + 1)
            if ok:
                success += 1
            if i < send_n - 1:
                await page.wait_for_timeout(2000)
        log("ALL_DONE success=%d/%d" % (success, send_n))


asyncio.run(main())
```

### 2. ensure_services.sh — 运行环境自检与自动拉起

```bash
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
```

### 3. daily_spark.sh — 每日任务入口

```bash
#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE=/root/.douyin-auth
LOG=$BASE/cron.log

echo "===== run at $(date '+%F %T') =====" >> $LOG

bash $BASE/ensure_services.sh >> $LOG 2>&1

cd $BASE
$BASE/venv/bin/python $BASE/send_spark.py >> $LOG 2>&1

echo "exit code: $?" >> $LOG
```

### 4. backup/restore.sh — 一键恢复脚本

```bash
#!/bin/bash
echo "=== 恢复续火花任务到备份状态 ==="
cp /root/.douyin-auth/backup/send_spark.py.bak /root/.douyin-auth/send_spark.py
cp /root/.douyin-auth/backup/daily_spark.sh.bak /root/.douyin-auth/daily_spark.sh
cp /root/.douyin-auth/backup/ensure_services.sh.bak /root/.douyin-auth/ensure_services.sh
chmod +x /root/.douyin-auth/send_spark.py /root/.douyin-auth/daily_spark.sh /root/.douyin-auth/ensure_services.sh
crontab /root/.douyin-auth/backup/crontab.bak
echo "恢复完成，定时任务已还原，脚本已还原"
crontab -l | grep -v '^#'
```

## 部署命令集

### 首次部署（按顺序执行）

```bash
# 1. 安装系统依赖
apt-get update -y && apt-get install -y python3-venv python3-dev xvfb fluxbox x11vnc websockify novnc scrot

# 2. 创建虚拟环境并安装 Python 依赖
mkdir -p /root/.douyin-auth
python3 -m venv /root/.douyin-auth/venv
/root/.douyin-auth/venv/bin/pip install --upgrade pip -q
/root/.douyin-auth/venv/bin/pip install -q playwright qrcode pillow opencv-python-headless

# 3. 安装浏览器内核（使用国内镜像加速）
export PLAYWRIGHT_DOWNLOAD_HOST=https://cdn.npmmirror.com/binaries/playwright
/root/.douyin-auth/venv/bin/python -m playwright install-deps chromium
/root/.douyin-auth/venv/bin/python -m playwright install chromium

# 4. 将上述三个脚本写入对应文件并赋予执行权限
chmod +x /root/.douyin-auth/send_spark.py /root/.douyin-auth/daily_spark.sh /root/.douyin-auth/ensure_services.sh

# 5. 首次登录抖音（需要手动操作）
# 启动浏览器并打开抖音，手动扫码登录
# 登录成功后浏览器登录态会自动保存在 chrome-gui 目录中

# 6. 配置定时任务
(crontab -l 2>/dev/null | grep -v 'daily_spark.sh' | grep -v 'ensure_services.sh'; echo '# DYSPARK managed tasks'; echo '0 9 * * * /bin/bash /root/.douyin-auth/daily_spark.sh >/dev/null 2>&1'; echo '@reboot sleep 30 && /bin/bash /root/.douyin-auth/ensure_services.sh >/dev/null 2>&1') | crontab -

# 7. 手动试跑一次验证
bash /root/.douyin-auth/daily_spark.sh
```

### 日常维护命令

```bash
# 查看最近执行日志
tail -20 /root/.douyin-auth/cron.log

# 手动执行一次发送
cd /root/.douyin-auth && ./venv/bin/python send_spark.py

# 检查浏览器是否在线
curl -s http://127.0.0.1:9222/json/version | head -c 100

# 检查登录态是否有效
python3 -c "import sqlite3; c=sqlite3.connect('/root/.douyin-auth/chrome-gui/Default/Cookies'); rs=c.execute(\"select name from cookies where host_key like '%douyin%'\").fetchall(); n=[r[0] for r in rs]; print('real_login:', [x for x in n if x in ('sessionid','sessionid_ss','sid_tt','uid_tt','uid_tt_ss','sid_guard')])"

# 出问题时一键恢复
bash /root/.douyin-auth/backup/restore.sh
```

## 配置说明

### 调整发送人数

编辑 `/root/.douyin-auth/send_spark.py`，修改第 8 行附近的 `PINNED_COUNT_TO_SEND`：
- `0`：自动检测所有置顶会话，全部发送
- `1`：只给第一个置顶会话发送
- `2`：给前两个置顶会话发送
- 以此类推

### 调整发送内容

编辑 `/root/.douyin-auth/send_spark.py`，修改第 5 行的 `MSG` 变量。

### 调整发送时间

编辑 crontab：`crontab -e`，修改 `0 9 * * *` 中的 `9` 为目标小时（24 小时制）。

## 定时任务

```
0 9 * * * /bin/bash /root/.douyin-auth/daily_spark.sh >/dev/null 2>&1
@reboot sleep 30 && /bin/bash /root/.douyin-auth/ensure_services.sh >/dev/null 2>&1
```

## 文件结构

```
/root/.douyin-auth/
├── venv/                    # Python 虚拟环境
├── chrome-gui/              # 浏览器用户数据（含登录态）
├── send_spark.py            # 发送逻辑主脚本
├── daily_spark.sh           # 每日任务入口
├── ensure_services.sh       # 运行环境自检与自动拉起
├── cron.log                 # 每次自动执行的日志
├── send_log.txt             # 发送脚本的运行日志
├── backup/                  # 备份目录
│   ├── send_spark.py.bak
│   ├── daily_spark.sh.bak
│   ├── ensure_services.sh.bak
│   ├── crontab.bak
│   └── restore.sh           # 一键恢复脚本
└── *.png                    # 发送前后截图（调试用）
```

## 注意事项

1. **登录态依赖**：整个方案依赖浏览器中已登录的抖音账号。若登录态失效（退出登录、会话过期、平台风控），当天发送会失败，需重新手动登录。
2. **云端环境风险**：云服务器机房 IP 可能被抖音风控标记，长周期运行存在被拦截的可能。建议定期查看 `cron.log` 确认执行状态。
3. **时区**：确保服务器时区为 `Asia/Shanghai`（+0800），否则定时任务执行时间会偏移。
4. **浏览器内核路径**：如果 Playwright 安装的浏览器版本不同，需修改 `ensure_services.sh` 中的 `CHROME` 路径。
