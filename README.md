# personnalMusic · 个人音乐播放器

> 一款轻量、优雅的 iOS 本地音乐播放应用，专为个人收藏打造。

---

## 简介

personnalMusic 是一个原生 iOS 应用，让你以最简洁的方式管理和欣赏本地音乐文件。无需账号、无需网络，所有数据完全存储在设备本地，保护你的隐私。

## 功能特性

- 🎵 **本地音乐播放** — 读取设备本地音频文件，支持主流格式（MP3、FLAC、AAC 等）
- 📋 **播放列表管理** — 查看、排序、清空播放列表，一键切换歌曲
- 🎨 **多主题切换** — 内置多套配色主题，随心定制界面风格
- 🔄 **播放状态同步** — 跨会话记忆上次播放进度，下次打开自动恢复
- 💿 **专辑封面动效** — 旋转唱片动画，增强沉浸感
- ⏩ **完整播放控制** — 进度拖拽、上一首 / 下一首、变速播放

## 技术栈

| 层次 | 技术 |
|------|------|
| UI 框架 | SwiftUI |
| 音频引擎 | AVFoundation |
| 响应式 | Combine |
| 架构模式 | MVVM |
| 最低系统 | iOS 15.0+ |

## 项目结构

```
personnalMusic/
├── personnalMusicApp.swift       # 应用入口
├── ContentView.swift             # 主视图（TabView 布局）
├── Models/
│   ├── Song.swift                # 歌曲数据模型
│   └── MusicSource.swift         # 音乐来源枚举
├── ViewModels/
│   ├── PlayerViewModel.swift     # 播放器状态管理
│   └── LocalMusicViewModel.swift # 本地音乐列表管理
├── Views/
│   ├── AlbumCoverView.swift      # 旋转封面动画
│   ├── LocalMusicView.swift      # 本地音乐浏览页
│   ├── PlaylistView.swift        # 播放列表面板
│   ├── PulsingProgressView.swift # 可拖拽进度条
│   └── ...                       # 其他视图组件
├── Managers/
│   └── LocalMusicManager.swift   # 本地文件读取与缓存
└── Utils/
    ├── ThemeManager.swift         # 主题管理
    ├── SyncManager.swift          # 播放状态持久化
    └── AudioFileManager.swift     # 音频文件工具
```

## 构建与运行

### 前置要求

- macOS 12.0+
- Xcode 14.0+
- iOS 15.0+ 模拟器或真机

### 步骤

```bash
git clone <repo-url>
cd personMusic
open personnalMusic.xcodeproj
```

在 Xcode 中选择目标设备，按 `Cmd + R` 构建运行。

> **注意：** 首次运行需在设备"设置 → 隐私 → 媒体与苹果音乐"中授权访问本地文件。

---

## English

# personnalMusic · Personal Music Player

> A lightweight and elegant iOS app for playing your local music collection.

### Overview

personnalMusic is a native iOS application that lets you manage and enjoy local audio files with minimal friction. No account required, no network needed — all data stays on your device.

### Features

- 🎵 **Local Playback** — Read audio files from on-device storage; supports MP3, FLAC, AAC, and more
- 📋 **Playlist Management** — Browse, reorder, and clear your playlist with ease
- 🎨 **Theme Switching** — Multiple built-in color themes to personalize the interface
- 🔄 **Playback State Sync** — Remembers your last track and position across app launches
- 💿 **Animated Album Cover** — Spinning vinyl disc animation for an immersive feel
- ⏩ **Full Playback Controls** — Seek bar, previous / next track, and playback speed

### Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | SwiftUI |
| Audio Engine | AVFoundation |
| Reactive | Combine |
| Architecture | MVVM |
| Minimum OS | iOS 15.0+ |

### Build & Run

**Requirements:** macOS 12.0+, Xcode 14.0+, iOS 15.0+ device or simulator

```bash
git clone <repo-url>
cd personMusic
open personnalMusic.xcodeproj
```

Select a target device in Xcode and press `Cmd + R` to build and run.

> **Note:** On first launch, grant media library access in **Settings → Privacy → Media & Apple Music**.

### License

MIT
