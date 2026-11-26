// WindowsUpdatePause20Y.exe
// 一键暂停 / 恢复 Windows 更新（Windows 11 / 10，含家庭版）
//
// 编译（C# 5 / .NET Framework 4.x 自带 csc.exe）：
//   csc.exe /nologo /target:exe /optimize+ /codepage:65001 /out:WindowsUpdatePause20Y.exe Program.cs
//
// 脚本版本 : 1.0.0
// 验证日期 : 2026-11-26
// 验证环境 : Windows 11 家庭版 25H2 (Build 26200.9711)
// 仓库     : https://github.com/ATiprime/windows-update-pause-20y

using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Security.Principal;
using System.Text;
using Microsoft.Win32;

[assembly: System.Reflection.AssemblyTitle("Windows更新暂停工具")]
[assembly: System.Reflection.AssemblyProduct("Windows 更新暂停工具（傻瓜集成式）")]
[assembly: System.Reflection.AssemblyDescription("一键暂停 / 恢复 Windows 更新（Windows 11 / 10，含家庭版）")]
[assembly: System.Reflection.AssemblyCompany("ATiprime")]
[assembly: System.Reflection.AssemblyVersion("1.1.0.0")]
[assembly: System.Reflection.AssemblyFileVersion("1.1.0.0")]
[assembly: System.Reflection.AssemblyInformationalVersion("1.1.0 - 傻瓜集成式 (verified 2026-11-26)")]

internal static class Program
{
    private const string AppName    = "Windows 更新暂停工具";
    private const string Version    = "1.1.0";
    private const string VerifiedOn = "2026-11-26";
    private const string TestedEnv  = "Windows 11 家庭版 25H2 (Build 26200.9711)";
    private const string RepoUrl    = "https://github.com/ATiprime/windows-update-pause-20y";

    private const string UxKey  = @"SOFTWARE\Microsoft\WindowsUpdate\UX\Settings";
    private const string PolKey = @"SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings";

    private const int Years = 20;

    // ------------------------------------------------------------------ main
    private static int Main(string[] args)
    {
        try { Console.Title = AppName + " v" + Version; } catch { }

        // 仅在输出被重定向（写日志）时切到 UTF-8，避免控制台窗口乱码
        try
        {
            if (Console.IsOutputRedirected)
                Console.OutputEncoding = new UTF8Encoding(false);
        }
        catch { }

        try
        {
            if (Has(args, "--help") || Has(args, "-h")) { PrintHelp(); return 0; }

            bool dryRun    = Has(args, "--dry-run");
            bool doPause   = Has(args, "--pause");
            bool doRestore = Has(args, "--restore");

            if (!dryRun && !IsAdmin())
                return Elevate(args);

            Banner();
            ShowCurrentState();

            if (doRestore) return Restore();
            if (doPause)   return PauseUpdate(dryRun);
            if (dryRun)    return PauseUpdate(true);

            return Menu();
        }
        catch (Exception ex)
        {
            Line("");
            Line("  [错误] " + ex.Message, ConsoleColor.Red);
            Pause();
            return 1;
        }
    }

    // ------------------------------------------------------------------ menu
    private static int Menu()
    {
        while (true)
        {
            Console.WriteLine();
            Console.WriteLine("  ------------------------------------------------------------");
            Console.WriteLine("   [1] 暂停更新 20 年（推荐）");
            Console.WriteLine("   [2] 恢复更新");
            Console.WriteLine("   [3] 仅预览，不修改");
            Console.WriteLine("   [0] 退出");
            Console.WriteLine("  ------------------------------------------------------------");
            Console.Write("   请选择 [1]: ");

            string input = Console.ReadLine();
            if (input == null) input = "";
            input = input.Trim();
            if (input.Length == 0) input = "1";

            switch (input)
            {
                case "1": return PauseUpdate(false);
                case "2": return Restore();
                case "3": return PauseUpdate(true);
                case "0": return 0;
                default:
                    Line("   无效输入，请重新选择。", ConsoleColor.Yellow);
                    break;
            }
        }
    }

