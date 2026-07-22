import machine
from machine import Pin, SoftI2C, RTC
import time
import json
import network
import ntptime
import asyncio
import sh1106
import sys
import framebuf

# Global Variables / Config Defaults
config = {
    "wifi_ssid": "Antharjalam",
    "wifi_pass": "Superman$9",
    "tz_offset": -5,
    "flip_display": False,
    "brightness": 255,
    "t1": 9,   # Block 2 start (9 AM)
    "t2": 13,  # Block 3 start (1 PM)
    "t3": 17,  # Block 4 start (5 PM)
    "t4": 21   # Block 5 start (9 PM)
}

custom_timer_end = None
custom_timer_duration = 0
ntp_synced = False

# Read persistent configuration
def load_config():
    global config
    try:
        with open('config.json', 'r') as f:
            cfg = json.load(f)
            config.update(cfg)
            print("Loaded config successfully.")
    except Exception as e:
        print("Using default config, error:", e)

def save_config():
    try:
        with open('config.json', 'w') as f:
            json.dump(config, f)
        print("Saved config successfully.")
    except Exception as e:
        print("Failed to save config:", e)

load_config()

# Display Setup
# Standard 0.42" OLED is SH1106 128x64 with offsets (28, 12)
oled = None

def apply_display_config():
    if oled is None:
        return
    try:
        # Set Contrast / Brightness
        oled.write_cmd(0x81)
        oled.write_cmd(config["brightness"])
        
        # Set internal IREF
        oled.write_cmd(0xAD)
        oled.write_cmd(0x30)
        
        # Set flip orientation
        oled.flip(config["flip_display"])
    except Exception as e:
        print("Error applying display config:", e)

try:
    i2c = SoftI2C(sda=Pin(5), scl=Pin(6), freq=400000)
    oled = sh1106.SH1106_I2C(128, 64, i2c)
    apply_display_config()
    print("OLED display (SH1106) initialized successfully.")
except Exception as e:
    print("OLED display initialization failed:", e)

# Helper to draw large (scaled) text using a temporary FrameBuffer
def draw_large_text(text, x, y, scale=2):
    if oled is None:
        return
    
    w = len(text) * 8
    h = 8
    buf_size = (w * h) // 8 + 1
    buf = bytearray(buf_size)
    tb = framebuf.FrameBuffer(buf, w, h, framebuf.MONO_VLSB)
    tb.fill(0)
    tb.text(text, 0, 0, 1)
    
    for ty in range(h):
        for tx in range(w):
            if tb.pixel(tx, ty):
                oled.fill_rect(x + tx * scale, y + ty * scale, scale, scale, 1)

def update_oled():
    if oled is None:
        return
    
    try:
        oled.fill(0)
        
        # Get current state
        mode, current_time_str, remaining_secs, active_range, progress = get_system_status()
        
        # Coordinates offset
        x_off = 28
        y_off = 12
        
        rem_mins = (remaining_secs + 59) // 60
        min_text = str(rem_mins)
        scale = 3 if len(min_text) <= 3 else 2
        large_w = len(min_text) * 8 * scale
        large_x = x_off + (72 - large_w) // 2
        
        if mode != "custom":
            # 1. Draw Range Tab (centered at the top)
            text_w = len(active_range) * 8
            range_x = x_off + (72 - text_w) // 2
            oled.text(active_range, range_x, y_off + 0, 1)
            
            # 2. Draw Minutes Only
            draw_large_text(min_text, large_x, y_off + 10, scale)
        else:
            # Custom mode: No top range tab, vertically centered large minutes
            y_pos = y_off + (6 if scale == 3 else 8)
            draw_large_text(min_text, large_x, y_pos, scale)
        
        # 3. Draw Progress Bar (at the bottom, y = y_off + 35)
        oled.rect(x_off + 2, y_off + 35, 68, 5, 1)
        if progress > 0:
            fill_w = int(64 * min(max(progress, 0.0), 1.0))
            if fill_w > 0:
                oled.fill_rect(x_off + 4, y_off + 37, fill_w, 1, 1)
                
        oled.show()
    except Exception as e:
        print("OLED drawing error:", e)

# Wi-Fi setup (Station mode to connect to router)
ssid = config.get("wifi_ssid", "YOUR_WIFI_SSID")
password = config.get("wifi_pass", "YOUR_WIFI_PASSWORD")

