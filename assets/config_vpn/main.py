import requests
from bs4 import BeautifulSoup
import re
import os
import html
import json
import base64
import urllib.parse
from datetime import datetime, timezone

# =============================================================
#  بخش تنظیمات (Settings)
# =============================================================
PINNED_CONFIGS = [
    "ss://bm9uZTpmOGY3YUN6Y1BLYnNGOHAz@lil:360#%F0%9F%91%91",
]

MY_CHANNEL_ID = "@Express_alaki"
CUSTOM_SEPARATOR = "|"
NOT_FOUND_FLAG = "🌐"

SUPPORTED_PROTOCOLS = ['vless://', 'vmess://', 'trojan://', 'hysteria2://', 'hy2://']

EXPIRY_HOURS = 12       # حذف کانفیگ‌های قدیمی‌تر از ۱۲ ساعت از دیتابیس
SEARCH_LIMIT_HOURS = 1  # بررسی پیام‌های ۱ ساعت اخیر کانال‌ها
ROTATION_LIMIT = 65      
ROTATION_LIMIT_2 = 1000   
ROTATION_LIMIT_3 = 3000   
# =============================================================

def get_only_flag(text):
    if not text: return NOT_FOUND_FLAG
    try:
        text = urllib.parse.unquote(urllib.parse.unquote(str(text)))
    except: pass
    flag_pattern = re.compile(r'[\U0001F1E6-\U0001F1FF]{2}')
    flags = flag_pattern.findall(text)
    return flags[0] if flags else NOT_FOUND_FLAG

def parse_vmess_uri(config):
    try:
        b64_str = config[8:]
        b64_str += "=" * (-len(b64_str) % 4)
        data = json.loads(base64.b64decode(b64_str).decode('utf-8'))
        raw_name = data.get('ps', '')
        net = data.get('net', 'tcp').lower()
        tls = data.get('tls', '').lower()
        transport = net
        security = 'TLS' if tls == 'tls' else 'None'
        return data, raw_name, transport, security, True
    except:
        return None, "", "TCP", "None", False

def get_config_core(config):
    """ استخراج بخش فنی کانفیگ برای تشخیص تکراری بودن بدون در نظر گرفتن نام """
    try:
        config = config.strip()
        if config.startswith("vmess://"):
            data, _, _, _, is_json = parse_vmess_uri(config)
            if is_json:
                # مقایسه بر اساس آدرس، پورت و آیدی اصلی
                return f"vmess-{data.get('add')}:{data.get('port')}:{data.get('id')}"
        else:
            # برای سایر پروتکل‌ها، بخش قبل از # تمام تنظیمات فنی را شامل می‌شود
            return config.split('#')[0]
    except:
        return config

def analyze_and_rename(config, channel_name):
    try:
        config = config.strip()
        clean_source = channel_name.replace("https://t.me/", "@").replace("t.me/", "@")
        if not clean_source.startswith("@"): clean_source = f"@{clean_source}"

        transport, security, flag = "TCP", "None", NOT_FOUND_FLAG
        
        if config.startswith("vmess://"):
            data, raw_name, v_trans, v_sec, is_json = parse_vmess_uri(config)
            if is_json:
                flag = get_only_flag(raw_name)
                t_map = {'tcp': 'TCP', 'ws': 'WS', 'grpc': 'GRPC', 'kcp': 'KCP', 'h2': 'H2', 'quic': 'QUIC', 'httpupgrade': 'HTTPUpgrade', 'xhttp': 'XHTTP'}
                transport = t_map.get(v_trans.lower(), 'TCP')
                security = v_sec
                # فرمت: flag transport-tls | @source
                new_ps = f"{flag} {transport}-{security} {CUSTOM_SEPARATOR} {clean_source}"
                data['ps'] = new_ps
                return "vmess://" + base64.b64encode(json.dumps(data).encode('utf-8')).decode('utf-8')

        if '#' in config:
            base_url, raw_fragment = config.split('#', 1)
        else:
            base_url, raw_fragment = config, ""

        flag = get_only_flag(raw_fragment)
        try:
            parsed = urllib.parse.urlparse(base_url)
            params = {k.lower(): v.lower() for k, v in urllib.parse.parse_qsl(parsed.query)}
        except: params = {}

        if 'security' in params:
            if params['security'] in ['tls', 'xtls', 'ssl']: security = 'TLS'
            elif params['security'] == 'reality': security = 'Reality'
        elif 'sni' in params or 'pbk' in params: security = 'Reality' if 'pbk' in params else 'TLS'

        t_val = params.get('type', params.get('net', 'tcp'))
        t_map = {'tcp': 'TCP', 'ws': 'WS', 'grpc': 'GRPC', 'kcp': 'KCP', 'httpupgrade': 'HTTPUpgrade', 'xhttp': 'XHTTP'}
        transport = t_map.get(t_val, 'TCP')

        if config.startswith(('hysteria2://', 'hy2://')): transport, security = "Hysteria", "TLS"

        # فرمت درخواستی: flag transport-tls | @source
        final_name = f"{flag} {transport}-{security} {CUSTOM_SEPARATOR} {clean_source}"
        return f"{base_url}#{urllib.parse.quote(final_name)}"
    except:
        return config

