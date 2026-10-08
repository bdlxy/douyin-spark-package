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