wlan = network.WLAN(network.STA_IF)
wlan.active(False)
time.sleep(1.0)
wlan.active(True)
time.sleep(0.5)
print("Connecting to Wi-Fi...")
wlan.connect(ssid, password)

# Network background task
async def wifi_monitor_task():
    await asyncio.sleep(15)
    while True:
        if not wlan.isconnected() and wlan.status() != network.STAT_CONNECTING:
            s = config.get("wifi_ssid", "YOUR_WIFI_SSID")
            p = config.get("wifi_pass", "YOUR_WIFI_PASSWORD")
            try:
                wlan.connect(s, p)
            except Exception as e:
                pass
        await asyncio.sleep(10)

# NTP Sync Task
async def ntp_sync_task():
    global ntp_synced
    while True:
        if wlan.isconnected():
            try:
                print("Syncing time with NTP...")
                ntptime.settime()
                ntp_synced = True
                print("NTP time sync successful. Current UTC time:", time.localtime())
                await asyncio.sleep(12 * 3600)
            except Exception as e:
                print("NTP sync failed, retrying in 15s. Error:", e)
                await asyncio.sleep(15)
        else:
            await asyncio.sleep(5)

# Timer logic helper functions
def get_local_seconds():
    return time.time() + int(config["tz_offset"] * 3600)

def fmt_hr(h):
    h_12 = h % 12
    return 12 if h_12 == 0 else h_12

def get_system_status():
    global custom_timer_end, custom_timer_duration
    
    local_secs = get_local_seconds()
    local_tuple = time.localtime(local_secs)
    hour = local_tuple[3]
    minute = local_tuple[4]
    second = local_tuple[5]
    
    current_time_str = "{:02d}:{:02d}:{:02d}".format(hour, minute, second)
    
    # Check if custom timer is active
    if custom_timer_end is not None:
        utc_now = time.time()
        if utc_now < custom_timer_end:
            remaining_secs = int(custom_timer_end - utc_now)
            progress = 0.0
            if custom_timer_duration > 0:
                progress = (custom_timer_duration - remaining_secs) / custom_timer_duration
            return "custom", current_time_str, remaining_secs, "Custom", progress
        else:
            custom_timer_end = None
            custom_timer_duration = 0
            
    current_mins = hour * 60 + minute
    
    # Get config transition hours (5 blocks, 4 transition points)
    t1_mins = config.get("t1", 9) * 60
    t2_mins = config.get("t2", 13) * 60
    t3_mins = config.get("t3", 17) * 60
    t4_mins = config.get("t4", 21) * 60
    
    r1 = "12-{}".format(fmt_hr(config.get("t1", 9)))
    r2 = "{}-{}".format(fmt_hr(config.get("t1", 9)), fmt_hr(config.get("t2", 13)))
    r3 = "{}-{}".format(fmt_hr(config.get("t2", 13)), fmt_hr(config.get("t3", 17)))
    r4 = "{}-{}".format(fmt_hr(config.get("t3", 17)), fmt_hr(config.get("t4", 21)))
    r5 = "{}-12".format(fmt_hr(config.get("t4", 21)))
    
    if t1_mins <= current_mins < t2_mins:
        active_range = r2
        total_duration_secs = (t2_mins - t1_mins) * 60
        remaining_secs = (t2_mins * 60) - (current_mins * 60 + second)
    elif t2_mins <= current_mins < t3_mins:
        active_range = r3
        total_duration_secs = (t3_mins - t2_mins) * 60
        remaining_secs = (t3_mins * 60) - (current_mins * 60 + second)
    elif t3_mins <= current_mins < t4_mins:
        active_range = r4
        total_duration_secs = (t4_mins - t3_mins) * 60
        remaining_secs = (t4_mins * 60) - (current_mins * 60 + second)
    elif t4_mins <= current_mins < 1440:
        active_range = r5
        total_duration_secs = (1440 - t4_mins) * 60
        remaining_secs = (1440 * 60) - (current_mins * 60 + second)
    else: # 0 to t1_mins
        active_range = r1
        total_duration_secs = t1_mins * 60
        remaining_secs = (t1_mins * 60) - (current_mins * 60 + second)
            
    if remaining_secs < 0:
        remaining_secs = 0
        
    progress = (total_duration_secs - remaining_secs) / total_duration_secs if total_duration_secs > 0 else 0.0
    return "default", current_time_str, remaining_secs, active_range, progress