def extract_configs_logic(msg_div):
    for img in msg_div.find_all("img"):
        if 'emoji' in img.get('class', []) and img.get('alt'): img.replace_with(img['alt'])
    for br in msg_div.find_all("br"): br.replace_with("\n")
    full_text = html.unescape(msg_div.get_text())
    extracted = []
    for line in full_text.split('\n'):
        line = line.strip()
        starts = []
        for proto in SUPPORTED_PROTOCOLS:
            for m in re.finditer(re.escape(proto), line): starts.append((m.start(), proto))
        starts.sort(key=lambda x: x[0])
        for i in range(len(starts)):
            start_pos = starts[i][0]
            candidate = line[start_pos:starts[i+1][0]] if i+1 < len(starts) else line[start_pos:]
            if len(candidate.strip()) > 15: extracted.append(candidate.strip())
    return extracted

def run():
    if not os.path.exists('channels.txt'): return
    with open('channels.txt', 'r') as f:
        channels = [line.strip() for line in f if line.strip()]

    db_data = []
    if os.path.exists('data.temp'):
        with open('data.temp', 'r', encoding='utf-8') as f:
            for line in f:
                parts = line.strip().split('|', 2)
                if len(parts) == 3: db_data.append(parts)

    # برای جلوگیری از تکرار در طول کل برنامه
    seen_cores = set()
    for pin in PINNED_CONFIGS: seen_cores.add(get_config_core(pin))

    now = datetime.now().timestamp()

    # استخراج جدید
    for ch in channels:
        try:
            resp = requests.get(f"https://t.me/s/{ch}", timeout=15)
            if resp.status_code != 200: continue
            soup = BeautifulSoup(resp.text, 'html.parser')
            for wrap in soup.find_all('div', class_='tgme_widget_message_wrap'):
                time_tag = wrap.find('time')
                if not time_tag: continue
                msg_time = datetime.fromisoformat(time_tag['datetime'])
                if (datetime.now(timezone.utc) - msg_time).total_seconds() > (SEARCH_LIMIT_HOURS * 3600): continue
                msg_text = wrap.find('div', class_='tgme_widget_message_text')
                if not msg_text: continue
                for c in extract_configs_logic(msg_text):
                    core = get_config_core(c)
                    if core not in seen_cores:
                        db_data.append([str(now), ch, c])
                        seen_cores.add(core)
        except: continue

    # فیلتر ۱۲ ساعته برای کل دیتابیس
    valid_items = [item for item in db_data if now - float(item[0]) < (EXPIRY_HOURS * 3600)]

    # مرتب‌سازی و حذف تکراری نهایی قبل از توزیع در فایل‌ها
    unique_pool = []
    final_seen = set()
    for pin in PINNED_CONFIGS: final_seen.add(get_config_core(pin))
    
    for item in valid_items:
        core = get_config_core(item[2])
        if core not in final_seen:
            unique_pool.append(item)
            final_seen.add(core)

    # چرخش و توزیع
    current_index = 0
    if os.path.exists('pointer.txt'):
        try:
            with open('pointer.txt', 'r') as f: current_index = int(f.read().strip())
        except: current_index = 0
    
    pool_size = len(unique_pool)
    if current_index >= pool_size: current_index = 0

    def get_rotated_batch(size):
        if pool_size == 0: return []
        actual_size = min(size, pool_size)
        if current_index + actual_size <= pool_size:
            return unique_pool[current_index : current_index + actual_size]
        else:
            return unique_pool[current_index:] + unique_pool[:actual_size - (pool_size - current_index)]

    batch1 = get_rotated_batch(ROTATION_LIMIT)
    batch2 = get_rotated_batch(ROTATION_LIMIT_2)
    batch_chronological = unique_pool[-ROTATION_LIMIT_3:]

    # --- فیلتر ۱ ساعته برای فایل ۴ ---
    # 3600 ثانیه = ۱ ساعت
    batch_under_1_hour = [item for item in unique_pool if now - float(item[0]) < 3600]

    def save_output(filename, batch):
        with open(filename, 'w', encoding='utf-8') as f:
            for pin in PINNED_CONFIGS: f.write(pin + "\n\n")
            for ts, source_ch, raw_cfg in batch:
                renamed = analyze_and_rename(raw_cfg, source_ch)
                f.write(renamed + "\n\n")

    save_output('configs.txt', batch1)
    save_output('configs2.txt', batch2)
    save_output('configs3.txt', batch_chronological)
    save_output('configs4.txt', batch_under_1_hour)

    with open('data.temp', 'w', encoding='utf-8') as f:
        for item in valid_items: f.write("|".join(item) + "\n")
    
    with open('pointer.txt', 'w', encoding='utf-8') as f:
        new_ptr = (current_index + ROTATION_LIMIT) % pool_size if pool_size > 0 else 0
        f.write(str(new_ptr))

if __name__ == "__main__":
    run()
