```markdown
# 📊 Hetzner-monitor

> 基于 Docker + Python 的全自动流量监控与运维闭环系统。

## 📖 项目背景

Hetzner 的云服务器虽然性价比极高，但其 **20TB 的流量限制**一旦超标，随之而来的高昂账单往往让人肉疼。

为了彻底解决这个问题，我借助 Gemini Pro开发了这套 **“全自动流量监控系统”**。

## ✨ 主要功能

这套系统不仅仅是一个简单的流量报警器，更是一套**全自动化的运维闭环**：

- **自动化监控**：实时追踪 Hetzner 服务器流量使用情况。
- **智能策略**：流量接近阈值时自动执行预设操作（如关机、停止服务等）。
- **场景适用**：特别适合 **PT 刷流** 或其他高流量消耗的业务场景。
- **技术栈**：Docker + Python，轻量且易于部署。

## 📸 运行截图

<img src="https://github.com/user-attachments/assets/e08efc49-d650-4d85-9e83-389f94e59828" width="100%" alt="运行截图">

## 🚀 快速安装 (Quick Start)

为了方便使用，本项目提供了一键安装脚本，支持主流 Linux 发行版。

### ⚡️ 一键脚本（推荐）

直接在服务器终端运行以下命令即可：

```bash
bash <(curl -sL [https://oknm.de/hz](https://oknm.de/hz))

```

脚本会自动执行以下操作：

1. 检测并安装 Docker 环境。
2. 拉取最新镜像。
3. 引导生成配置文件。
4. 启动监控服务。

## ⚙️ 配置说明

安装过程中，你需要提供以下核心信息（也可在生成的配置文件中修改）：

| 参数项 | 说明 | 获取方式 |
| --- | --- | --- |
| `HETZNER_TOKEN` | Hetzner API Token | Hetzner Cloud Console -> Security -> API Tokens |
| `SERVER_ID` | 需要监控的服务器 ID | URL 链接中的数字或 API 获取 |
| `TG_BOT_TOKEN` | (可选) TG 机器人 Token | @BotFather |
| `TG_CHAT_ID` | (可选) TG 用户 ID | @userinfobot |

## ⚠️ 免责声明

1. 本项目的初衷是为了满足作者个人的使用需求。
2. **仅供学习交流使用，严禁用于任何商业用途。**
3. 使用本工具产生的任何后果（包括但不限于数据丢失、服务中断）由使用者自行承担。

```
