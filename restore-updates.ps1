#Requires -Version 5.1
<#
.SYNOPSIS
    恢复 Windows 更新的正常行为（撤销 pause-windows-update-20y.ps1）。

.DESCRIPTION
    删除被脚本加长/改写的暂停值，让 Windows 更新恢复正常。

    其实最简单的方法是：设置 → Windows 更新 → 点「恢复更新」。
    本脚本用于「恢复更新按钮点不动 / 想彻底清干净」的情况。

.NOTES
    脚本版本 : 1.0.0
    验证日期 : 2026-11-26
    作者     : ATiprime
    仓库     : https://github.com/ATiprime/windows-update-pause-20y
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$script:Version    = '1.0.0'
$script:VerifiedOn = '2026-11-26'

$ux  = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
$pol = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings'

$root    = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$logPath = Join-Path $root 'last-run.log'

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '   Windows 更新：恢复默认（撤销 20 年暂停）' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host "   脚本版本 : $script:Version   验证日期 : $script:VerifiedOn"
Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
Write-Host ''

if (-not (Test-Admin)) {
    Write-Host '  [错误] 需要管理员权限。' -ForegroundColor Red
    Write-Host '         请右键选择「以管理员身份运行」，或双击 Restore-WindowsUpdate.cmd。' -ForegroundColor Red
    exit 1
}

try { Start-Transcript -Path $logPath -Force | Out-Null } catch { }

try {
    $names = @(
        'FlightSettingsMaxPauseDays',
        'PauseFeatureUpdatesStartTime', 'PauseFeatureUpdatesEndTime',
        'PauseQualityUpdatesStartTime', 'PauseQualityUpdatesEndTime',
        'PauseUpdatesStartTime',        'PauseUpdatesExpiryTime',
        'ExcludeWUDriversInQualityUpdate'
    )

    foreach ($n in $names) {
        Remove-ItemProperty -Path $ux -Name $n -ErrorAction SilentlyContinue
        Write-Host "  已删除  $n" -ForegroundColor DarkGray
    }

    if (Test-Path $pol) {
        Set-ItemProperty -Path $pol -Name 'PausedFeatureStatus' -Value 0 -Type DWord
        Set-ItemProperty -Path $pol -Name 'PausedQualityStatus' -Value 0 -Type DWord
        Write-Host '  已清除暂停状态标志' -ForegroundColor DarkGray
    }

    Write-Host ''
    Write-Host '  完成。Windows 更新已恢复正常。' -ForegroundColor Green
    Write-Host '  关闭并重新打开「设置」即可确认。' -ForegroundColor DarkGray
    Write-Host ''
    exit 0
}
catch {
    Write-Host "  [失败] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    try { Stop-Transcript | Out-Null } catch { }
}
