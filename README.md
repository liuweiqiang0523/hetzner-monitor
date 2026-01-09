# 📊 Hetzner-monitor

> 基于 Docker + Python 的全自动流量监控与运维闭环系统。

## 📖 项目背景

Hetzner 的云服务器虽然性价比极高，但其 **20TB 的流量限制**一旦超标，随之而来的高昂账单往往让人肉疼。
为了彻底解决这个问题，我借助 Gemini 开发了这套 **“全自动流量监控系统”**。

## ✨ 主要功能

这套系统不仅仅是一个简单的流量报警器，更是一套**全自动化的运维闭环**：

- **自动化监控**：实时追踪流量使用情况。
- **智能策略**：流量接近阈值时自动执行预设操作。
- **场景适用**：特别适合 **PT 刷流** 或其他高流量消耗的业务场景。

## 📸 运行截图

<img src="https://github.com/user-attachments/assets/e08efc49-d650-4d85-9e83-389f94e59828" width="100%" alt="运行截图">

## 🚀 快速安装 (Quick Start)

为了方便使用，我编写了一键安装脚本，支持主流 Linux 发行版。

### 方式一：一键脚本（推荐）

直接在服务器终端运行以下命令：

```bash
bash <(curl -sL [https://oknm.de/hz](https://oknm.de/hz))

```

脚本会自动执行以下操作：

1. 检测并安装 Docker 环境（如果未安装）。
2. 拉取最新的镜像。
3. 帮助你生成配置文件。
4. 启动监控服务。

### 方式二：Docker Compose 手动部署

如果你喜欢自己掌控一切，也可以使用 `docker-compose` 部署。

1. **下载项目**
```bash
git clone [https://github.com/liuweiqiang0523/hetzner-monitor.git](https://github.com/liuweiqiang0523/hetzner-monitor.git)
cd hetzner-monitor

```


2. **修改配置**
在目录下找到 `config.json` (或 `.env`) 文件，根据你的需求修改参数。
3. **启动容器**
```bash
docker-compose up -d

```

## 💡 进阶技巧：设置快捷命令

觉得每次输入长链接太麻烦？在终端执行这一行命令，以后只需要输入 `hz` 就能唤出管理面板！

```bash
echo "alias hz='bash <(curl -sL [https://oknm.de/hz](https://oknm.de/hz))'" >> ~/.bashrc && source ~/.bashrc

```

以后管理服务器，只需键入：

```bash
hz

```

## ⚙️ 配置说明 (Configuration)

核心配置文件位于 `config/` 目录下，主要参数说明如下：

| 参数项 | 说明 | 默认值/获取方式 |
| --- | --- | --- |
| `HETZNER_TOKEN` | Hetzner API Token | **必填** (控制台获取) |
| `SERVER_ID` | 需要监控的服务器 ID | **必填** (URL中获取) |
| `TRAFFIC_LIMIT` | 流量预警阈值 (单位: TB) | `18` |
| `CHECK_INTERVAL` | 检查间隔时间 (单位: 秒) | `60` |
| `TG_BOT_TOKEN` | (可选) TG 机器人 Token | @BotFather |
| `TG_CHAT_ID` | (可选) TG 推送的用户 ID | @userinfobot |

> 💡 **提示**：为了防止因为流量统计延迟导致超标，建议将阈值设置在 `18TB` - `19TB` 之间，预留缓冲空间。

## 🛠 常用命令

* **查看日志**：
```bash
docker logs -f hetzner-monitor

```


* **重启服务**：
```bash
docker restart hetzner-monitor

```


* **更新脚本/镜像**：
重新运行一键脚本即可自动更新。

## 🤝 贡献与反馈

如果你在使用过程中遇到问题，或者有新的功能建议：

1. 提交 [Issue](https://github.com/liuweiqiang0523/hetzner-monitor/issues) 反馈。
2. 欢迎 Pull Requests 贡献代码。
