# Windows 自动更新：一键暂停 20 年

> 双击一个 `.cmd` 就能用。专为 **Windows 11 / 10 家庭版（Home）** 设计——家庭版没有组策略，网上一半教程对它无效。

---

## ⬇️ 单文件 EXE（最省事）

不想碰脚本？直接下载打包好的 EXE：

**➡️ [WindowsUpdatePause20Y.exe](https://github.com/ATiprime/windows-update-pause-20y/releases/latest/download/WindowsUpdatePause20Y.exe)**

双击 → UAC 点「是」→ 菜单选 `1`（直接回车也行）。

中文菜单包含：

```
[1] 暂停更新 20 年（推荐）
[2] 恢复更新
[3] 仅预览，不修改
[0] 退出
```

> 原生 C# 编译，**不需要 PowerShell、不需要解压、不需要 .NET 额外安装**（Win10/11 自带 .NET Framework 4.x）。
> 未签名，首次运行若提示「已保护你的电脑」，点「更多信息」→「仍要运行」。

---

## ⏳ 有效日期（请先看这个）

| 项目 | 内容 |
| --- | --- |
| **方法实测通过** | **2026-11-26** |
| 测试环境 | Windows 11 家庭版 25H2，Build 26200.9711 |
| 暂停到期日 | **2046-11-26**（= 运行当天 + 20 年） |
| 脚本版本 | v1.0.0 |
| 预计可用范围 | 23H2 / 24H2 / 25H2 家庭版；Win10 22H2 家庭版 |
| 失效风险 | 微软后续大版本可能重置或封堵此机制，届时请提 Issue |

> 只要「设置 → Windows 更新」里显示 `已暂停，直到 2046 年`，就说明生效了。

---

## 🚀 懒人用法（3 步）

1. 下载本仓库（`Code → Download ZIP`），解压到任意文件夹。
2. **双击 `Pause-WindowsUpdate-20Y.cmd`**。
3. 弹出 UAC 授权框时点「**是**」。

完成。全程无需打开注册表，无需命令行。

> **如果 Windows 提示「已保护你的电脑」**（SmartScreen）：
> 点「更多信息」→「仍要运行」。这是未签名脚本的常规提示，源码全部公开可查。

### 只想先看看会改什么？

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\pause-windows-update-20y.ps1 -DryRun
```

`-DryRun` 只打印计划修改的值，**不写注册表、不需要管理员**。

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

**方法一（最简单）**：设置 → Windows 更新 → 点「**恢复更新**」。

**方法二**：双击 `Restore-WindowsUpdate.cmd`（管理员）。

**方法三**：双击运行后生成的 `backup-UX-Settings-*.reg` 备份文件。

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

本脚本把窗口设成 `现在 → 现在+20年`，并置
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
可能。微软有时会重置这些值，重新跑一次脚本即可。

**Q：为什么不直接禁用服务？**
`WaaSMedicSvc` 是受保护服务，会自愈并把服务重新打开；强行改还可能弄坏更新组件。暂停方案更干净、更可逆。

**Q：有风险吗？**
长期不装安全补丁确实有安全风险。建议每半年手动恢复更新装一次，或至少保证 Defender 正常。

---

## 🗂 文件说明

| 文件 | 作用 |
| --- | --- |
| `Pause-WindowsUpdate-20Y.cmd` | **双击这个**，自动提权并暂停 20 年 |
| `Restore-WindowsUpdate.cmd` | 双击这个，恢复更新 |
| `pause-windows-update-20y.ps1` | 主脚本（支持 `-Years`、`-DryRun`、`-NoDriverUpdates`） |
| `restore-updates.ps1` | 恢复脚本 |
| `backup-*.reg` | 首次运行时自动生成的原值备份（不上传仓库） |
| `last-run.log` | 运行日志（不上传仓库） |

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

本脚本修改的是 Windows 公开的注册表配置项，**可完全撤销**。
但暂停安全更新会使系统暴露于已修补的漏洞风险中。请自行评估并承担使用后果。
作者不对因使用本脚本导致的任何数据丢失或系统问题负责。

## 📄 License

[MIT](LICENSE)
