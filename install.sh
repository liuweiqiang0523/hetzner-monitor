#!/bin/bash

# ==========================================
# 🚀 Hetzner 流量监控保姆级脚本 (安装+管理)
#    修复版: 解决今日流量显示为0的问题
# ==========================================

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
SKYBLUE='\033[0;36m'
PLAIN='\033[0m'

WORK_DIR="/opt/hetzner_monitor"

# --- 1. 检查 Docker ---
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}未检测到 Docker，正在自动安装...${PLAIN}"
        curl -fsSL https://get.docker.com | bash -s docker
        systemctl enable --now docker
        echo -e "${GREEN}✅ Docker 安装完成${PLAIN}"
    else
        echo -e "${GREEN}✅ 检测到 Docker 已安装${PLAIN}"
    fi
}

# --- 2. 安装/重装逻辑 ---
install_monitor() {
    check_docker
    mkdir -p $WORK_DIR
    cd $WORK_DIR

    echo -e "\n${GREEN}>>> 开始配置监控参数 (请按提示输入):${PLAIN}"

    read -p "1. 请输入 Hetzner API Token: " INPUT_HZ_TOKEN
    read -p "2. 请输入 Telegram Bot Token: " INPUT_TG_TOKEN
    read -p "3. 请输入 Telegram Chat ID: " INPUT_TG_ID

    echo -e "\n${YELLOW}>>> 配置【第 1 台】服务器信息 (例如 QB 下载机):${PLAIN}"
    read -p "   > 服务器名称 (必须与后台一致): " S1_NAME
    read -p "   > 快照 ID (Snapshot ID): " S1_SNAP
    read -p "   > 流量阈值 (TB) [默认 18.0]: " S1_LIMIT
    S1_LIMIT=${S1_LIMIT:-18.0}
    read -p "   > 机房 (nbg1/fsn1/hel1/ash): " S1_LOC
    read -p "   > 机型 (例如 cx22): " S1_TYPE

    echo -e "\n${YELLOW}>>> Cloudflare DDNS 设置:${PLAIN}"
    read -p "   > 是否开启 CF 解析? (y/n): " CF_CHOICE
    if [[ "$CF_CHOICE" == "y" ]]; then
        CF_ENABLE_VAL="True"
        read -p "   > CF API Token: " INPUT_CF_TOKEN
        read -p "   > CF Zone ID: " INPUT_CF_ZONE
        read -p "   > 第1台域名 (如 hz1.com): " S1_DOMAIN
    else
        CF_ENABLE_VAL="False"
        INPUT_CF_TOKEN=""
        INPUT_CF_ZONE=""
        S1_DOMAIN=""
    fi

    echo -e "\n${SKYBLUE}正在生成配置文件...${PLAIN}"

    # 生成 requirements.txt
    cat << EOF > requirements.txt
hcloud
requests
pyTelegramBotAPI
EOF

    # 生成 Dockerfile
    cat << EOF > Dockerfile
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
COPY main.py .
CMD ["python", "-u", "main.py"]
EOF

    # 生成 main.py (包含修正后的时区逻辑)
    cat << EOF > main.py
# -*- coding: utf-8 -*-
import time, threading, telebot, requests
from datetime import datetime, timedelta
from hcloud import Client
from hcloud.images.domain import Image
from hcloud.server_types.domain import ServerType
from hcloud.locations.domain import Location

# === 基础配置 ===
HETZNER_TOKEN = "${INPUT_HZ_TOKEN}"
TG_BOT_TOKEN = "${INPUT_TG_TOKEN}"
TG_CHAT_ID = "${INPUT_TG_ID}"
CF_ENABLE = ${CF_ENABLE_VAL}
CF_API_TOKEN = "${INPUT_CF_TOKEN}"

NOTIFY_LEVELS = [10, 20, 30, 40, 50, 60, 70, 80, 90]
CHECK_INTERVAL = 300
DAILY_REPORT_TIME = "23:55"  # 每日战报时间

# === 服务器列表 ===
SERVERS = [
    {
        "name": "${S1_NAME}",
        "snapshot_id": ${S1_SNAP},
        "location": "${S1_LOC}",
        "type": "${S1_TYPE}",
        "limit_tb": ${S1_LIMIT},
        "cf_zone_id": "${INPUT_CF_ZONE}",
        "cf_domain": "${S1_DOMAIN}"
    },
    # 如需添加第2台，请按下面格式复制并修改:
    # {
    #     "name": "HZ-Server-2",
    #     "snapshot_id": 87654321,
    #     "location": "fsn1",
    #     "type": "cx22",
    #     "limit_tb": 18.0,
    #     "cf_zone_id": "${INPUT_CF_ZONE}",
    #     "cf_domain": "hz2.yourdomain.com"
    # },
]
# =================

client = Client(token=HETZNER_TOKEN)
bot = telebot.TeleBot(TG_BOT_TOKEN)
server_states = {} 
for s in SERVERS: server_states[s['name']] = { "lock": threading.Lock(), "notify_level": 0 }

def update_cloudflare(conf, new_ip):
    if not CF_ENABLE: return "DNS未开启"
    headers = { "Authorization": f"Bearer {CF_API_TOKEN}", "Content-Type": "application/json" }
    try:
        list_url = f"https://api.cloudflare.com/client/v4/zones/{conf['cf_zone_id']}/dns_records?name={conf['cf_domain']}"
        resp = requests.get(list_url, headers=headers).json()
        if not resp.get('success') or not resp['result']: return f"❌ CF记录不存在"
        record_id = resp['result'][0]['id']
        update_url = f"https://api.cloudflare.com/client/v4/zones/{conf['cf_zone_id']}/dns_records/{record_id}"
        data = { "type": "A", "name": conf['cf_domain'], "content": new_ip, "ttl": 60, "proxied": False }
        requests.put(update_url, headers=headers, json=data)
        return f"✅ DNS已更新 -> {new_ip}"
    except Exception as e: return f"❌ DNS异常: {str(e)}"

def get_today_traffic(server):
    """计算今日流量(修正时区版)"""
    try:
        # 获取 UTC 和 北京时间
        now_utc = datetime.utcnow()
        now_bj = now_utc + timedelta(hours=8)
        
        # 算出北京时间“今天0点”对应的 UTC 时间
        start_bj_day = now_bj.replace(hour=0, minute=0, second=0, microsecond=0)
        start_query_utc = start_bj_day - timedelta(hours=8)
        
        # 向 API 查询 (使用 UTC 时间段)
        metrics = server.get_metrics(type="traffic", start=start_query_utc, end=now_utc)
        
        if not metrics or not metrics.time_series: return 0, 0

        def integrate(series):
            total = 0
            if not series or len(series) < 2: return 0
            for i in range(len(series) - 1):
                val = float(series[i][1])
                t_curr = series[i][0]
                t_next = series[i+1][0]
                duration = (t_next - t_curr).total_seconds()
                total += val * duration
            return total

        up = integrate(metrics.time_series.get('traffic.0.out', []))
        down = integrate(metrics.time_series.get('traffic.0.in', []))
        return up, down
    except Exception as e:
        print(f"Metrics Error: {e}")
        return 0, 0

def get_usage(conf, fetch_today=False):
    try:
        server = client.servers.get_by_name(conf['name'])
        if server is None: return None, "服务器不存在"
        current_out = server.outgoing_traffic
        current_in = server.ingoing_traffic
        limit_bytes = conf['limit_tb'] * 1024**4
        percent = (current_out / limit_bytes) * 100
        data = { "name": conf['name'], "tb_out": current_out / 1024**4, "tb_in": current_in / 1024**4, "percent": percent, "ip": server.public_net.ipv4.ip, "today_up": 0, "today_down": 0 }
        if fetch_today:
            up, down = get_today_traffic(server)
            data['today_up'] = up / 1024**3
            data['today_down'] = down / 1024**3
        return current_out, data
    except Exception as e: return None, str(e)

def perform_rebuild(conf, source="自动监控"):
    state = server_states[conf['name']]
    if not state["lock"].acquire(blocking=False): return
    try:
        try:
            server = client.servers.get_by_name(conf['name'])
            if server:
                final_up = server.outgoing_traffic / 1024**4
                final_down = server.ingoing_traffic / 1024**4
                bot.send_message(TG_CHAT_ID, f"🚨 **[{conf['name']}] 流量超标 - 自动销毁启动**\n━━━━━━━━━━━━━━━━\n📉 **最终战报**:\n📤 上传: \`{final_up:.4f} TB\`\n📥 下载: \`{final_down:.4f} TB\`\n⚠️ 正在删机...", parse_mode="Markdown")
                server.delete(); time.sleep(15)
        except: pass
        bot.send_message(TG_CHAT_ID, f"🔄 **[{conf['name']}]** 正在重建...", parse_mode="Markdown")
        new_server = client.servers.create(name=conf['name'], server_type=ServerType(name=conf['type']), image=Image(id=conf['snapshot_id']), location=Location(name=conf['location']))
        new_ip = new_server.server.public_net.ipv4.ip
        state["notify_level"] = 0 
        dns_msg = update_cloudflare(conf, new_ip)
        bot.send_message(TG_CHAT_ID, f"✅ **{conf['name']} 重建完成**\nIP: \`{new_ip}\`\n{dns_msg}", parse_mode="Markdown")
        time.sleep(60)
    except Exception as e: bot.send_message(TG_CHAT_ID, f"❌ {conf['name']} 重建失败: {e}")
    finally: state["lock"].release()

def send_daily_report_logic():
    print("⏰ 发送每日战报...")
    msg = f"📅 **每日定时战报 ({time.strftime('%Y-%m-%d')})**\n"
    for conf in SERVERS:
        u, d = get_usage(conf, fetch_today=True)
        if u is not None: msg += f"━━━━━━━━━━\n🖥️ \`{d['name']}\`\n📤 总上传: \`{d['tb_out']:.4f} TB\` ({d['percent']:.2f}%)\n📥 总下载: \`{d['tb_in']:.4f} TB\`\n📈 **今日新增**: ⬆️ \`{d['today_up']:.2f} GB\` | ⬇️ \`{d['today_down']:.2f} GB\`\n"
        else: msg += f"━━━━━━━━━━\n🖥️ \`{conf['name']}\`\n❌ 获取失败\n"
    bot.send_message(TG_CHAT_ID, msg, parse_mode="Markdown")

def server_monitor_thread(conf):
    print(f"🚀 启动监控: {conf['name']}")
    state = server_states[conf['name']]
    u, d = get_usage(conf)
    if u is not None:
        print(update_cloudflare(conf, d['ip']))
        for l in NOTIFY_LEVELS:
            if d['percent'] >= l: state["notify_level"] = l
    while True:
        try:
            u, d = get_usage(conf)
            if u is not None:
                print(f"[{conf['name']}] {d['percent']:.2f}%")
                for l in NOTIFY_LEVELS:
                    if d['percent'] >= l and l > state["notify_level"]:
                        bot.send_message(TG_CHAT_ID, f"⚠️ **{conf['name']}** 流量提醒: {l}% ({d['tb_out']:.2f} TB)", parse_mode="Markdown")
                        state["notify_level"] = l
                if u > (conf['limit_tb'] * 1024**4): perform_rebuild(conf, "流量超标")
        except: pass
        time.sleep(CHECK_INTERVAL)

def scheduler_thread():
    print(f"⏰ 定时任务: 每天 {DAILY_REPORT_TIME}")
    last_sent_date = None
    while True:
        now = datetime.now()
        if now.strftime("%H:%M") == DAILY_REPORT_TIME and last_sent_date != now.strftime("%Y-%m-%d"):
            try: send_daily_report_logic(); last_sent_date = now.strftime("%Y-%m-%d")
            except: pass
        time.sleep(30)

@bot.message_handler(commands=['start'])
def h(m): bot.reply_to(m, f"🤖 监控运行中\n/ll - 查看战报\n/rebuild 名字 - 强制重建")
@bot.message_handler(commands=['ll', 'status'])
def s(m):
    if str(m.chat.id) != TG_CHAT_ID: return
    bot.send_chat_action(m.chat.id, 'typing'); send_daily_report_logic()
@bot.message_handler(commands=['rebuild'])
def r(m):
    if str(m.chat.id) != TG_CHAT_ID: return
    try:
        t_name = m.text.split()[1]
        t_conf = next((s for s in SERVERS if s['name'] == t_name), None)
        if t_conf: threading.Thread(target=perform_rebuild, args=(t_conf, "手动指令")).start(); bot.reply_to(m, f"执行 {t_name} 重建...")
        else: bot.reply_to(m, "❌ 找不到该服务器")
    except: bot.reply_to(m, "⚠️ 用法: /rebuild 服务器名")

if __name__ == "__main__":
    for c in SERVERS: threading.Thread(target=server_monitor_thread, args=(c,), daemon=True).start()
    threading.Thread(target=scheduler_thread, daemon=True).start()
    print("🤖 Bot 启动...")
    bot.infinity_polling()
EOF

    echo -e "${GREEN}♻️ 构建镜像中...${PLAIN}"
    docker build -t hetzner-bot . > /dev/null 2>&1
    echo -e "${GREEN}🚀 启动容器中...${PLAIN}"
    docker rm -f hetzner-monitor > /dev/null 2>&1
    docker run -d --name hetzner-monitor --restart always hetzner-bot > /dev/null 2>&1
    
    echo -e "\n${GREEN}✅✅✅ 安装成功！监控已在后台运行！ ✅✅✅${PLAIN}"
}

