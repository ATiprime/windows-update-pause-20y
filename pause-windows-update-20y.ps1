#Requires -Version 5.1
<#
.SYNOPSIS
    一键将 Windows 自动更新「暂停」20 年（Windows 11 / 10，含家庭版 Home）。

.DESCRIPTION
    Windows 没有官方「关闭更新」开关，而家庭版（Home）会忽略组策略，
    也会忽略注册表 HKLM\...\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoUpdate。

    唯一在家庭版上可靠生效的，是「设置」自己写入的暂停时间戳：
        HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings

    本脚本把暂停窗口设为「现在 → 现在 + N 年」，并抬高
    FlightSettingsMaxPauseDays 以突破「Pick a date」日历的 5 周上限。

    完全可逆：
      * 设置 → Windows 更新 → 「恢复更新」，或
      * 运行 restore-updates.ps1

.PARAMETER Years
    暂停年数，默认 20（最大 50）。

.PARAMETER NoDriverUpdates
    同时设置 ExcludeWUDriversInQualityUpdate=1，暂停结束后也不自动推送驱动。

.PARAMETER DryRun
    只显示将要修改的内容，不写注册表，也不需要管理员权限。

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\pause-windows-update-20y.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\pause-windows-update-20y.ps1 -DryRun

.NOTES
    脚本版本 : 1.0.0
    验证日期 : 2026-11-26
    验证环境 : Windows 11 家庭版 25H2 (Build 26200.9711)
    作者     : ATiprime
    仓库     : https://github.com/ATiprime/windows-update-pause-20y
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 50)]
    [int]$Years = 20,

    [switch]$NoDriverUpdates,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# 保证中文在控制台/重定向时都不乱码
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$script:Version    = '1.0.0'
$script:VerifiedOn = '2026-11-26'
$script:TestedEnv  = 'Windows 11 家庭版 25H2 (Build 26200.9711)'

$ux  = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
$pol = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings'

$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$logPath = Join-Path $root 'last-run.log'

