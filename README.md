# MedReminder (今日用药 / 吃药提醒)

精致、轻量的原生 macOS 菜单栏吃药提醒小助手，基于 **SwiftUI** 与 Apple 原生 **Liquid Glass** 毛玻璃质感打造。

---

## ✨ 核心特性

- 🍎 **原生菜单栏常驻**：极简菜单栏图标，点击快速弹出今日用药浮层，不挤占 Dock 栏空间。
- 🪟 **Liquid Glass 毛玻璃美学**：
  - 底层基于原生 `NSVisualEffectView(.popover)` 动态振动层，随系统壁纸自适应光影；
  - 遵循标准 Apple HIG 字体与色彩规范，告别生硬纯色块。
- 💊 **灵活日程规划**：
  - 支持按预设时段（早晨、中午、晚上、睡前）或自定义具体时间（如 08:30）；
  - 支持每天服药或按周期服药，内置常用规格/剂量快速填充胶囊。
- ⚡️ **丝滑快捷交互**：
  - 双胶囊按钮组：`[✓ 服药]` 与 `[跳过]`；
  - 容错机制：支持漏服/跳过后的「补服」，以及误触后的「撤销已服」。
- 📊 **动态日程与进度追踪**：
  - 顶栏实时感知待服状态（如 `9月17日 星期四 · 2 剂待服` / `全部已服完 ✨`）；
  - 配备 Apple 规格动态进度条与完成比例。
- 🔔 **系统通知与声音**：准时系统横幅推送与操作音效反馈。
- 🔒 **纯本地隐私保护**：所有药品及打卡数据保存在本地 `~/Library/Application Support/MedReminder/`，无网络请求、无隐私泄露风险。

---

## 🛠️ 系统要求与安装

### 系统要求
- macOS 14.0 (Sonoma) 或更高版本
- Swift 5.9+ / Xcode Command Line Tools

### 编译与运行

1. 克隆代码仓库：
   ```bash
   git clone https://github.com/<your-username>/MedReminder.git
   cd MedReminder
   ```

2. 编译并直接运行：
   ```bash
   ./build.sh
   ```

3. 编译并一键安装到系统应用程序目录（`/Applications/`）：
   ```bash
   ./build.sh --install
   ```

---

## 📂 项目结构

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

## 📄 开源许可

[MIT License](LICENSE)