    // ----------------------------------------------------------------- pause
    private static int PauseUpdate(bool dryRun)
    {
        DateTime now = DateTime.UtcNow;
        DateTime end = now.AddYears(Years);

        string nowS = now.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture);
        string endS = end.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture);
        int maxDays = Years * 366;

        Console.WriteLine();
        Line("   暂停窗口 : " + nowS + "  ->  " + endS + "  (" + maxDays + " 天)", ConsoleColor.Yellow);
        Console.WriteLine();

        if (dryRun)
        {
            Line("   [预览] 以下内容将被写入，本次不修改：", ConsoleColor.Magenta);
            Console.WriteLine();
            Console.WriteLine("     [" + UxKey + "]");
            Console.WriteLine("       FlightSettingsMaxPauseDays     = " + maxDays);
            Console.WriteLine("       PauseUpdatesStartTime          = " + nowS);
            Console.WriteLine("       PauseUpdatesExpiryTime         = " + endS);
            Console.WriteLine("       PauseFeatureUpdatesStartTime   = " + nowS);
            Console.WriteLine("       PauseFeatureUpdatesEndTime     = " + endS);
            Console.WriteLine("       PauseQualityUpdatesStartTime   = " + nowS);
            Console.WriteLine("       PauseQualityUpdatesEndTime     = " + endS);
            Console.WriteLine();
            Console.WriteLine("     [" + PolKey + "]");
            Console.WriteLine("       PausedFeatureStatus            = 1");
            Console.WriteLine("       PausedQualityStatus            = 1");
            Console.WriteLine();
            Line("   预览结束，未做任何修改。", ConsoleColor.Green);
            return 0;
        }

        // ---- 1. 备份 ----
        string backupDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "WindowsUpdatePause20Y");
        Directory.CreateDirectory(backupDir);

        string stamp = DateTime.Now.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture);
        string b1 = Path.Combine(backupDir, "backup-UX-" + stamp + ".reg");
        string b2 = Path.Combine(backupDir, "backup-Policy-" + stamp + ".reg");
        ExportKey(UxKey, b1);
        ExportKey(PolKey, b2);
        Line("   [1/3] 已备份原值 -> " + backupDir, ConsoleColor.DarkGray);

        // ---- 2. 写入 ----
        SetString(UxKey, "PauseFeatureUpdatesStartTime", nowS);
        SetString(UxKey, "PauseFeatureUpdatesEndTime",   endS);
        SetString(UxKey, "PauseQualityUpdatesStartTime", nowS);
        SetString(UxKey, "PauseQualityUpdatesEndTime",   endS);
        SetString(UxKey, "PauseUpdatesStartTime",        nowS);
        SetString(UxKey, "PauseUpdatesExpiryTime",       endS);
        SetDword (UxKey, "FlightSettingsMaxPauseDays",   maxDays);
        SetDword (PolKey, "PausedFeatureStatus",         1);
        SetDword (PolKey, "PausedQualityStatus",         1);
        Line("   [2/3] 已写入暂停时间戳与状态标志", ConsoleColor.DarkGray);

        // ---- 3. 校验 ----
        bool ok = GetString(UxKey, "PauseUpdatesExpiryTime")     == endS
               && GetString(UxKey, "PauseFeatureUpdatesEndTime") == endS
               && GetString(UxKey, "PauseQualityUpdatesEndTime") == endS;

        Console.WriteLine();
        Line("   === 校验结果 ===", ConsoleColor.Cyan);
        Console.WriteLine("     PauseUpdatesExpiryTime      = " + GetString(UxKey, "PauseUpdatesExpiryTime"));
        Console.WriteLine("     PauseFeatureUpdatesEndTime  = " + GetString(UxKey, "PauseFeatureUpdatesEndTime"));
        Console.WriteLine("     PauseQualityUpdatesEndTime  = " + GetString(UxKey, "PauseQualityUpdatesEndTime"));
        Console.WriteLine("     FlightSettingsMaxPauseDays  = " + GetDword (UxKey, "FlightSettingsMaxPauseDays"));
        Console.WriteLine("     PausedFeatureStatus         = " + GetDword (PolKey, "PausedFeatureStatus"));
        Console.WriteLine("     PausedQualityStatus         = " + GetDword (PolKey, "PausedQualityStatus"));
        Console.WriteLine();

        if (!ok)
        {
            Line("   [失败] 写入后校验不一致，请手动检查注册表。", ConsoleColor.Red);
            Pause();
            return 1;
        }

        Line("   [3/3] 成功！", ConsoleColor.Green);
        Console.WriteLine();
        Line("   打开「设置 → Windows 更新」，应显示：", ConsoleColor.Green);
        Line("       「更新已暂停，直到 " + end.ToString("yyyy 年 M 月 d 日", CultureInfo.InvariantCulture) + "」", ConsoleColor.Green);
        Line("   （若未刷新，关闭设置窗口后重新打开）", ConsoleColor.DarkGray);
        Console.WriteLine();
        Line("   恢复方法：本程序选 [2]，或 设置 → Windows 更新 → 恢复更新", ConsoleColor.DarkGray);
        Pause();
        return 0;
    }

    // --------------------------------------------------------------- restore
    private static int Restore()
    {
        string[] names = new string[]
        {
            "FlightSettingsMaxPauseDays",
            "PauseFeatureUpdatesStartTime", "PauseFeatureUpdatesEndTime",
            "PauseQualityUpdatesStartTime", "PauseQualityUpdatesEndTime",
            "PauseUpdatesStartTime",        "PauseUpdatesExpiryTime",
            "ExcludeWUDriversInQualityUpdate"
        };

        foreach (string n in names)
        {
            DeleteValue(UxKey, n);
            Line("   已删除  " + n, ConsoleColor.DarkGray);
        }

        SetDword(PolKey, "PausedFeatureStatus", 0);
        SetDword(PolKey, "PausedQualityStatus", 0);
        Line("   已清除暂停状态标志", ConsoleColor.DarkGray);

        Console.WriteLine();
        Line("   完成。Windows 更新已恢复正常。", ConsoleColor.Green);
        Line("   关闭并重新打开「设置」即可确认。", ConsoleColor.DarkGray);
        Pause();
        return 0;
    }

    // ---------------------------------------------------------------- banner
    private static void Banner()
    {
        Console.WriteLine();
        Line("  ============================================================", ConsoleColor.Cyan);
        Line("    " + AppName + "  v" + Version + "  傻瓜集成式", ConsoleColor.Cyan);
        Line("  ============================================================", ConsoleColor.Cyan);
        Console.WriteLine("    验证日期 : " + VerifiedOn);
        Console.WriteLine("    验证环境 : " + TestedEnv);
        Console.WriteLine("    适用系统 : Windows 11 / 10（含家庭版 Home）");
        Line("  ------------------------------------------------------------", ConsoleColor.DarkGray);
    }

    private static void ShowCurrentState()
    {
        string exp = GetString(UxKey, "PauseUpdatesExpiryTime");
        if (string.IsNullOrEmpty(exp))
            Line("    当前状态 : 未暂停（正常更新）", ConsoleColor.DarkGray);
        else
            Line("    当前状态 : 已暂停至 " + exp, ConsoleColor.DarkGray);
    }

    private static void PrintHelp()
    {
        Console.WriteLine();
        Console.WriteLine("  " + AppName + " v" + Version);
        Console.WriteLine();
        Console.WriteLine("  用法:");
        Console.WriteLine("    WindowsUpdatePause20Y.exe              打开菜单（默认暂停 20 年）");
        Console.WriteLine("    WindowsUpdatePause20Y.exe --pause      直接暂停 20 年");
        Console.WriteLine("    WindowsUpdatePause20Y.exe --restore    恢复更新");
        Console.WriteLine("    WindowsUpdatePause20Y.exe --dry-run    仅预览，不修改");
        Console.WriteLine("    WindowsUpdatePause20Y.exe --help       显示帮助");
        Console.WriteLine();
        Console.WriteLine("  仓库: " + RepoUrl);
    }

    // ----------------------------------------------------------------- utils
    private static bool Has(string[] args, string name)
    {
        for (int i = 0; i < args.Length; i++)
            if (string.Equals(args[i], name, StringComparison.OrdinalIgnoreCase))
                return true;
        return false;
    }

    private static bool IsAdmin()
    {
        using (WindowsIdentity id = WindowsIdentity.GetCurrent())
        {
            WindowsPrincipal p = new WindowsPrincipal(id);
            return p.IsInRole(WindowsBuiltInRole.Administrator);
        }
    }

    private static int Elevate(string[] args)
    {
        try
        {
            string exe = Process.GetCurrentProcess().MainModule.FileName;

            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < args.Length; i++)
            {
                sb.Append('"');
                sb.Append(args[i].Replace("\"", "\\\""));
                sb.Append('"');
                sb.Append(' ');
            }

            ProcessStartInfo psi = new ProcessStartInfo(exe, sb.ToString());
            psi.UseShellExecute = true;
            psi.Verb = "runas";

            Line("");
            Line("   正在请求管理员权限，请在 UAC 弹窗中点「是」...", ConsoleColor.Yellow);

            Process.Start(psi);
            return 0;
        }
        catch (System.ComponentModel.Win32Exception ex)
        {
            Line("");
            if (ex.NativeErrorCode == 1223)
                Line("   已取消管理员授权，操作未执行。", ConsoleColor.Yellow);
            else
                Line("   提权失败：" + ex.Message, ConsoleColor.Red);
            Pause();
            return 1;
        }
    }

    private static void SetString(string subKey, string name, string value)
    {
        using (RegistryKey k = Registry.LocalMachine.CreateSubKey(subKey))
        {
            if (k == null) throw new InvalidOperationException("无法打开注册表键: " + subKey);
            k.SetValue(name, value, RegistryValueKind.String);
        }
    }

    private static void SetDword(string subKey, string name, int value)
    {
        using (RegistryKey k = Registry.LocalMachine.CreateSubKey(subKey))
        {
            if (k == null) throw new InvalidOperationException("无法打开注册表键: " + subKey);
            k.SetValue(name, value, RegistryValueKind.DWord);
        }
    }

    private static string GetString(string subKey, string name)
    {
        using (RegistryKey k = Registry.LocalMachine.OpenSubKey(subKey, false))
        {
            if (k == null) return null;
            object v = k.GetValue(name);
            return v == null ? null : v.ToString();
        }
    }

    private static int GetDword(string subKey, string name)
    {
        using (RegistryKey k = Registry.LocalMachine.OpenSubKey(subKey, false))
        {
            if (k == null) return -1;
            object v = k.GetValue(name);
            if (v == null) return -1;
            return Convert.ToInt32(v, CultureInfo.InvariantCulture);
        }
    }

    private static void DeleteValue(string subKey, string name)
    {
        using (RegistryKey k = Registry.LocalMachine.OpenSubKey(subKey, true))
        {
            if (k != null) k.DeleteValue(name, false);
        }
    }

    private static void ExportKey(string subKey, string file)
    {
        ProcessStartInfo psi = new ProcessStartInfo();
        psi.FileName = "reg.exe";
        psi.Arguments = "export \"HKLM\\" + subKey + "\" \"" + file + "\" /y";
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.RedirectStandardOutput = true;
        psi.RedirectStandardError = true;

        using (Process p = Process.Start(psi))
        {
            if (p != null)
            {
                p.StandardOutput.ReadToEnd();
                p.StandardError.ReadToEnd();
                p.WaitForExit();
            }
        }
    }

    private static void Line(string text)
    {
        Console.WriteLine(text);
    }

    private static void Line(string text, ConsoleColor color)
    {
        ConsoleColor old = Console.ForegroundColor;
        Console.ForegroundColor = color;
        Console.WriteLine(text);
        Console.ForegroundColor = old;
    }

    private static void Pause()
    {
        Console.WriteLine();
        Console.Write("   按任意键退出...");
        try { Console.ReadKey(true); } catch { }
    }
}