function Show-Header {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '   Windows 自动更新：暂停 20 年（一键脚本）' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host "   脚本版本 : $script:Version"
    Write-Host "   验证日期 : $script:VerifiedOn"
    Write-Host "   验证环境 : $script:TestedEnv"
    Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

Show-Header

# ---- 计算目标时间 ---------------------------------------------------------
$fmt     = 'yyyy-MM-ddTHH:mm:ssZ'
$now     = (Get-Date).ToUniversalTime()
$end     = $now.AddYears($Years)
$nowS    = $now.ToString($fmt)
$endS    = $end.ToString($fmt)
$maxDays = [int]($Years * 366)

$plan = [ordered]@{
    'FlightSettingsMaxPauseDays'   = $maxDays
    'PauseUpdatesStartTime'        = $nowS
    'PauseUpdatesExpiryTime'       = $endS
    'PauseFeatureUpdatesStartTime' = $nowS
    'PauseFeatureUpdatesEndTime'   = $endS
    'PauseQualityUpdatesStartTime' = $nowS
    'PauseQualityUpdatesEndTime'   = $endS
}

Write-Host ''
Write-Host "  暂停窗口 : $nowS  ->  $endS  ($maxDays 天)" -ForegroundColor Yellow
Write-Host ''

# ---- 预演模式 -------------------------------------------------------------
if ($DryRun) {
    Write-Host '  [DryRun] 以下内容将被写入，但本次不实际修改：' -ForegroundColor Magenta
    Write-Host ''
    Write-Host "  [$ux]" -ForegroundColor DarkGray
    $plan.GetEnumerator() | ForEach-Object {
        Write-Host ('    {0,-30} = {1}' -f $_.Key, $_.Value)
    }
    Write-Host ''
    Write-Host "  [$pol]" -ForegroundColor DarkGray
    Write-Host '    PausedFeatureStatus            = 1'
    Write-Host '    PausedQualityStatus            = 1'
    Write-Host ''
    Write-Host '  DryRun 结束，未做任何修改。' -ForegroundColor Green
    exit 0
}

# ---- 管理员检查 -----------------------------------------------------------
if (-not (Test-Admin)) {
    Write-Host '  [错误] 需要管理员权限。' -ForegroundColor Red
    Write-Host '         请右键脚本选择「以管理员身份运行」，' -ForegroundColor Red
    Write-Host '         或直接双击 Pause-WindowsUpdate-20Y.cmd。' -ForegroundColor Red
    exit 1
}

try { Start-Transcript -Path $logPath -Force | Out-Null } catch { }

try {
    if (-not (Test-Path $ux)) { throw "缺少注册表键：$ux" }
    if (-not (Test-Path $pol)) { New-Item -Path $pol -Force | Out-Null }

    # ---- 1. 备份当前状态 -------------------------------------------------
    $stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup1 = Join-Path $root "backup-UX-Settings-$stamp.reg"
    $backup2 = Join-Path $root "backup-UpdatePolicy-Settings-$stamp.reg"
    & reg.exe export 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' $backup1 /y | Out-Null
    & reg.exe export 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings' $backup2 /y | Out-Null
    Write-Host "  [1/3] 已备份原值 -> $(Split-Path $backup1 -Leaf)" -ForegroundColor DarkGray

    # ---- 2. 写入暂停窗口 -------------------------------------------------
    Set-ItemProperty -Path $ux -Name 'FlightSettingsMaxPauseDays'   -Value $maxDays -Type DWord
    Set-ItemProperty -Path $ux -Name 'PauseFeatureUpdatesStartTime' -Value $nowS -Type String
    Set-ItemProperty -Path $ux -Name 'PauseFeatureUpdatesEndTime'   -Value $endS -Type String
    Set-ItemProperty -Path $ux -Name 'PauseQualityUpdatesStartTime' -Value $nowS -Type String
    Set-ItemProperty -Path $ux -Name 'PauseQualityUpdatesEndTime'   -Value $endS -Type String
    Set-ItemProperty -Path $ux -Name 'PauseUpdatesStartTime'        -Value $nowS -Type String
    Set-ItemProperty -Path $ux -Name 'PauseUpdatesExpiryTime'       -Value $endS -Type String

    Set-ItemProperty -Path $pol -Name 'PausedFeatureStatus' -Value 1 -Type DWord
    Set-ItemProperty -Path $pol -Name 'PausedQualityStatus' -Value 1 -Type DWord

    if ($NoDriverUpdates) {
        Set-ItemProperty -Path $ux -Name 'ExcludeWUDriversInQualityUpdate' -Value 1 -Type DWord
    }
    Write-Host '  [2/3] 已写入暂停时间戳与状态标志' -ForegroundColor DarkGray

    # ---- 3. 校验 ---------------------------------------------------------
    $check = Get-ItemProperty -Path $ux
    $ok = ($check.PauseUpdatesExpiryTime -eq $endS) -and
          ($check.PauseFeatureUpdatesEndTime -eq $endS) -and
          ($check.PauseQualityUpdatesEndTime -eq $endS)

    Write-Host ''
    Write-Host '  === 校验结果 ===' -ForegroundColor Cyan
    $check | Select-Object FlightSettingsMaxPauseDays,
                          PauseUpdatesStartTime, PauseUpdatesExpiryTime,
                          PauseFeatureUpdatesEndTime, PauseQualityUpdatesEndTime |
        Format-List | Out-String | Write-Host

    Get-ItemProperty -Path $pol | Select-Object PausedFeatureStatus, PausedQualityStatus |
        Format-List | Out-String | Write-Host

    if ($ok) {
        Write-Host '  [3/3] 成功！' -ForegroundColor Green
        Write-Host ''
        Write-Host '  现在打开「设置 → Windows 更新」，应显示：' -ForegroundColor Green
        Write-Host "      「更新已暂停，直到 $($end.ToString('yyyy 年 M 月 d 日'))」" -ForegroundColor Green
        Write-Host '  （若未刷新，关闭设置窗口后重新打开）' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '  恢复方法：设置 → Windows 更新 → 点「恢复更新」' -ForegroundColor DarkGray
        exit 0
    }
    else {
        throw '写入后校验不一致，请查看日志或手动检查注册表。'
    }
}
catch {
    Write-Host ''
    Write-Host "  [失败] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    try { Stop-Transcript | Out-Null } catch { }
}
