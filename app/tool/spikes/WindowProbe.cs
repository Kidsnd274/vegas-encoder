// Window spikes for the Flutter runner (WORKSTREAMS F0; TECH_ARCHITECTURE §9.3, §9.4).
//
// A stand-in for VEGAS: a WinForms window plays the host (the render dialog or
// the Custom Template dialog), made foreground by one real mouse click, and
// launches VegasEncoder.exe the way the exporter will. Nothing here touches
// VEGAS; results describe the app's window behaviour against a fake host.
//
// Usage: WindowProbe.exe <VegasEncoder.exe> <outDir> [start|owner|monitor|theme|all] [runs]
//        WindowProbe.exe <VegasEncoder.exe> <outDir> shot <name.png> <skia|impeller|-> [app arguments...]
// Build: see run_window_spikes.ps1.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

static class Native
{
    public delegate bool EnumProc(IntPtr hwnd, IntPtr lparam);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; public int Width => Right - Left; public int Height => Bottom - Top; public override string ToString() => $"({Left},{Top}) {Width}x{Height}"; }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X, Y; }

    [StructLayout(LayoutKind.Sequential)]
    public struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }

    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc proc, IntPtr lparam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd, StringBuilder name, int max);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr hwnd, uint cmd);
    [DllImport("user32.dll")] public static extern IntPtr GetWindowLongPtr(IntPtr hwnd, int index);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hwnd, int attribute, out RECT rect, int size);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, uint msg, IntPtr wparam, IntPtr lparam);
    [DllImport("user32.dll")] public static extern bool EnableWindow(IntPtr hwnd, bool enable);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int cmd);
    [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
    [DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT point);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extra);
    [DllImport("user32.dll")] public static extern IntPtr GetFocus();

    public const uint GW_OWNER = 4;
    public const int GWL_EXSTYLE = -20;
    public const long WS_EX_TOPMOST = 0x8;
    public const long WS_EX_NOACTIVATE = 0x08000000;
    public const uint WM_CLOSE = 0x0010;
    public const int SW_MINIMIZE = 6;
    public const int SW_RESTORE = 9;
    public const int DWMWA_EXTENDED_FRAME_BOUNDS = 9;
    public const uint MONITOR_DEFAULTTONEAREST = 2;
    public const uint MOUSEEVENTF_LEFTDOWN = 0x2, MOUSEEVENTF_LEFTUP = 0x4;
}

/// The fake host window, on its own UI thread.
sealed class FakeHost : IDisposable
{
    readonly Thread _thread;
    Form _form;
    public IntPtr Handle { get; private set; }

    public FakeHost(string title, Rectangle bounds)
    {
        var ready = new ManualResetEventSlim();
        _thread = new Thread(() =>
        {
            _form = new Form { Text = title, StartPosition = FormStartPosition.Manual, Bounds = bounds, BackColor = Color.FromArgb(38, 38, 38), ShowInTaskbar = true };
            _form.Load += (s, e) => { Handle = _form.Handle; ready.Set(); };
            Application.Run(_form);
        });
        _thread.SetApartmentState(ApartmentState.STA);
        _thread.IsBackground = true;
        _thread.Start();
        ready.Wait(5000);
        Thread.Sleep(300);
    }