# --- 3. 管理菜单 ---
manage_menu() {
    clear
    echo -e "${GREEN}🚀 Hetzner 监控脚本管理面板${PLAIN}"
    echo -e "${GREEN}-----------------------------${PLAIN}"
    echo -e "1. 查看实时日志 (Ctrl+C 退出)"
    echo -e "2. 修改配置 (添加/删除服务器)"
    echo -e "3. 重启监控"
    echo -e "4. 停止并删除"
    echo -e "-----------------------------"
    echo -e "0. 退出"
    echo ""
    read -p "请输入选项: " choice
    case $choice in
        1)
            docker logs -f hetzner-monitor
            ;;
        2)
            if [ -f "$WORK_DIR/main.py" ]; then
                nano $WORK_DIR/main.py
                echo -e "${YELLOW}配置已修改，正在重建容器...${PLAIN}"
                cd $WORK_DIR
                docker build -t hetzner-bot .
                docker rm -f hetzner-monitor
                docker run -d --name hetzner-monitor --restart always hetzner-bot
                echo -e "${GREEN}✅ 更新成功！${PLAIN}"
            else
                echo -e "${RED}未找到配置文件，请先安装。${PLAIN}"
            fi
            ;;
        3)
            docker restart hetzner-monitor
            echo -e "${GREEN}✅ 已重启${PLAIN}"
            ;;
        4)
            docker rm -f hetzner-monitor
            echo -e "${RED}已停止并删除容器${PLAIN}"
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项${PLAIN}"
            ;;
    esac
}

# --- 4. 主逻辑 ---
if [ -d "$WORK_DIR" ] && docker ps -a | grep -q hetzner-monitor; then
    manage_menu
else
    install_monitor
fi
