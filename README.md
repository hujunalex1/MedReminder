# MedReminder

一款轻量的 macOS 菜单栏吃药提醒小工具。

---

## 功能特性

- **菜单栏常驻**：常驻顶部菜单栏，点击即可查看今日用药与打卡，不占 Dock 栏
- **原生质感**：原生毛玻璃背景与系统字体，自适应深色/浅色模式
- **灵活提醒**：支持按时间段（早/中/晚/睡前）或具体时间提醒，支持按天或自定义周期重复
- **快捷打卡**：一键标记服药或跳过，支持漏服补服与误触撤销
- **进度概览**：顶部直观展示待服状态与今日用药进度条
- **系统通知**：到达设定时间发送系统通知提醒与音效提示
- **本地存储**：数据仅保存在本地，无需联网

---

## 系统要求与安装

### 系统要求
- macOS 14.0 (Sonoma) 或更高版本
- Swift 5.9+ / Xcode Command Line Tools

### 编译与运行

1. 克隆代码仓库：
   ```bash
   git clone https://github.com/hujunalex1/MedReminder.git
   cd MedReminder
   ```

2. 编译并直接运行：
   ```bash
   ./build.sh
   ```

3. 编译并安装到系统应用程序目录（`/Applications/`）：
   ```bash
   ./build.sh --install
   ```

4. 打包为 DMG 安装镜像：
   ```bash
   ./build.sh --dmg
   ```

---

## 项目结构

```text
MedReminder/
├── Package.swift               # SwiftPM 配置文件
├── build.sh                    # 一键编译与安装脚本
├── Resources/                  # 应用图标与 Info.plist 资源
│   ├── AppIcon.icns
│   ├── AppIcon.iconset/
│   ├── Info.plist
│   └── *.png
└── Sources/                    # 源代码
    ├── MedReminderApp.swift    # 应用程序入口与菜单栏状态项管理
    ├── ContentView.swift        # 主弹出面板（今日日程、顶栏与进度）
    ├── MedicationRowView.swift  # 单条用药卡片与交互按钮
    ├── AddMedicationView.swift  # 添加/编辑药品视图与快捷规格选择
    ├── AllMedicationsView.swift # 药品管理与维护列表
    ├── MedicationStore.swift    # 业务状态管理与日程计算逻辑
    ├── Models.swift             # 数据模型（Medication, DoseRecord 等）
    ├── DataStore.swift          # 本地 JSON 文件持久化层
    ├── NotificationManager.swift# 本地系统通知调度
    ├── AppleTheme.swift         # 毛玻璃视图包装与 Apple HIG Typography
    └── UnifiedPillIcon.swift    # 统一药丸图标绘制组件
```

---

## 开源许可

[MIT License](LICENSE)
