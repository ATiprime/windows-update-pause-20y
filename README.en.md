# Pause Windows Update for 20 Years

[中文](README.md) | **English**

> Built for **Windows 11 / 10 Home** editions — Home has no Group Policy Editor, and most guides on the internet simply don't work there.
> One double-click. Fully reversible.

---

## 📥 Download

### v1.1.1 · All-in-one (single EXE, recommended)

**➡️ [WindowsUpdatePauseTool.exe](https://github.com/ATiprime/windows-update-pause-20y/releases/latest/download/WindowsUpdatePauseTool.exe)**

- Double-click → click **Yes** on UAC → choose `1` (or just press Enter)
- Ships with an icon and a Chinese UI; no PowerShell, no unzipping
- If the direct link fails, use the **[Releases page](https://github.com/ATiprime/windows-update-pause-20y/releases/tag/v1.1.1)**

> **What did v1.1.1 fix?**
> On machines whose console code page is a Western one (850/437 — e.g. Windows with an English UI
> language but a Chinese locale), every Chinese character used to be printed as `????`.
> v1.1.1 writes through the Unicode console API (`WriteConsoleW`), which **bypasses the code page**,
> so the Chinese UI renders correctly under any regional setting.

> Want the file to download as `Windows更新暂停工具.exe`?
> Use the [Chinese-named copy](https://github.com/ATiprime/windows-update-pause-20y/raw/main/bin/Windows%E6%9B%B4%E6%96%B0%E6%9A%82%E5%81%9C%E5%B7%A5%E5%85%B7.exe).
> (GitHub strips non-ASCII characters from release asset names — `中文.exe` becomes `default.exe` — so the release asset must be ASCII.)

### v1.0.0 · Script bundle (ZIP)

For people who want to audit or tweak the source: **[Release v1.0.0](https://github.com/ATiprime/windows-update-pause-20y/releases/tag/v1.0.0)**

---

## 📦 Versions

| Version | Form | Notes |
| --- | --- | --- |
| **v1.1.1** | Single EXE | **All-in-one**: icon + menu, double-click to run (fixes garbled text on non-Chinese regional settings) |
| v1.1.0 | Single EXE | First EXE release (Chinese showed as `????` on some machines) |
| v1.0.0 | ZIP scripts | PowerShell + CMD, auditable and editable |

---

## ⏳ Validity

| Item | Value |
| --- | --- |
| **Verified on** | **2026-11-26** |
| Tested environment | Windows 11 Home 25H2, Build 26200.9711 |
| Pause expires | **2046-11-26** (run date + 20 years) |
| Current version | v1.1.1 (all-in-one) |
| Expected range | 23H2 / 24H2 / 25H2 Home; Windows 10 22H2 Home |
| Breakage risk | A future Windows feature update may reset or block this method — open an Issue if so |

> If **Settings → Windows Update** says `Paused until 2046`, it worked.

---

## 🚀 Usage

### Option A: the EXE (recommended)

1. Download `WindowsUpdatePauseTool.exe`
2. Double-click → click **Yes** on the UAC prompt
3. Choose `1` (or just press Enter)

```
  [1] Pause updates for 20 years (recommended)
  [2] Restore updates
  [3] Preview only (no changes)
  [0] Exit
```

Command line is supported too:

```
WindowsUpdatePauseTool.exe --pause     pause for 20 years
WindowsUpdatePauseTool.exe --restore   restore normal updates
WindowsUpdatePauseTool.exe --dry-run   preview only
WindowsUpdatePauseTool.exe --help      show help
```

### Option B: the scripts

1. Download the v1.0.0 ZIP and extract it
2. Double-click `Pause-WindowsUpdate-20Y.cmd`
3. Click **Yes** on the UAC prompt

> **SmartScreen says "Windows protected your PC"**: click **More info → Run anyway**.
> That is the normal warning for unsigned binaries; the full source is public.

---

## ✅ Verify it worked

Open **Settings → Windows Update**. It should read:

```
Paused until 2046
```

If it doesn't refresh, close and reopen the Settings window.

Or check the registry:

```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' |
  Select-Object PauseUpdatesExpiryTime, PauseFeatureUpdatesEndTime, PauseQualityUpdatesEndTime
```

---

## 🔄 Restore (always reversible)

- **EXE**: choose `[2] Restore updates`
- **Scripts**: double-click `Restore-WindowsUpdate.cmd`
- **Built-in**: Settings → Windows Update → **Resume updates**

Before every change the EXE exports the original values to `%LOCALAPPDATA%\WindowsUpdatePause20Y\`.

---

## 🧠 Why not Group Policy?

| Method | Works on Home? | Why |
| --- | --- | --- |
| `gpedit.msc` | ❌ No | Not present on Home; installing it only writes a file, nothing is enforced |
| `Policies\...\WindowsUpdate\AU\NoAutoUpdate=1` | ❌ Ignored | Home 25H2 does not read this policy (tested) |
| Disabling the `wuauserv` service | ⚠️ Unreliable | `WaaSMedicSvc` (Update Medic) repairs and re-enables it |
| Metered connection | ⚠️ Download only | Does not block installation |
| **Editing the pause timestamps** | ✅ **Works** | This is exactly what Windows itself writes when you pause |

The "Pause updates" button in Settings is just six timestamps under
`HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings`:

| Value | Meaning |
| --- | --- |
| `PauseUpdatesStartTime` / `PauseUpdatesExpiryTime` | Overall pause window |
| `PauseFeatureUpdatesStartTime` / `PauseFeatureUpdatesEndTime` | Feature (big version) updates |
| `PauseQualityUpdatesStartTime` / `PauseQualityUpdatesEndTime` | Quality (patch) updates |
| `FlightSettingsMaxPauseDays` | Max allowed pause length; the UI caps it at 35 days, so we raise it |

This tool sets the window to `now → now + 20 years` and sets
`PausedFeatureStatus` / `PausedQualityStatus = 1` under `UpdatePolicy\Settings`,
so the update engine treats updates as paused.

> Note: the new "Pick a date" calendar UI only allows 5 weeks, so "pick a date 20 years out" tutorials no longer work — editing the timestamps still does.

---

## 📋 Compatibility

**Works on**
- Windows 11 Home 23H2 / 24H2 / 25H2
- Windows 10 Home 22H2
- Pro / Enterprise / Education (works too, but Group Policy is also available there)

**Does not work on**
- Windows 7 / 8.1 (different mechanism)
- Domain-joined or MDM-managed devices (policy overrides local settings)
- Windows Insider builds (a "Check for updates" may reset `FlightSettingsMaxPauseDays`)

---

## ❓ FAQ

**Is this "turning updates off"?**
It is a long pause. Update components stay intact, it is reversible, and it does not break Windows.

**Will Defender definitions still update?**
Yes. Definitions and Microsoft Store apps use separate channels.

**Can I still check for updates manually?**
The button is usually unavailable while paused. Resume first if you want to update.

**Will a feature update reset it?**
Possibly. Microsoft sometimes resets these values — just run the tool again.

**Why not just disable the services?**
`WaaSMedicSvc` is a protected service that heals itself and re-enables the others; forcing it can break Windows Update. Pausing is cleaner and reversible.

**Is the EXE safe?**
The source is in [`src/Program.cs`](src/Program.cs). You can build it yourself with the compiler bundled with Windows — see below.

---

## 🛠 Build it yourself

```powershell
# 1) Generate the icon (optional, src/app.ico is included)
powershell -ExecutionPolicy Bypass -File .\tools\make-icon.ps1

# 2) Compile with the .NET Framework 4.x compiler that ships with Windows
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe `
  /nologo /target:exe /optimize+ /codepage:65001 `
  /win32icon:src\app.ico `
  /out:bin\WindowsUpdatePauseTool.exe `
  src\Program.cs
```

---

## 🗂 Files

| File | Purpose |
| --- | --- |
| `bin/Windows更新暂停工具.exe` | **v1.1 all-in-one** executable |
| `src/Program.cs` | C# source of the EXE |
| `src/app.ico` | Application icon (16–256 px) |
| `tools/make-icon.ps1` | Icon generator |
| `Pause-WindowsUpdate-20Y.cmd` | v1.0 script: pause |
| `Restore-WindowsUpdate.cmd` | v1.0 script: restore |
| `pause-windows-update-20y.ps1` | v1.0 main script (`-Years` / `-DryRun`) |
| `restore-updates.ps1` | v1.0 restore script |

---

## 📚 References

**Web**
- ElevenForum – [Disable Automatic Windows Updates in Windows 11](https://www.elevenforum.com/t/disable-automatic-windows-updates-in-windows-11.22669/)
- MajorGeeks – [Pause or Disable Windows 11 Updates With the New "Pick a Date" Calendar](https://www.majorgeeks.com/content/page/pause_or_disable_windows_11_updates_with_the_new_pick_a_date_calendar.html)
- itechtics – [Windows Home Policy Finder](https://www.itechtics.com/windows-home-policy-finder/) (Home: `Configure Automatic Updates` = Ignored)
- Microsoft Learn – [Manage additional Windows Update settings](https://learn.microsoft.com/en-us/windows/deployment/update/waas-wu-settings)
- Windows OS Hub – [How to Pause (Delay) Update Installation](https://woshub.com/pause-delay-windows-updates/)

**GitHub**
- [ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil)
- [memstechtips/Winhance](https://github.com/memstechtips/Winhance)
- [dawncopper/WUD](https://github.com/dawncopper/WUD)
- [lunanetdev/lunauctl](https://github.com/lunanetdev/lunauctl)
- [hellzerg/optimizer](https://github.com/hellzerg/optimizer)
- [W4RH4WK/Debloat-Windows-10](https://github.com/W4RH4WK/Debloat-Windows-10)

**Other**
- [Sordum Windows Update Blocker](https://www.sordum.org/9470/windows-update-blocker-v1-8/)

---

## ⚠️ Disclaimer

This tool only modifies documented Windows registry values and is fully reversible.
However, pausing security updates exposes your system to already-patched vulnerabilities.
Use at your own risk. The author is not responsible for any data loss or system issues.

## 📄 License

[MIT](LICENSE)
