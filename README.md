# Windows 自动更新：一键暂停 20 年

**中文** | [English](README.en.md)

> 专为 **Windows 11 / 10 家庭版（Home）** 设计——家庭版没有组策略，网上一半教程对它无效。
> 双击一个 EXE 或 `.cmd` 就能用，完全可逆。

---

## 📥 下载

### v1.1.0 · 傻瓜集成式（单文件 EXE，推荐）

**➡️ [WindowsUpdatePauseTool.exe](https://github.com/ATiprime/windows-update-pause-20y/releases/latest/download/WindowsUpdatePauseTool.exe)**

- 双击 → UAC 点「是」→ 菜单选 `1`（直接回车也行）
- 自带图标、中文界面，无需 PowerShell、无需解压
- 若直链打不开，请到 **[Release 页面](https://github.com/ATiprime/windows-update-pause-20y/releases/tag/v1.1.0)** 下载

> 想下载后文件名就是中文的 **`Windows更新暂停工具.exe`**？
> 用仓库里的 [中文名副本](https://github.com/ATiprime/windows-update-pause-20y/raw/main/bin/Windows%E6%9B%B4%E6%96%B0%E6%9A%82%E5%81%9C%E5%B7%A5%E5%85%B7.exe)。
> （GitHub 的 Release 资源名会**自动剥离非 ASCII 字符**，`中文.exe` 会变成 `default.exe`，所以 Release 里只能用英文名。）

### v1.0.0 · 脚本版（ZIP）

适合想审计源码、或想用 PowerShell 版的人：**[Release v1.0.0](https://github.com/ATiprime/windows-update-pause-20y/releases/tag/v1.0.0)**

---

## 📦 版本说明

| 版本 | 形式 | 说明 |
| --- | --- | --- |
| **v1.1.0** | 单文件 EXE | **傻瓜集成式**：图标 + 中文菜单，双击即用 |
| v1.0.0 | ZIP 脚本包 | PowerShell + CMD，可审计、可修改 |

---

## ⏳ 有效日期（请先看这个）

| 项目 | 内容 |
| --- | --- |
| **方法实测通过** | **2026-11-26** |
| 测试环境 | Windows 11 家庭版 25H2，Build 26200.9711 |
| 暂停到期日 | **2046-11-26**（= 运行当天 + 20 年） |
| 当前版本 | v1.1.0（傻瓜集成式） |
| 预计可用范围 | 23H2 / 24H2 / 25H2 家庭版；Win10 22H2 家庭版 |
| 失效风险 | 微软后续大版本可能重置或封堵此机制，届时请提 Issue |

> 只要「设置 → Windows 更新」里显示 `已暂停，直到 2046 年`，就说明生效了。

---

## 🚀 用法

### 方式 A：EXE（推荐）

1. 下载 `Windows更新暂停工具.exe`
2. 双击 → UAC 点「是」
3. 菜单选 `1`（直接回车即可）

```
  [1] 暂停更新 20 年（推荐）
  [2] 恢复更新
  [3] 仅预览，不修改
  [0] 退出
```

命令行也支持：

```
Windows更新暂停工具.exe --pause     直接暂停
Windows更新暂停工具.exe --restore   恢复更新
Windows更新暂停工具.exe --dry-run   仅预览
Windows更新暂停工具.exe --help      帮助
```

### 方式 B：脚本

1. 下载 v1.0.0 的 ZIP 并解压
2. 双击 `Pause-WindowsUpdate-20Y.cmd`
3. UAC 点「是」

> **SmartScreen 提示「已保护你的电脑」**：点「更多信息」→「仍要运行」。
> 这是未签名程序的常规提示，源码全部公开可查。

---

## ✅ 怎么确认成功

打开 **设置 → Windows 更新**，应显示：

```
更新已暂停，直到 2046 年
```

若没刷新，关掉设置窗口再打开一次。

命令行验证：

```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' |
  Select-Object PauseUpdatesExpiryTime, PauseFeatureUpdatesEndTime, PauseQualityUpdatesEndTime
```

---

## 🔄 如何恢复（随时可逆）

- **EXE**：菜单选 `[2] 恢复更新`
- **脚本**：双击 `Restore-WindowsUpdate.cmd`
- **系统自带**：设置 → Windows 更新 → 点「**恢复更新**」

EXE 每次运行前会自动备份原值到 `%LOCALAPPDATA%\WindowsUpdatePause20Y\`。

---

## 🧠 原理：为什么不用组策略？

| 方法 | 家庭版是否有效 | 原因 |
| --- | --- | --- |
| 组策略 `gpedit.msc` | ❌ 无效 | 家庭版根本没有；装了也只写文件不生效 |
| `Policies\...\WindowsUpdate\AU\NoAutoUpdate=1` | ❌ 被忽略 | Home 25H2 实测不读取该策略 |
| 禁用 `wuauserv` 服务 | ⚠️ 不可靠 | `WaaSMedicSvc`（更新医疗服务）会自动修复并重新启用 |
| 计量连接 | ⚠️ 只限下载 | 不阻止安装 |
| **修改暂停时间戳** | ✅ **有效** | 这是 Windows 自己实现「暂停更新」用的同一套值 |

「设置」里的暂停功能，本质上就是往
`HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings` 写 6 个时间戳：

| 值 | 含义 |
| --- | --- |
| `PauseUpdatesStartTime` / `PauseUpdatesExpiryTime` | 总暂停窗口 |
| `PauseFeatureUpdatesStartTime` / `PauseFeatureUpdatesEndTime` | 功能更新（大版本）窗口 |
| `PauseQualityUpdatesStartTime` / `PauseQualityUpdatesEndTime` | 质量更新（补丁）窗口 |
| `FlightSettingsMaxPauseDays` | 允许的最大暂停天数，UI 只给 35 天，这里直接放开 |

本工具把窗口设成 `现在 → 现在+20年`，并置
`UpdatePolicy\Settings` 的 `PausedFeatureStatus` / `PausedQualityStatus = 1`，
让更新引擎认为「暂停中」。

> 注意：新版「Pick a date」日历**界面**最多只能选 5 周，所以网上「日历选 20 年」的教程已经失效；直接改时间戳仍然有效。

---

## 📋 适用 / 不适用

**适用**
- Windows 11 家庭版 23H2 / 24H2 / 25H2
- Windows 10 家庭版 22H2
- Pro / Enterprise / Education（同样有效，但这类版本也可用组策略）

**不适用 / 无效**
- Windows 7 / 8.1（机制不同）
- 由公司域或 MDM 接管的设备（策略会覆盖本地设置）
- Windows Insider 预览版（每次「检查更新」可能重置 `FlightSettingsMaxPauseDays`）

---

## ❓ FAQ

**Q：这算「关闭更新」吗？**
算「长期暂停」。更新组件完好，随时能恢复，也不会弄坏系统。

**Q：Defender 病毒库还会更新吗？**
会。病毒库和 Microsoft Store 应用走的是别的通道，不受影响。

**Q：会影响我手动检查更新吗？**
暂停期间「检查更新」按钮通常不可用。想更新就先「恢复更新」。

**Q：大版本升级后会失效吗？**
可能。微软有时会重置这些值，重新跑一次即可。

**Q：为什么不直接禁用服务？**
`WaaSMedicSvc` 是受保护服务，会自愈并把服务重新打开；强行改还可能弄坏更新组件。暂停方案更干净、更可逆。

**Q：EXE 安全吗？**
源码在 [`src/Program.cs`](src/Program.cs)，用系统自带 `csc.exe` 即可自行编译，见下方。

---

## 🛠 自行编译 EXE

```powershell
# 1) 生成图标（可选，已附带 src/app.ico）
powershell -ExecutionPolicy Bypass -File .\tools\make-icon.ps1

# 2) 编译（使用系统自带 .NET Framework 4.x 编译器）
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe `
  /nologo /target:exe /optimize+ /codepage:65001 `
  /win32icon:src\app.ico `
  /out:bin\Windows更新暂停工具.exe `
  src\Program.cs
```

---

## 🗂 文件说明

| 文件 | 作用 |
| --- | --- |
| `bin/Windows更新暂停工具.exe` | **v1.1 傻瓜集成式**，双击即用 |
| `src/Program.cs` | EXE 的 C# 源码 |
| `src/app.ico` | 程序图标（16–256 多尺寸） |
| `tools/make-icon.ps1` | 图标生成脚本 |
| `Pause-WindowsUpdate-20Y.cmd` | v1.0 脚本版：暂停 |
| `Restore-WindowsUpdate.cmd` | v1.0 脚本版：恢复 |
| `pause-windows-update-20y.ps1` | v1.0 主脚本（`-Years` / `-DryRun`） |
| `restore-updates.ps1` | v1.0 恢复脚本 |

---

## 📚 参考

**网页**
- ElevenForum – [Disable Automatic Windows Updates in Windows 11](https://www.elevenforum.com/t/disable-automatic-windows-updates-in-windows-11.22669/)
- MajorGeeks – [Pause or Disable Windows 11 Updates With the New "Pick a Date" Calendar](https://www.majorgeeks.com/content/page/pause_or_disable_windows_11_updates_with_the_new_pick_a_date_calendar.html)
- itechtics – [Windows Home Policy Finder](https://www.itechtics.com/windows-home-policy-finder/)（实测家庭版 `Configure Automatic Updates` = Ignored）
- Microsoft Learn – [Manage additional Windows Update settings](https://learn.microsoft.com/en-us/windows/deployment/update/waas-wu-settings)
- Windows OS Hub – [How to Pause (Delay) Update Installation](https://woshub.com/pause-delay-windows-updates/)

**GitHub**
- [ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil)
- [memstechtips/Winhance](https://github.com/memstechtips/Winhance)
- [dawncopper/WUD](https://github.com/dawncopper/WUD)
- [lunanetdev/lunauctl](https://github.com/lunanetdev/lunauctl)
- [hellzerg/optimizer](https://github.com/hellzerg/optimizer)
- [W4RH4WK/Debloat-Windows-10](https://github.com/W4RH4WK/Debloat-Windows-10)

**其他**
- [Sordum Windows Update Blocker](https://www.sordum.org/9470/windows-update-blocker-v1-8/)

---

## ⚠️ 免责声明

本工具修改的是 Windows 公开的注册表配置项，**可完全撤销**。
但暂停安全更新会使系统暴露于已修补的漏洞风险中。请自行评估并承担使用后果。
作者不对因使用本工具导致的任何数据丢失或系统问题负责。

## 📄 License

[MIT](LICENSE)
