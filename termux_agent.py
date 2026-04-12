"""
Termux Agent - Chay trong Termux tren Android
Khong can root

Cai dat (1 lan):
  pkg update -y && pkg install -y python termux-api
  pip install requests
  python termux_agent.py
"""

import subprocess, requests, json, time, os

GITHUB_TOKEN    = "YOUR_GITHUB_TOKEN"
GIST_ID         = "3c371b92bd526f2d0ca452cc70aebc4a"
GIST_FILE       = "commands.json"
DISCORD_WEBHOOK = "https://discord.com/api/webhooks/YOUR_WEBHOOK_TOKEN"
MY_NAME         = "manchanhkundz"
POLL_INTERVAL   = 3
SCREEN_PATH     = "/sdcard/termux_screen.png"

HEADERS = {"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"}
last_ts = 0

def screenshot():
    try:
        r = subprocess.run(["termux-screenshot", "-f", SCREEN_PATH], timeout=10, capture_output=True)
        time.sleep(0.5)
        return os.path.exists(SCREEN_PATH) and os.path.getsize(SCREEN_PATH) > 1000
    except Exception as e:
        print(f"Screenshot error: {e}")
        return False

def tap(x, y):
    try:
        subprocess.run(["input", "tap", str(x), str(y)], timeout=5)
    except:
        # Fallback: dung am
        subprocess.run(["termux-toast", f"Tap {x},{y}"], timeout=3)

def send_image(caption=""):
    if not os.path.exists(SCREEN_PATH): return
    with open(SCREEN_PATH, "rb") as f:
        requests.post(DISCORD_WEBHOOK,
            data={"payload_json": json.dumps({"content": caption})},
            files={"file": ("screen.png", f, "image/png")}, timeout=15)

def send_text(msg):
    try:
        requests.post(DISCORD_WEBHOOK, json={"content": msg}, timeout=5)
    except: pass

def read_gist():
    r = requests.get(f"https://api.github.com/gists/{GIST_ID}", headers=HEADERS, timeout=8)
    if r.status_code == 200:
        return json.loads(r.json()["files"][GIST_FILE]["content"])
    return None

def clear_gist():
    requests.patch(f"https://api.github.com/gists/{GIST_ID}", headers=HEADERS,
        json={"files": {GIST_FILE: {"content": json.dumps({"cmd":"","target":"","timestamp":0,"extra":{}})}}},
        timeout=8)

def main():
    global last_ts
    print(f"[Agent] Chay cho {MY_NAME}, poll moi {POLL_INTERVAL}s")
    send_text(f"📱 Termux Agent online | `{MY_NAME}`")

    while True:
        try:
            data = read_gist()
            if data:
                cmd    = data.get("cmd", "")
                target = data.get("target", "")
                ts     = int(data.get("timestamp", 0))
                extra  = data.get("extra", {})

                is_new    = ts > last_ts
                is_for_me = target.lower() == MY_NAME.lower() or target == "all"

                if cmd and is_new and is_for_me:
                    last_ts = ts
                    print(f"  CMD: {cmd}")

                    if cmd == "screenshot":
                        ok = screenshot()
                        if ok:
                            send_image(f"📸 `{MY_NAME}`")
                            print("  Sent screenshot")
                        else:
                            send_text("❌ Chup man hinh that bai - can cap quyen Termux:API")
                        clear_gist()

                    elif cmd == "click":
                        x, y = extra.get("x", 0), extra.get("y", 0)
                        tap(x, y)
                        send_text(f"✅ Click ({x},{y})")
                        clear_gist()

                    elif cmd == "autoclick":
                        x        = extra.get("x", 0)
                        y        = extra.get("y", 0)
                        interval = extra.get("interval", 1000) / 1000
                        count    = extra.get("count", 10)
                        send_text(f"▶️ AutoClick ({x},{y}) x{count} interval={interval}s")
                        clear_gist()
                        for i in range(count):
                            tap(x, y)
                            time.sleep(interval)
                        send_text(f"⏹ AutoClick xong")

        except Exception as e:
            print(f"  Error: {e}")

        time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    main()
