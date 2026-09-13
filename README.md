<!-- ═══════════════════════════════════════════════════════════════════════
                         ARGONOV SHELL · README
              Bilingual: English first, Russian second
     ═══════════════════════════════════════════════════════════════════════ -->

<div align="center">

# ⚡ ARGONOV SHELL

**A custom PowerShell 7 shell for Windows 11**

*Fast commands · Git aliases · AI agent · OSINT toolkit · CAD launcher*

![PowerShell](https://img.shields.io/badge/PowerShell-7.6-5391FE?style=flat-square&logo=powershell&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?style=flat-square&logo=windows&logoColor=white)
![Git](https://img.shields.io/badge/Git-SSH-F05032?style=flat-square&logo=git&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Commands](https://img.shields.io/badge/Commands-96-brightgreen?style=flat-square)

[English](#-english) · [Русский](#-русский)

</div>

---

## 📖 Table of Contents

- [✨ Overview](#-overview)
- [🚀 Features](#-features)
- [📋 Requirements](#-requirements)
- [⚙️ Installation](#️-installation)
- [🎯 Quick Start](#-quick-start)
- [📚 Command Reference](#-command-reference)
  - [🗂 Navigation & Files](#-navigation--files)
  - [💻 System](#-system)
  - [🌐 Network](#-network)
  - [🔀 Proxy](#-proxy)
  - [🕵️ OSINT](#️-osint)
  - [🧠 AI](#-ai)
  - [🎛 LM Studio](#-lm-studio)
  - [🌿 Git](#-git)
  - [📸 Screenshots](#-screenshots)
  - [💾 Backup](#-backup)
  - [📐 CAD/CAM](#-cadcam)
  - [🎮 Fun](#-fun)
- [🤖 AI Agent](#-ai-agent)
- [🔒 Safety & Sandbox](#-safety--sandbox)
- [🏗 Architecture](#-architecture)
- [📁 Project Structure](#-project-structure)
- [🔧 Configuration](#-configuration)
- [📝 Coding Conventions](#-coding-conventions)
- [🛠 Tech Stack](#-tech-stack)
- [🗺 Roadmap](#-roadmap)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

---

## ✨ Overview

**ARGONOV SHELL** is a personal shell environment for Windows 11 built on top of **PowerShell 7**. It transforms the default terminal into a comprehensive toolbox for:

- **Development** — Git workflows, file navigation, process management
- **Automation** — batch operations, system info, backups
- **AI assistance** — local LLM agent that can write files, run commands, and edit code
- **OSINT research** — IP geolocation, DNS analysis, port scanning, hash generation
- **Engineering** — CAD/CAM launcher for SolidWorks, AutoCAD, KOMPAS, Mastercam, and more

The shell loads automatically when you open Windows Terminal — no manual setup, no extra tools, just a faster workflow.

> **Status:** Personal project, actively developed. 96 commands across 17 modules.

---

## 🚀 Features

| Feature | Description |
|---|---|
| **⚡ Auto-loading** | Loads profile on every terminal start — no `cd`, no manual trigger |
| **🎨 Custom prompt** | Two-line prompt with path, git branch, time, dirty status |
| **📦 96 commands** | Curated set of aliases, functions, and utilities |
| **🤖 AI agent** | Local LLM (LM Studio) that can write, read, edit, and execute |
| **🕵️ OSINT toolkit** | IP geolocation, DNS, WHOIS, port scan, hash generation |
| **🌐 Proxy manager** | Fetch ~6000 public proxies, test, sort, apply |
| **📸 Screenshots** | Full screen and window capture with auto-organization |
| **💾 Backups** | ZIP archives of the entire shell with one command |
| **📐 CAD launcher** | Auto-detects SolidWorks, AutoCAD, KOMPAS, Mastercam, etc. |
| **🎮 Fun** | Matrix rain with variable speed, CJK charset support |
| **🔒 Sandbox** | AI agent restricted to safe folders, dangerous commands blocked |
| **🌍 Bilingual** | All commands documented in English and Russian |

---

## 📋 Requirements

| Component | Version | Purpose |
|---|---|---|
| **Windows** | 10 or 11 | OS |
| **PowerShell** | 7.6+ | Shell runtime |
| **Git** | Any recent | Repo management |
| **SSH key** | ED25519 | GitHub without password |
| **LM Studio** | Latest | AI backend (optional) |
| **Python** | 3.14 | Scripts and AI integrations (optional) |

> 💡 **Note:** You can use ARGONOV SHELL without LM Studio — everything except `ai` commands works.

---

## ⚙️ Installation

### Option 1 — Clone from GitHub (recommended)

```powershell
# 1. Clone the repo
git clone git@github.com:Andreyfdfd/argonov-windows.git C:\ARGONOV

# 2. Connect to your PowerShell profile
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}
Add-Content -Path $PROFILE -Value '. C:\ARGONOV\profile.ps1' -Encoding UTF8

# 3. Restart Windows Terminal