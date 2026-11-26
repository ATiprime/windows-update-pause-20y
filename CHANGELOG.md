# 更新日志 / Changelog

本项目的所有重要变更都记录在这里。
格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [1.1.1] — 2026-11-26

### 修复

- **非中文区域设置下，控制台中文全部显示为 `????`**
  - 原因：系统 OEM 代码页为 **850 / 437** 等西欧代码页时（典型场景：Windows 界面语言是英文，但用户使用中文），`Console.WriteLine` 会把每个汉字转换成 `?`
  - 实测环境：`OEMCP = 850`、`ACP = 1252`、`UI language = en-IE`
  - 修复：改用 Windows Unicode 控制台 API **`WriteConsoleW`** 直接输出，**完全绕开代码页**
  - 输出被重定向（写日志 / 管道）时改为写 **UTF-8 字节**，日志同样不再乱码
- 已在 **conhost**（双击运行时使用的真实控制台窗口）中截图验证：标题栏、横幅、菜单、日期全部正常显示中文

### 变更

- 版本号 `1.1.0.0` → `1.1.1.0`
- 程序内部版本字符串改为 `1.1.1`

### 产物

| 文件 | 大小 | SHA256 |
| --- | --- | --- |
| `WindowsUpdatePauseTool.exe` | 30,208 字节 | `A8F7FE8F748E10F494855954A58685FF71D8B47287D2BC9718007109BFA4148F` |

---

## [1.1.0] — 2026-11-26

### 新增

- **单文件 EXE（傻瓜集成式）**：`Windows更新暂停工具.exe`
  - 原生 C# 编译（系统自带 `csc.exe`），不依赖 PowerShell、不释放临时文件
  - 自动请求管理员权限（UAC），无需右键「以管理员身份运行」
  - 中文彩色菜单：暂停 20 年 / 恢复更新 / 仅预览 / 退出
  - 写前自动备份到 `%LOCALAPPDATA%\WindowsUpdatePause20Y\`
  - 写后自动校验，失败明确报错
  - 命令行支持：`--pause` / `--restore` / `--dry-run` / `--help`
- **内嵌图标**：蓝色圆角底 + 白色暂停符号，含 16 / 24 / 32 / 48 / 64 / 128 / 256 七种尺寸
- **中文产品名**：文件属性显示「Windows 更新暂停工具（傻瓜集成式）」
- `src/app.ico` 与 `tools/make-icon.ps1`（图标生成脚本）
- **英文说明页** `README.en.md`

### 变更

- `src/Program.cs` 版本号 `1.0.0.0` → `1.1.0.0`
- README 增加版本对照表与 EXE 下载入口

### 已知问题

- 在 OEM 代码页为 850 / 437 的机器上，控制台中文显示为 `????`（已在 1.1.1 修复）

---

## [1.0.0] — 2026-11-26

### 新增

- 首个版本：**PowerShell + CMD 脚本包**
  - `pause-windows-update-20y.ps1`（支持 `-Years` / `-DryRun`）
  - `restore-updates.ps1`
  - `Pause-WindowsUpdate-20Y.cmd` / `Restore-WindowsUpdate.cmd`（双击启动器）
- 通过修改 `HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings` 下的 6 个暂停时间戳实现
  - 同时设置 `FlightSettingsMaxPauseDays = 7320`
  - 设置 `PausedFeatureStatus` / `PausedQualityStatus = 1`
- 实测通过：**Windows 11 家庭版 25H2（Build 26200.9711）**
- 暂停到期：运行当天 + 20 年

---

## 版本对照

| 版本 | 形式 | 状态 |
| --- | --- | --- |
| **1.1.1** | 单文件 EXE | ✅ 当前推荐 |
| 1.1.0 | 单文件 EXE | ⚠️ 中文可能显示为 `????` |
| 1.0.0 | ZIP 脚本包 | ✅ 可用（需 PowerShell） |

## 下载

- 最新版：<https://github.com/ATiprime/windows-update-pause-20y/releases/latest>
- 全部版本：<https://github.com/ATiprime/windows-update-pause-20y/releases>