    /// A real click in the window, as a user would, so it becomes foreground.
    public bool Activate()
    {
        Native.GetWindowRect(Handle, out var r);
        Native.GetCursorPos(out var saved);
        Native.SetCursorPos(r.Left + r.Width / 2, r.Top + r.Height / 2);
        Native.mouse_event(Native.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        Native.mouse_event(Native.MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
        Thread.Sleep(250);
        Native.SetCursorPos(saved.X, saved.Y);
        return Native.GetForegroundWindow() == Handle;
    }

    public void Dispose()
    {
        try { _form?.Invoke(new Action(() => _form.Close())); } catch { }
        _thread.Join(2000);
    }
}

static class Probe
{
    static string _exe, _out;
    static readonly List<string> Report = new List<string>();

    static void Log(string line) { Console.WriteLine(line); Report.Add(line); }

    static int Main(string[] args)
    {
        Native.SetProcessDpiAwarenessContext(new IntPtr(-4)); // per-monitor v2: physical pixels
        if (args.Length < 2) { Console.WriteLine("Usage: WindowProbe.exe <VegasEncoder.exe> <outDir> [start|owner|monitor|theme|all] [runs]"); return 2; }
        _exe = Path.GetFullPath(args[0]);
        _out = Path.GetFullPath(args[1]);
        Directory.CreateDirectory(_out);
        var what = args.Length > 2 ? args[2] : "all";
        if (what == "shot")
        {
            // shot <name.png> [renderer] [app arguments...]: capture one window for review.
            var env = new Dictionary<string, string>();
            if (args.Length > 4 && args[4] != "-") env["VEGAS_ENCODER_RENDERER"] = args[4];
            var p = Launch(string.Join(" ", args.Skip(5).Select(a => a.Contains(" ") ? "\"" + a + "\"" : a)), env);
            var h = FindAppWindow(p.Id);
            Thread.Sleep(1500);
            Save(h, args[3]);
            CloseAndWait(p, h);
            return 0;
        }
        var runs = args.Length > 3 ? int.Parse(args[3]) : 10;
        Log($"exe {_exe}");
        Log($"exe version {FileVersionInfo.GetVersionInfo(_exe).FileVersion}, size {new FileInfo(_exe).Length}, modified {File.GetLastWriteTime(_exe):s}");
        Log($"windows {Environment.OSVersion.Version}");
        try
        {
            if (what == "start" || what == "all") StartTime(runs);
            if (what == "owner" || what == "all") Owner();
            if (what == "monitor" || what == "all") Monitor();
            if (what == "theme" || what == "all") Theme();
        }
        finally
        {
            File.WriteAllLines(Path.Combine(_out, "window-spikes.txt"), Report);
        }
        return 0;
    }

    // ------------------------------------------------------------ helpers

    static IntPtr FindAppWindow(int pid, int timeoutMs = 10000)
    {
        var sw = Stopwatch.StartNew();
        while (sw.ElapsedMilliseconds < timeoutMs)
        {
            IntPtr found = IntPtr.Zero;
            Native.EnumWindows((h, l) =>
            {
                Native.GetWindowThreadProcessId(h, out var p);
                if (p != pid || !Native.IsWindowVisible(h)) return true;
                var cls = new StringBuilder(64);
                Native.GetClassName(h, cls, 64);
                if (cls.ToString() != "VEGAS_ENCODER_WINDOW") return true;
                found = h;
                return false;
            }, IntPtr.Zero);
            if (found != IntPtr.Zero) return found;
            Thread.Sleep(10);
        }
        return IntPtr.Zero;
    }

    static Native.RECT Visible(IntPtr hwnd)
    {
        Native.DwmGetWindowAttribute(hwnd, Native.DWMWA_EXTENDED_FRAME_BOUNDS, out var r, Marshal.SizeOf(typeof(Native.RECT)));
        return r;
    }

    static Native.RECT WorkArea(IntPtr hwnd)
    {
        var info = new Native.MONITORINFO { cbSize = Marshal.SizeOf(typeof(Native.MONITORINFO)) };
        Native.GetMonitorInfo(Native.MonitorFromWindow(hwnd, Native.MONITOR_DEFAULTTONEAREST), ref info);
        return info.rcWork;
    }

    static Bitmap Capture(Native.RECT r)
    {
        var bmp = new Bitmap(r.Width, r.Height, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(bmp)) g.CopyFromScreen(r.Left, r.Top, 0, 0, new Size(r.Width, r.Height));
        return bmp;
    }

    static void Save(IntPtr hwnd, string name, int margin = 0)
    {
        var r = Visible(hwnd);
        r.Left -= margin; r.Top -= margin; r.Right += margin; r.Bottom += margin;
        using (var bmp = Capture(r)) bmp.Save(Path.Combine(_out, name), ImageFormat.Png);
    }

    static Process Launch(string arguments, Dictionary<string, string> env = null)
    {
        var info = new ProcessStartInfo(_exe, arguments) { UseShellExecute = false, WorkingDirectory = Path.GetDirectoryName(_exe) };
        if (env != null) foreach (var kv in env) info.EnvironmentVariables[kv.Key] = kv.Value;
        return Process.Start(info);
    }

    static bool CloseAndWait(Process p, IntPtr hwnd, int timeoutMs = 5000)
    {
        if (hwnd != IntPtr.Zero) Native.PostMessage(hwnd, Native.WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
        if (p.WaitForExit(timeoutMs)) return true;
        p.Kill();
        p.WaitForExit();
        return false;
    }

    static string Yes(bool b) => b ? "yes" : "NO";

    // ------------------------------------------------------------ start time

    static void StartTime(int runs)
    {
        Log("");
        Log("== start time: ms from process creation (startup trace), medians ==");
        var stages = new[] { "runner_entry", "window_created", "dart_main", "dart_first_frame", "first_frame", "shown" };
        foreach (var renderer in new[] { "skia", "impeller" })
        foreach (var mode in new[] { "desktop", "popup" })
        {
            var runsMarks = new List<Dictionary<string, double>>();
            for (var i = 0; i < runs; i++)
            {
                var trace = Path.Combine(_out, $"trace-{renderer}-{mode}-{i}.txt");
                File.Delete(trace);
                var sessionDir = Path.Combine(_out, "session");
                Directory.CreateDirectory(sessionDir);
                var env = new Dictionary<string, string> { { "VEGAS_ENCODER_STARTUP_TRACE", trace } };
                env["VEGAS_ENCODER_RENDERER"] = renderer;
                var p = Launch(mode == "desktop" ? "" : $"--edit-session \"{sessionDir}\"", env);
                var hwnd = FindAppWindow(p.Id);
                var sw = Stopwatch.StartNew();
                string[] lines = new string[0];
                while (sw.ElapsedMilliseconds < 5000)
                {
                    try { lines = File.ReadAllLines(trace); } catch (IOException) { }
                    if (lines.Any(l => l.EndsWith(" shown")) && lines.Any(l => l.EndsWith(" dart_first_frame"))) break;
                    Thread.Sleep(20);
                }
                var marks = new Dictionary<string, double>();
                foreach (var f in lines.Select(l => l.Split(new[] { ' ' }, 3)).Where(f => f.Length == 3))
                    marks[f[2]] = double.Parse(f[1], CultureInfo.InvariantCulture);
                runsMarks.Add(marks);
                Thread.Sleep(300);
                CloseAndWait(p, hwnd);
                Thread.Sleep(300);
            }
            string Median(string stage)
            {
                var v = runsMarks.Where(m => m.ContainsKey(stage)).Select(m => m[stage]).OrderBy(x => x).ToList();
                return v.Count == 0 ? "-" : $"{v[v.Count / 2]:0}";
            }
            var shown = runsMarks.Where(m => m.ContainsKey("shown")).Select(m => m["shown"]).ToList();
            Log($"{renderer,-8} {mode,-8} " + string.Join("  ", stages.Select(st => $"{st} {Median(st)}")) +
                (shown.Count > 0 ? $"  | shown first run {shown[0]:0}, min {shown.Min():0}, max {shown.Max():0} ({shown.Count} runs)" : ""));
        }
    }

    // ------------------------------------------------------------ owner window

    static void Owner()
    {
        Log("");
        Log("== owner window: --edit-session with --owner <hwnd> over a fake Custom Template dialog ==");
        using (var host = new FakeHost("Fake VEGAS Custom Settings", new Rectangle(300, 200, 1280, 820)))
        {
            Log($"fake owner foreground after click: {Yes(host.Activate())}");
            var sessionDir = Path.Combine(_out, "session");
            Directory.CreateDirectory(sessionDir);

            // As the native page will: disable the owner, then start the editor.
            Native.EnableWindow(host.Handle, false);
            var sw = Stopwatch.StartNew();
            var ownerTrace = Path.Combine(_out, "trace-owner.txt");
            File.Delete(ownerTrace);
            var p = Launch($"--edit-session \"{sessionDir}\" --owner {host.Handle.ToInt64()}",
                new Dictionary<string, string> { { "VEGAS_ENCODER_STARTUP_TRACE", ownerTrace } });
            var editor = FindAppWindow(p.Id);
            Log($"editor visible after {sw.ElapsedMilliseconds} ms (wall clock from launch)");
            Thread.Sleep(600);
            foreach (var line in File.ReadAllLines(ownerTrace)) Log("  trace: " + line);
            Native.GetWindowRect(editor, out var raw);
            Log($"editor window rect {raw}");

            var owner = Native.GetWindow(editor, Native.GW_OWNER);
            Log($"owner set (GW_OWNER is the fake dialog): {Yes(owner == host.Handle)}");
            Native.GetWindowRect(host.Handle, out var o);
            var e = Visible(editor);
            int dx = (e.Left + e.Right) / 2 - (o.Left + o.Right) / 2, dy = (e.Top + e.Bottom) / 2 - (o.Top + o.Bottom) / 2;
            Log($"owner {o}, editor visible bounds {e}, centre offset ({dx},{dy}) px");
            Log($"editor is foreground: {Yes(Native.GetForegroundWindow() == editor)}");
            Save(editor, "owner-popup.png", 24);

            Native.ShowWindow(host.Handle, Native.SW_MINIMIZE);
            Thread.Sleep(500);
            Log($"editor hidden while owner minimized: {Yes(!Native.IsWindowVisible(editor))}");
            Native.ShowWindow(host.Handle, Native.SW_RESTORE);
            Thread.Sleep(500);
            Log($"editor visible again after owner restored: {Yes(Native.IsWindowVisible(editor))}");

            Native.SetForegroundWindow(editor);
            Thread.Sleep(200);
            var exited = CloseAndWait(p, editor);
            Thread.Sleep(400);
            Log($"editor exited on WM_CLOSE: {Yes(exited)}");
            Log($"owner re-enabled by the editor before closing: {Yes(Native.IsWindowEnabled(host.Handle))}");
            Log($"owner is foreground after the editor closed: {Yes(Native.GetForegroundWindow() == host.Handle)}");

            // Crash: the editor dies with the owner still disabled.
            host.Activate();
            Native.EnableWindow(host.Handle, false);
            p = Launch($"--edit-session \"{sessionDir}\" --owner {host.Handle.ToInt64()}");
            editor = FindAppWindow(p.Id);
            Thread.Sleep(600);
            p.Kill();
            p.WaitForExit();
            Thread.Sleep(300);
            var fgAfterKill = Native.GetForegroundWindow();
            Native.EnableWindow(host.Handle, true); // the page re-enables on process exit
            Thread.Sleep(200);
            Log($"crash: foreground right after kill is the owner: {Yes(fgAfterKill == host.Handle)}");
            var regained = Native.SetForegroundWindow(host.Handle);
            Thread.Sleep(200);
            Log($"crash: owner process can take foreground back after re-enabling: {Yes(regained && Native.GetForegroundWindow() == host.Handle)}");
        }
    }

    // ------------------------------------------------------------ no-activate progress window

    static void Monitor()
    {
        Log("");
        Log("== no-activate window: --render-monitor over a fake VEGAS main window ==");
        using (var host = new FakeHost("Fake VEGAS Pro", new Rectangle(200, 150, 1400, 900)))
        {
            Log($"fake VEGAS foreground after click: {Yes(host.Activate())}");
            var live = Path.Combine(_out, "render.live.json");
            var p = Launch($"--render-monitor \"{live}\"");
            var mon = FindAppWindow(p.Id);
            Thread.Sleep(800);
            var fg = Native.GetForegroundWindow();
            Log($"progress window visible: {Yes(mon != IntPtr.Zero && Native.IsWindowVisible(mon))}");
            Log($"VEGAS still foreground after the window showed: {Yes(fg == host.Handle)}");
            var ex = Native.GetWindowLongPtr(mon, Native.GWL_EXSTYLE).ToInt64();
            Log($"WS_EX_NOACTIVATE: {Yes((ex & Native.WS_EX_NOACTIVATE) != 0)}, topmost (keep on top): {Yes((ex & Native.WS_EX_TOPMOST) != 0)}");
            var r = Visible(mon);
            var work = WorkArea(host.Handle);
            Log($"progress window {r}; work area of VEGAS's monitor {work}; gap right {work.Right - r.Right}, bottom {work.Bottom - r.Bottom} px");
            Save(mon, "monitor-window.png", 24);

            // A click on the progress window body must not activate it.
            Native.GetCursorPos(out var saved);
            Native.SetCursorPos(r.Left + r.Width / 2, r.Top + r.Height / 2);
            Native.mouse_event(Native.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
            Native.mouse_event(Native.MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
            Thread.Sleep(300);
            Native.SetCursorPos(saved.X, saved.Y);
            Log($"VEGAS still foreground after a click on the progress window: {Yes(Native.GetForegroundWindow() == host.Handle)}");
            CloseAndWait(p, mon);
        }
    }

    // ------------------------------------------------------------ live theme

    static bool IsDark(IntPtr hwnd)
    {
        // Sample the gallery background below the title bar.
        var r = Visible(hwnd);
        using (var bmp = Capture(new Native.RECT { Left = r.Left + 200, Top = r.Top + 400, Right = r.Left + 201, Bottom = r.Top + 401 }))
        {
            var c = bmp.GetPixel(0, 0);
            return (c.R + c.G + c.B) / 3 < 128;
        }
    }

    static void Theme()
    {
        Log("");
        Log("== live theme: flip HKCU AppsUseLightTheme while the desktop app runs ==");
        const string key = @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize";
        var original = (int)Registry.CurrentUser.OpenSubKey(key).GetValue("AppsUseLightTheme", 1);
        var p = Launch("");
        var hwnd = FindAppWindow(p.Id);
        Thread.Sleep(1000);
        try
        {
            var start = IsDark(hwnd);
            Log($"Windows app mode {(original == 0 ? "dark" : "light")}; app renders dark: {Yes(start == (original == 0))}");
            Save(hwnd, original == 0 ? "theme-dark.png" : "theme-light.png");
            using (var k = Registry.CurrentUser.OpenSubKey(key, true)) k.SetValue("AppsUseLightTheme", original == 0 ? 1 : 0, RegistryValueKind.DWord);
            var sw = Stopwatch.StartNew();
            while (IsDark(hwnd) == start && sw.ElapsedMilliseconds < 3000) Thread.Sleep(20);
            var flipped = IsDark(hwnd) != start;
            Log($"app followed the change live: {Yes(flipped)} after {sw.ElapsedMilliseconds} ms (includes the 200 ms theme animation)");
            Thread.Sleep(400);
            Save(hwnd, original == 0 ? "theme-light.png" : "theme-dark.png");
        }
        finally
        {
            using (var k = Registry.CurrentUser.OpenSubKey(key, true)) k.SetValue("AppsUseLightTheme", original, RegistryValueKind.DWord);
        }
        var sw2 = Stopwatch.StartNew();
        while (IsDark(hwnd) != (original == 0) && sw2.ElapsedMilliseconds < 3000) Thread.Sleep(20);
        Log($"restored AppsUseLightTheme={original}; app followed back: {Yes(IsDark(hwnd) == (original == 0))}");
        CloseAndWait(p, hwnd);
    }
}