# Web request handlers
async def handle_client(reader, writer):
    global custom_timer_end, custom_timer_duration
    
    try:
        request_line = await reader.readline()
        if not request_line:
            return
            
        req = request_line.decode('utf-8').split()
        if len(req) < 2:
            return
            
        method, path = req[0], req[1]
        
        # Read remaining headers
        while True:
            line = await reader.readline()
            if line == b'\r\n' or line == b'\n':
                break
                
        if method == 'GET' and path in ('/', '/index.html'):
            # Serve index.html
            writer.write(b"HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n")
            try:
                with open('index.html', 'rb') as f:
                    while True:
                        chunk = f.read(256)
                        if not chunk:
                            break
                        writer.write(chunk)
                        await writer.drain()
            except Exception as e:
                writer.write(b"Error reading index.html")
                
        elif method == 'GET' and path == '/api/status':
            # Serve JSON status
            mode, current_time_str, remaining_secs, active_range, progress = get_system_status()
            status_json = {
                "mode": mode,
                "current_time": current_time_str,
                "remaining_secs": remaining_secs,
                "active_range": active_range,
                "progress": progress,
                "tz_offset": config["tz_offset"],
                "brightness": config["brightness"],
                "flip_display": config["flip_display"],
                "t1": config.get("t1", 9),
                "t2": config.get("t2", 13),
                "t3": config.get("t3", 17),
                "t4": config.get("t4", 21)
            }
            res_body = json.dumps(status_json)
            writer.write(b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n")
            writer.write(res_body.encode('utf-8'))
            
        elif method == 'POST' and path.startswith('/api/set'):
            mins = 0
            if 'mins=' in path:
                try:
                    mins = int(path.split('mins=')[1].split('&')[0])
                except:
                    pass
            if mins > 0:
                custom_timer_duration = mins * 60
                custom_timer_end = time.time() + custom_timer_duration
                print("Started custom timer for {} minutes".format(mins))
                
            writer.write(b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n")
            writer.write(b'{"status":"ok"}')
            
        elif method == 'POST' and path == '/api/reset':
            custom_timer_end = None
            custom_timer_duration = 0
            print("Reset to default schedule timer")
            writer.write(b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n")
            writer.write(b'{"status":"ok"}')
            
        elif method == 'POST' and path.startswith('/api/set_config'):
            params = {}
            if '?' in path:
                q = path.split('?')[1]
                for pair in q.split('&'):
                    if '=' in pair:
                        k, v = pair.split('=')
                        params[k] = v
            
            # Update configuration
            if 'tz_offset' in params:
                config['tz_offset'] = int(params['tz_offset'])
            if 'flip_display' in params:
                config['flip_display'] = params['flip_display'] in ('1', 'true', 'True')
            if 'brightness' in params:
                config['brightness'] = int(params['brightness'])
            if 't1' in params: config['t1'] = int(params['t1'])
            if 't2' in params: config['t2'] = int(params['t2'])
            if 't3' in params: config['t3'] = int(params['t3'])
            if 't4' in params: config['t4'] = int(params['t4'])
                
            apply_display_config()
            save_config()
            
            writer.write(b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n")
            writer.write(b'{"status":"ok"}')
            
        elif method == 'POST' and path == '/api/rotate':
            config['flip_display'] = not config.get('flip_display', False)
            apply_display_config()
            save_config()
            
            res_val = b"true" if config['flip_display'] else b"false"
            writer.write(b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n")
            writer.write(b'{"status":"ok","flip_display":' + res_val + b'}')
            
        else:
            writer.write(b"HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n")
            writer.write(b"Not Found")
            
        await writer.drain()
    except Exception as e:
        print("Web handling error:", e)
    finally:
        await writer.aclose()

# Timer and Display Update Task
async def display_timer_task():
    while True:
        update_oled()
        await asyncio.sleep(1)

# Main async runner
async def main():
    # Start web server
    print("Starting web server on port 80...")
    server = await asyncio.start_server(handle_client, "0.0.0.0", 80)
    
    # Start background tasks
    asyncio.create_task(wifi_monitor_task())
    asyncio.create_task(ntp_sync_task())
    asyncio.create_task(display_timer_task())
    
    print("System running. Waiting for connections...")
    while True:
        await asyncio.sleep(3600)

try:
    asyncio.run(main())
except KeyboardInterrupt:
    print("Shutting down...")
