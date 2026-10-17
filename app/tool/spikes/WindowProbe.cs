// Window spikes for the Flutter runner (WORKSTREAMS F0; TECH_ARCHITECTURE §9.3, §9.4).
//
// A stand-in for VEGAS: a WinForms window plays the host (the render dialog or
// the Custom Template dialog), made foreground by one real mouse click, and
// launches VegasEncoder.exe the way the exporter will. Nothing here touches
// VEGAS; results describe the app's window behaviour against a fake host.
//
// Usage: WindowProbe.exe <VegasEncoder.exe> <outDir> [start|owner|close|monitor|theme|all] [runs]
//        WindowProbe.exe <VegasEncoder.exe> <outDir> shot <name.png> <skia|impeller|-> [app arguments...]
// Build: see run_window_spikes.ps1.
//
// Popups get a session directory with the C4 request the exporter's page will
// write: the platform fixture (VE_SPIKE_REQUEST, schema/fixtures/b0/request.json)
// with ownerHwnd set to the fake host. The app reads it through its real
// FileEditSessionService, so a WM_CLOSE with nothing changed leaves a cancel
// result.json. VEGAS_ENCODER_DATA_ROOT (set by run_window_spikes.ps1) keeps
// settings and the library out of the user's %APPDATA%.

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
using System.Text.RegularExpressions;
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

    [StructLayout(LayoutKind.Sequential)]
    public struct COPYDATASTRUCT { public UIntPtr dwData; public uint cbData; public IntPtr lpData; }

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
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint message, IntPtr wparam, ref COPYDATASTRUCT data, uint flags, uint timeout, out UIntPtr result);
    [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
    [DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT point);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extra);
    [DllImport("user32.dll")] public static extern IntPtr GetFocus();
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hwnd);
    [DllImport("shcore.dll")] public static extern int GetDpiForMonitor(IntPtr monitor, int type, out uint dpiX, out uint dpiY);
    public delegate bool MonitorProc(IntPtr monitor, IntPtr dc, ref RECT rect, IntPtr data);
    [DllImport("user32.dll")] public static extern bool EnumDisplayMonitors(IntPtr dc, IntPtr clip, MonitorProc proc, IntPtr data);

    public const uint GW_OWNER = 4;
    public const int GWL_EXSTYLE = -20;
    public const long WS_EX_TOPMOST = 0x8;
    public const long WS_EX_NOACTIVATE = 0x08000000;
    public const uint WM_CLOSE = 0x0010;
    public const int SW_MINIMIZE = 6;
    public const int SW_RESTORE = 9;
    public const int DWMWA_EXTENDED_FRAME_BOUNDS = 9;
    public const uint MONITOR_DEFAULTTONEAREST = 2;
    public const uint MONITORINFOF_PRIMARY = 1;
    public const int MDT_EFFECTIVE_DPI = 0;
    public const uint MOUSEEVENTF_LEFTDOWN = 0x2, MOUSEEVENTF_LEFTUP = 0x4;
}

/// The fake host window, on its own UI thread.
sealed class FakeHost : IDisposable
{
    readonly Thread _thread;
    Form _form;
    public IntPtr Handle { get; private set; }

    public FakeHost(string title, Rectangle bounds, bool fullScreen = false)
    {
        var ready = new ManualResetEventSlim();
        _thread = new Thread(() =>
        {
            _form = new Form { Text = title, StartPosition = FormStartPosition.Manual, Bounds = bounds, BackColor = Color.FromArgb(38, 38, 38), ShowInTaskbar = true };
            if (fullScreen) { _form.FormBorderStyle = FormBorderStyle.None; _form.Bounds = Screen.PrimaryScreen.Bounds; }
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
        for (int attempt = 0; attempt < 3; ++attempt)
        {
            Native.SetForegroundWindow(Handle);
            Native.SetWindowPos(Handle, IntPtr.Zero, 0, 0, 0, 0, 0x0013); // NOMOVE | NOSIZE | NOACTIVATE
            Thread.Sleep(100);
            Native.GetWindowRect(Handle, out var r);
            Native.GetCursorPos(out var saved);
            Native.SetCursorPos(r.Left + r.Width / 2, r.Top + r.Height / 2);
            Native.mouse_event(Native.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
            Native.mouse_event(Native.MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
            Thread.Sleep(250);
            Native.SetCursorPos(saved.X, saved.Y);
            if (Native.GetForegroundWindow() == Handle) return true;
        }
        return false;
    }

    public void Dispose()
    {
        try { _form?.Invoke(new Action(() => _form.Close())); } catch { }
        _thread.Join(2000);
    }
}

static class Probe
{
    static string _exe, _out, _request;
    static int _sessions;
    static readonly List<string> Report = new List<string>();
    static int _closeFailures;

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
        _request = Environment.GetEnvironmentVariable("VE_SPIKE_REQUEST");
        if ((what == "start" || what == "owner" || what == "close" || what == "integration" || what == "all") && (_request == null || !File.Exists(_request)))
        {
            Console.WriteLine("Set VE_SPIKE_REQUEST to the C4 request fixture (run_window_spikes.ps1 does).");
            return 2;
        }
        Log($"exe {_exe}");
        Log($"exe version {FileVersionInfo.GetVersionInfo(_exe).FileVersion}, size {new FileInfo(_exe).Length}, modified {File.GetLastWriteTime(_exe):s}");
        Log($"windows {Environment.OSVersion.Version}");
        Log($"data root {Environment.GetEnvironmentVariable("VEGAS_ENCODER_DATA_ROOT") ?? "(not set: the user's %APPDATA%)"}");
        foreach (var m in Monitors()) Log($"monitor {m.Bounds} work {m.Work} dpi {m.Dpi}{(m.Primary ? " primary" : "")}");
        try
        {
            if (what == "start" || what == "all") StartTime(runs);
            if (what == "owner" || what == "all") Owner();
            if (what == "close") CloseFocus();
            if (what == "monitor" || what == "all") Monitor();
            if (what == "theme" || what == "all") Theme();
            if (what == "integration") DesktopIntegration();
        }
        finally
        {
            File.WriteAllLines(Path.Combine(_out, "window-spikes.txt"), Report);
        }
        return _closeFailures == 0 ? 0 : 1;
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

    static void Require(bool condition, string message)
    {
        Log(message + ": " + Yes(condition));
        if (!condition) throw new InvalidOperationException(message);
    }

    static bool WaitForStage(string trace, string stage)
    {
        var sw = Stopwatch.StartNew();
        while (sw.ElapsedMilliseconds < 6000)
        {
            try { if (File.ReadAllLines(trace).Any(l => l.EndsWith(" " + stage))) return true; }
            catch (IOException) { }
            Thread.Sleep(20);
        }
        return false;
    }

    static bool WaitForRoute(string trace, string kind, string id) => WaitForStage(trace, "desktop_route_applied " + kind + " " + id);

    static void HandoffExited(Process process, string message)
    {
        var exited = process.WaitForExit(9000);
        if (!exited) { process.Kill(); process.WaitForExit(); }
        Require(exited && process.ExitCode == 0, message);
    }

    static bool SendRouteData(IntPtr window, string payload, uint tag = 0x56454E31)
    {
        var bytes = Encoding.ASCII.GetBytes(payload);
        var buffer = Marshal.AllocHGlobal(bytes.Length);
        try
        {
            Marshal.Copy(bytes, 0, buffer, bytes.Length);
            var data = new Native.COPYDATASTRUCT { dwData = new UIntPtr(tag), cbData = (uint)bytes.Length, lpData = buffer };
            return Native.SendMessageTimeout(window, 0x004A, IntPtr.Zero, ref data, 0x23, 2000, out var result) != IntPtr.Zero && result.ToUInt64() == 1;
        }
        finally { Marshal.FreeHGlobal(buffer); }
    }

    // Only selected by `integration`: real runner, fake owner, isolated data.
    // No theme changes, installed exporter, FFmpeg process or VEGAS process.
    static void DesktopIntegration()
    {
        var root = Environment.GetEnvironmentVariable("VEGAS_ENCODER_DATA_ROOT");
        if (root == null) throw new InvalidOperationException("An isolated data root is required.");
        Log("== desktop routes / profile isolation / popup physical size ==");
        var trace = Path.Combine(_out, "desktop-routes.txt");
        using (var first = Launch("--open-preset yt-h264", new Dictionary<string, string> { { "VEGAS_ENCODER_STARTUP_TRACE", trace } }))
        {
            IntPtr desktop = IntPtr.Zero;
            try
            {
                Require(WaitForStage(trace, "desktop_instance_acquired"), "first process acquires profile before startup race");
                // A second launch while the first engine is starting must be
                // queued/drained rather than discarded or create a new window.
                using (var early = Launch("--open-preset av1-small"))
                    HandoffExited(early, "startup handoff acknowledged");
                desktop = FindAppWindow(first.Id);
                Require(desktop != IntPtr.Zero && WaitForRoute(trace, "preset", "yt-h264") && WaitForRoute(trace, "preset", "av1-small"), "cold and queued preset routes applied");
                Native.ShowWindow(desktop, Native.SW_MINIMIZE);
                using (var warm = Launch("--open-preset ffv1-master", new Dictionary<string, string> { { "VEGAS_ENCODER_DATA_ROOT", root.ToUpperInvariant() + "\\" } }))
                    HandoffExited(warm, "equivalent profile forwards to existing process");
                Require(WaitForRoute(trace, "preset", "ffv1-master") && !Native.IsIconic(desktop), "warm route applied and desktop restored");
                Require(!SendRouteData(desktop, "preset\nyt-h264", 0) && !SendRouteData(desktop, "preset\n../escape") && !SendRouteData(desktop, "preset\n" + new string('a', 129)) && !SendRouteData(desktop, "preset\nCON"), "foreign, path, oversized and reserved destinations refused");
                var otherTrace = Path.Combine(_out, "desktop-other-profile.txt");
                using (var other = Launch("--open-preset av1-small", new Dictionary<string, string> {
                    { "VEGAS_ENCODER_DATA_ROOT", Path.Combine(root, "different-profile") },
                    { "VEGAS_ENCODER_STARTUP_TRACE", otherTrace } }))
                {
                    var otherWindow = FindAppWindow(other.Id);
                    Require(otherWindow != IntPtr.Zero && WaitForRoute(otherTrace, "preset", "av1-small"), "different profile owns an independent desktop");
                    Require(CloseAndWait(other, otherWindow), "other profile closes cleanly");
                }
            }
            finally { CloseAndWait(first, desktop); }
        }
        using (var host = new FakeHost("Fake VEGAS popup-size owner", new Rectangle(250, 150, 1100, 800)))
        {
            var roaming = Path.Combine(root, "Roaming");
            Directory.CreateDirectory(roaming);
            var ownerScale = Native.GetDpiForWindow(host.Handle) / 96.0;
            var physicalSize = new Size((int)Math.Ceiling(1020 * ownerScale), (int)Math.Ceiling(700 * ownerScale));
            foreach (var size in new[] { physicalSize, new Size(32768, 32768) })
            {
                var settings = Path.Combine(roaming, "machine.json");
                File.WriteAllText(settings, "{\"machine\":1,\"revision\":0,\"installations\":[],\"defaultFFmpegId\":null,\"progressWindow\":true,\"keepOnTop\":false,\"verifyOutput\":true,\"theme\":\"system\",\"uiState\":{\"desktopWindowBounds\":{\"x\":25,\"y\":30,\"width\":1200,\"height\":800},\"desktopMaximized\":false,\"lastSizeLengthText\":\"3:00\",\"popupWindowSize\":{\"width\":" + size.Width + ",\"height\":" + size.Height + "}}}");
                var dir = NewSession(host.Handle);
                using (var popup = Launch("--edit-session \"" + dir + "\""))
                {
                    var hwnd = FindAppWindow(popup.Id);
                    Thread.Sleep(200);
                    Native.GetWindowRect(hwnd, out var rect);
                    var work = WorkArea(host.Handle);
                    // Invisible resize borders may extend beyond the work area.
                    var dpi = Native.GetDpiForWindow(hwnd);
                    var border = (int)Math.Ceiling(16 * dpi / 96.0);
                    Require(hwnd != IntPtr.Zero && Native.GetWindow(hwnd, Native.GW_OWNER) == host.Handle, "remembered popup remains owned");
                    Require(rect.Top >= work.Top && rect.Bottom <= work.Bottom + border && rect.Left >= work.Left - border && rect.Right <= work.Right + border, "popup clamped to owner monitor work area");
                    if (size.Width < work.Width && size.Height < work.Height)
                        Require(rect.Width == size.Width && rect.Height == size.Height, "remembered outer physical size restored without rescaling");
                    Require(CloseAndWait(popup, hwnd), "remembered popup closes cleanly");
                }
                var saved = File.ReadAllText(settings);
                Require(saved.Contains("\"lastSizeLengthText\":\"3:00\"") && saved.Contains("\"desktopWindowBounds\""), "popup size save preserves desktop UI state");
            }
        }
    }

    /// A fresh session directory holding the fixture request (C4), owned by
    /// [owner] when given (the fake host), as the exporter's page writes it.
    static string NewSession(IntPtr owner)
    {
        var dir = Path.Combine(_out, "sessions", $"s{++_sessions:000}");
        if (Directory.Exists(dir)) throw new IOException("Preserve existing session output: " + dir);
        Directory.CreateDirectory(dir);
        var json = File.ReadAllText(_request);
        if (owner != IntPtr.Zero)
            json = Regex.Replace(json, "\"ownerHwnd\"\\s*:\\s*\"[^\"]*\"", $"\"ownerHwnd\": \"{owner.ToInt64()}\"");
        File.WriteAllText(Path.Combine(dir, "request.json"), json, new UTF8Encoding(false));
        return dir;
    }

    static string FixtureSessionId() => Regex.Match(File.ReadAllText(_request), "\"sessionId\"\\s*:\\s*\"([^\"]*)\"").Groups[1].Value;

    /// The session's result.json: (action, sessionId), or null when none was written.
    static (string action, string session)? SessionResult(string dir)
    {
        var path = Path.Combine(dir, "result.json");
        if (!File.Exists(path)) return null;
        var text = File.ReadAllText(path);
        return (Regex.Match(text, "\"action\"\\s*:\\s*\"(\\w+)\"").Groups[1].Value,
                Regex.Match(text, "\"sessionId\"\\s*:\\s*\"([^\"]*)\"").Groups[1].Value);
    }

    /// Files the writer left besides the request, the result and its lock.
    static List<string> Leftovers(string dir) => Directory.GetFiles(dir).Select(Path.GetFileName)
        .Where(n => n != "request.json" && n != "result.json" && !n.EndsWith(".lock")).ToList();

    static string ResultLine(string dir)
    {
        var r = SessionResult(dir);
        var left = Leftovers(dir);
        var cancel = r != null && r.Value.action == "cancel" && r.Value.session == FixtureSessionId();
        return $"result.json is a cancel for this session: {Yes(cancel)} ({(r == null ? "no result.json" : $"action {r.Value.action}, sessionId {r.Value.session}")}); " +
               $"other files: {(left.Count == 0 ? "none" : string.Join(", ", left))}; " +
               $"all files: {string.Join(", ", Directory.GetFiles(dir).Select(Path.GetFileName))}";
    }

    sealed class MonitorInfo { public IntPtr Handle; public Native.RECT Bounds, Work; public uint Dpi; public bool Primary; }

    static List<MonitorInfo> Monitors()
    {
        var list = new List<MonitorInfo>();
        Native.EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (IntPtr h, IntPtr dc, ref Native.RECT r, IntPtr d) =>
        {
            var info = new Native.MONITORINFO { cbSize = Marshal.SizeOf(typeof(Native.MONITORINFO)) };
            Native.GetMonitorInfo(h, ref info);
            Native.GetDpiForMonitor(h, Native.MDT_EFFECTIVE_DPI, out var x, out _);
            list.Add(new MonitorInfo { Handle = h, Bounds = info.rcMonitor, Work = info.rcWork, Dpi = x, Primary = (info.dwFlags & Native.MONITORINFOF_PRIMARY) != 0 });
            return true;
        }, IntPtr.Zero);
        return list;
    }

    /// The startup trace's lines once "shown" is in it (or after 5 s).
    static string[] WaitForTrace(string trace)
    {
        var sw = Stopwatch.StartNew();
        string[] lines = new string[0];
        while (sw.ElapsedMilliseconds < 5000)
        {
            try { lines = File.ReadAllLines(trace); } catch (IOException) { }
            if (lines.Any(l => l.EndsWith(" shown")) && lines.Any(l => l.EndsWith(" dart_first_frame"))) break;
            Thread.Sleep(20);
        }
        return lines;
    }

    static double? Mark(string[] lines, string stage)
    {
        var f = lines.Select(l => l.Split(new[] { ' ' }, 3)).FirstOrDefault(x => x.Length == 3 && x[2] == stage);
        return f == null ? (double?)null : double.Parse(f[1], CultureInfo.InvariantCulture);
    }

    // ------------------------------------------------------------ start time

    static void StartTime(int runs)
    {
        Log("");
        Log("== start time: ms from process creation (startup trace), medians ==");
        // Popups read the fixture request unowned: its ownerHwnd names no
        // window here, so the popup takes the no-owner path (centred on the
        // primary monitor), as with F0-F7's runs.
        var fixtureOwner = Regex.Match(File.ReadAllText(_request), "\"ownerHwnd\"\\s*:\\s*\"(\\d+)\"").Groups[1].Value;
        Log($"popup runs: fixture request, ownerHwnd {fixtureOwner} is a window here: {(long.TryParse(fixtureOwner, out var h) && Native.IsWindow(new IntPtr(h)) ? "YES (placed on it)" : "no")}");
        var stages = new[] { "runner_entry", "window_created", "dart_main", "dart_first_frame", "first_frame", "shown" };
        foreach (var renderer in new[] { "skia", "impeller" })
        foreach (var mode in new[] { "desktop", "popup" })
        {
            var runsMarks = new List<Dictionary<string, double>>();
            var cancels = 0;
            for (var i = 0; i < runs; i++)
            {
                var trace = Path.Combine(_out, $"trace-{renderer}-{mode}-{i}.txt");
                File.Delete(trace);
                var sessionDir = mode == "popup" ? NewSession(IntPtr.Zero) : null;
                var env = new Dictionary<string, string> { { "VEGAS_ENCODER_STARTUP_TRACE", trace } };
                env["VEGAS_ENCODER_RENDERER"] = renderer;
                var p = Launch(mode == "desktop" ? "" : $"--edit-session \"{sessionDir}\"", env);
                var hwnd = FindAppWindow(p.Id);
                var lines = WaitForTrace(trace);
                var marks = new Dictionary<string, double>();
                foreach (var f in lines.Select(l => l.Split(new[] { ' ' }, 3)).Where(f => f.Length == 3))
                    marks[f[2]] = double.Parse(f[1], CultureInfo.InvariantCulture);
                runsMarks.Add(marks);
                Thread.Sleep(300);
                CloseAndWait(p, hwnd);
                Thread.Sleep(300);
                if (sessionDir != null && SessionResult(sessionDir) is var r && r != null && r.Value.action == "cancel" && Leftovers(sessionDir).Count == 0) cancels++;
            }
            string Median(string stage)
            {
                var v = runsMarks.Where(m => m.ContainsKey(stage)).Select(m => m[stage]).OrderBy(x => x).ToList();
                return v.Count == 0 ? "-" : $"{v[v.Count / 2]:0}";
            }
            var shown = runsMarks.Where(m => m.ContainsKey("shown")).Select(m => m["shown"]).ToList();
            Log($"{renderer,-8} {mode,-8} " + string.Join("  ", stages.Select(st => $"{st} {Median(st)}")) +
                (shown.Count > 0 ? $"  | shown first run {shown[0]:0}, min {shown.Min():0}, max {shown.Max():0} ({shown.Count} runs)" : ""));
            if (mode == "popup") Log($"{"",-17} WM_CLOSE left a cancel result.json and no other files: {cancels} of {runs} runs");
        }
    }

    // ------------------------------------------------------------ owner window

    // Focused regression using the real release runner/C4, no native page poll
    // or post-exit activation to mask the frontend's close-time handoff.
    static void CloseFocus()
    {
        Log("== close focus: fake owner and full-screen other app; real Apply button / Cancel shortcut ==");
        using (var host = new FakeHost("Fake VEGAS Custom Settings", new Rectangle(300, 200, 1280, 820)))
        using (var other = new FakeHost("Fake full-screen other app", Rectangle.Empty, fullScreen: true))
        foreach (var order in new[] { "normal", "switch-back", "before-open", "background" })
        foreach (var action in order == "background" ? new[] { "cancel" } : new[] { "apply", "cancel" })
        {
            bool ready = host.Activate();
            if (order == "before-open") ready &= other.Activate();
            Native.EnableWindow(host.Handle, false);
            var dir = NewSession(host.Handle);
            var trace = Path.Combine(dir, "startup.txt");
            using (var p = Launch($"--edit-session \"{dir}\"",
                new Dictionary<string, string> { { "VEGAS_ENCODER_STARTUP_TRACE", trace } }))
            {
                var editor = FindAppWindow(p.Id);
                WaitForTrace(trace);
                Thread.Sleep(500);
                ready &= editor != IntPtr.Zero && Native.GetWindow(editor, Native.GW_OWNER) == host.Handle;
                if (order == "switch-back" || order == "background") ready &= other.Activate();
                if (order != "background")
                {
                    // Returning through the disabled VEGAS owner should route
                    // activation to its last active popup, as the real host does.
                    if (order == "switch-back") Native.SetForegroundWindow(host.Handle);
                    Native.SetWindowPos(editor, IntPtr.Zero, 0, 0, 0, 0, 0x0013);
                    Native.GetWindowRect(editor, out var er);
                    Native.GetCursorPos(out var saved);
                    Native.SetCursorPos(er.Left + er.Width / 2, er.Top + 24);
                    Native.mouse_event(Native.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
                    Native.mouse_event(Native.MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
                    Native.SetCursorPos(saved.X, saved.Y);
                    Thread.Sleep(250);
                    ready &= Native.GetForegroundWindow() == editor;
                }
                else ready &= Native.GetForegroundWindow() == other.Handle;

                if (ready && order != "background")
                {
                    if (action == "apply")
                    {
                        Native.GetWindowRect(editor, out var er);
                        double dpiScale = Native.GetDpiForWindow(editor) / 96.0;
                        Native.GetCursorPos(out var saved);
                        Native.SetCursorPos(er.Right - (int)(90 * dpiScale), er.Bottom - (int)(30 * dpiScale));
                        Native.mouse_event(Native.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
                        Native.mouse_event(Native.MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
                        Native.SetCursorPos(saved.X, saved.Y);
                    }
                    else
                    {
                        Native.keybd_event(0x1B, 0x01, 0, UIntPtr.Zero); // Escape
                        Native.keybd_event(0x1B, 0x01, 2, UIntPtr.Zero);
                    }
                }
                else if (ready) Native.PostMessage(editor, Native.WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
                bool exited = ready && p.WaitForExit(5000);
                Thread.Sleep(250);
                var expected = order == "background" ? other.Handle : host.Handle;
                var result = SessionResult(dir);
                bool passed = ready && exited && Native.IsWindowEnabled(host.Handle) &&
                    !Native.IsIconic(host.Handle) && Native.GetForegroundWindow() == expected &&
                    result != null && result.Value.action == action && result.Value.session == FixtureSessionId();
                Log($"{order}/{action}: {(passed ? "PASS" : "FAIL")} prerequisites={ready} exited={exited} " +
                    $"enabled={Native.IsWindowEnabled(host.Handle)} iconic={Native.IsIconic(host.Handle)} " +
                    $"foregroundExpected={Native.GetForegroundWindow() == expected} result={result?.action}; " +
                    $"shownMs={Mark(File.Exists(trace) ? File.ReadAllLines(trace) : new string[0], "shown")}");
                if (!passed) _closeFailures++;
                if (ready && !exited) Save(editor, $"close-{order}-{action}-failure.png");
                if (!p.HasExited) { p.Kill(); p.WaitForExit(); }
                Native.EnableWindow(host.Handle, true);
            }
        }
        Log($"close focus: {7 - _closeFailures}/7 passed (fake windows, not VEGAS)");
    }

    static void Owner()
    {
        Log("");
        Log("== owner window: --edit-session over a fake Custom Template dialog; owner from request.json (C4 ownerHwnd) ==");
        using (var host = new FakeHost("Fake VEGAS Custom Settings", new Rectangle(300, 200, 1280, 820)))
        {
            Log($"fake owner foreground after click: {Yes(host.Activate())}");
            var sessionDir = NewSession(host.Handle);

            // As the native page will: write the request, disable the owner,
            // then start the editor.
            Native.EnableWindow(host.Handle, false);
            var sw = Stopwatch.StartNew();
            var ownerTrace = Path.Combine(_out, "trace-owner.txt");
            File.Delete(ownerTrace);
            var p = Launch($"--edit-session \"{sessionDir}\"",
                new Dictionary<string, string> { { "VEGAS_ENCODER_STARTUP_TRACE", ownerTrace } });
            var editor = FindAppWindow(p.Id);
            Log($"editor visible after {sw.ElapsedMilliseconds} ms (wall clock from launch)");
            WaitForTrace(ownerTrace);
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
            Log($"WM_CLOSE with nothing changed: {ResultLine(sessionDir)}");

            // Crash: the editor dies with the owner still disabled.
            host.Activate();
            Native.EnableWindow(host.Handle, false);
            var crashDir = NewSession(host.Handle);
            p = Launch($"--edit-session \"{crashDir}\"");
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
            Log($"crash: no result.json (C4: a crashed editor means cancel): {Yes(SessionResult(crashDir) == null)}");
        }
        OwnerOnOtherDpi();
    }

    /// The popup over a fake host on a monitor whose DPI differs from the
    /// primary's (the window is created on the primary): placement, size and
    /// time to shown, three runs.
    static void OwnerOnOtherDpi()
    {
        Log("");
        Log("== owner window on a monitor with another DPI ==");
        var monitors = Monitors();
        var primary = monitors.FirstOrDefault(m => m.Primary);
        var other = monitors.FirstOrDefault(m => primary != null && m.Dpi != primary.Dpi);
        if (primary == null || other == null)
        {
            Log($"skipped: every monitor has the same DPI ({string.Join(", ", monitors.Select(m => m.Dpi))})");
            return;
        }
        var work = other.Work;
        var hostRect = new Rectangle(work.Left + (work.Width - 1280) / 2, work.Top + (work.Height - 820) / 2, Math.Min(1280, work.Width), Math.Min(820, work.Height));
        Log($"primary dpi {primary.Dpi}; fake host on {other.Bounds} at dpi {other.Dpi}");
        using (var host = new FakeHost("Fake VEGAS Custom Settings (other DPI)", hostRect))
        {
            Native.GetDpiForMonitor(Native.MonitorFromWindow(host.Handle, Native.MONITOR_DEFAULTTONEAREST), Native.MDT_EFFECTIVE_DPI, out var hostDpi, out _);
            Log($"fake host foreground after click: {Yes(host.Activate())}; host dpi {hostDpi}");
            var scale = other.Dpi / 96.0;
            int ew = (int)Math.Round(1120 * scale), eh = (int)Math.Round(740 * scale);
            for (var i = 0; i < 3; i++)
            {
                host.Activate();
                var sessionDir = NewSession(host.Handle);
                Native.EnableWindow(host.Handle, false);
                var trace = Path.Combine(_out, $"trace-otherdpi-{i}.txt");
                File.Delete(trace);
                var sw = Stopwatch.StartNew();
                var p = Launch($"--edit-session \"{sessionDir}\"", new Dictionary<string, string> { { "VEGAS_ENCODER_STARTUP_TRACE", trace } });
                var editor = FindAppWindow(p.Id);
                var visibleAfter = sw.ElapsedMilliseconds;
                var lines = WaitForTrace(trace);
                Thread.Sleep(600);
                Native.GetWindowRect(host.Handle, out var o);
                Native.GetWindowRect(editor, out var raw);
                var e = Visible(editor);
                int dx = (e.Left + e.Right) / 2 - (o.Left + o.Right) / 2, dy = (e.Top + e.Bottom) / 2 - (o.Top + o.Bottom) / 2;
                var owner = Native.GetWindow(editor, Native.GW_OWNER);
                var place = lines.FirstOrDefault(l => l.Contains("owner_bounds")) ?? "(no owner_bounds line)";
                Log($"run {i + 1}: owner set {Yes(owner == host.Handle)}; window dpi {Native.GetDpiForWindow(editor)}; rect {raw}; visible {e}; " +
                    $"centre offset ({dx},{dy}) px, within 4 px: {Yes(Math.Abs(dx) <= 4 && Math.Abs(dy) <= 4)}; " +
                    $"visible size vs 1120x740 at {other.Dpi} dpi ({ew}x{eh}): {e.Width - ew:+0;-0;0}x{e.Height - eh:+0;-0;0} px");
                Log($"  shown {Mark(lines, "shown"):0} ms, dart_main {Mark(lines, "dart_main"):0}, dart_first_frame {Mark(lines, "dart_first_frame"):0}, first_frame {Mark(lines, "first_frame"):0} (trace); visible after {visibleAfter} ms (wall clock)");
                Log($"  trace: {place}");
                if (i == 0) Save(editor, "owner-popup-otherdpi.png", 24);
                CloseAndWait(p, editor);
                Thread.Sleep(400);
                Log($"  owner re-enabled: {Yes(Native.IsWindowEnabled(host.Handle))}; {ResultLine(sessionDir)}");
                Native.EnableWindow(host.Handle, true);
            }
        }
    }

    // ------------------------------------------------------------ no-activate progress window

    /// A C5 live status file for a render in VEGAS's main window [host]: the
    /// encoding sample (schema/fixtures/b0/live) with this host's handle.
    static string WriteLive(string name, IntPtr host)
    {
        var live = Path.Combine(_out, name);
        File.WriteAllText(live,
            "{\"live\":1,\"jobId\":\"spike-render\",\"hostHwnd\":\"" + unchecked((ulong)host.ToInt64()) + "\",\"sequence\":2," +
            "\"updatedAt\":\"" + DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ") + "\",\"state\":\"encoding\"," +
            "\"framesDone\":7400,\"framesTotal\":22873,\"encodeFps\":61.8,\"speed\":2.06,\"bitrateKbps\":30700," +
            "\"bytesWritten\":1230000000,\"elapsedSec\":244,\"etaSec\":250,\"estimatedFinalBytes\":2930000000," +
            "\"outputPath\":\"D:\\\\Renders\\\\Lakeside wedding final.mp4\",\"templateName\":\"YouTube 4K upload (Lakeside)\"," +
            "\"encoderSummary\":\"x264 CRF 17, slower / AAC 256 kb/s\",\"message\":\"Encoding.\",\"ffmpegExitCode\":null}");
        return live;
    }

    /// C7 keep on top in the spike's data root (run_window_spikes.ps1 sets it).
    static void SetKeepOnTop(bool value)
    {
        var root = Environment.GetEnvironmentVariable("VEGAS_ENCODER_DATA_ROOT");
        if (root == null) throw new InvalidOperationException("VEGAS_ENCODER_DATA_ROOT is not set: refusing to write the user's machine.json.");
        var roaming = Path.Combine(root, "Roaming");
        Directory.CreateDirectory(roaming);
        File.WriteAllText(Path.Combine(roaming, "machine.json"),
            "{\"machine\":1,\"revision\":0,\"installations\":[],\"defaultFFmpegId\":null,\"progressWindow\":true," +
            "\"keepOnTop\":" + (value ? "true" : "false") + ",\"verifyOutput\":true,\"theme\":\"system\",\"uiState\":null}");
    }

    /// Where the window should be on [m]: 380x340 at its DPI, 16 px in from
    /// the bottom-right corner of its work area.
    static string CornerCheck(Native.RECT r, MonitorInfo m)
    {
        var scale = m.Dpi / 96.0;
        int w = (int)Math.Round(380 * scale), h = (int)Math.Round(340 * scale), margin = (int)Math.Round(16 * scale);
        int gapRight = m.Work.Right - r.Right, gapBottom = m.Work.Bottom - r.Bottom;
        var inside = r.Left >= m.Work.Left && r.Top >= m.Work.Top && r.Right <= m.Work.Right && r.Bottom <= m.Work.Bottom;
        return $"inside that work area: {Yes(inside)}; size {r.Width}x{r.Height} vs {w}x{h}; gap right {gapRight}, bottom {gapBottom} px (margin {margin})";
    }

    static MonitorInfo MonitorOf(IntPtr hwnd)
    {
        var handle = Native.MonitorFromWindow(hwnd, Native.MONITOR_DEFAULTTONEAREST);
        return Monitors().First(m => m.Handle == handle);
    }

    static void Monitor()
    {
        Log("");
        Log("== no-activate window: --render-monitor over a fake VEGAS main window ==");
        using (var host = new FakeHost("Fake VEGAS Pro", new Rectangle(200, 150, 1400, 900)))
        {
            Log($"fake VEGAS foreground after click: {Yes(host.Activate())}");
            SetKeepOnTop(false);
            var live = WriteLive("render.live.json", host.Handle);
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
            Log($"progress window {r}; work area of VEGAS's monitor {work}; {CornerCheck(r, MonitorOf(host.Handle))}");
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

            // The remembered pin (C7 keepOnTop) applies before the first frame.
            SetKeepOnTop(true);
            host.Activate();
            p = Launch($"--render-monitor \"{live}\"");
            mon = FindAppWindow(p.Id);
            Thread.Sleep(800);
            ex = Native.GetWindowLongPtr(mon, Native.GWL_EXSTYLE).ToInt64();
            Log($"with keepOnTop=true in machine.json: topmost {Yes((ex & Native.WS_EX_TOPMOST) != 0)}; VEGAS still foreground {Yes(Native.GetForegroundWindow() == host.Handle)}");
            CloseAndWait(p, mon);
            SetKeepOnTop(false);
        }
        MonitorOnHostMonitor();
    }

    /// C5 hostHwnd names VEGAS's main window on another monitor while a
    /// different window is in the foreground: the window goes to VEGAS's
    /// monitor, at that monitor's DPI, not the foreground window's.
    static void MonitorOnHostMonitor()
    {
        Log("");
        Log("== progress window on VEGAS's monitor (C5 hostHwnd), another window in front ==");
        var monitors = Monitors();
        var primary = monitors.FirstOrDefault(m => m.Primary);
        var other = monitors.FirstOrDefault(m => !m.Primary);
        if (primary == null || other == null)
        {
            Log("skipped: one monitor only");
            return;
        }
        Rectangle On(MonitorInfo m) => new Rectangle(m.Work.Left + 80, m.Work.Top + 80, Math.Min(1000, m.Work.Width - 160), Math.Min(700, m.Work.Height - 160));
        using (var vegas = new FakeHost("Fake VEGAS Pro (other monitor)", On(other)))
        using (var front = new FakeHost("Another app (primary monitor)", On(primary)))
        {
            Log($"VEGAS on {other.Bounds} at dpi {other.Dpi}; foreground window on the primary at dpi {primary.Dpi}: {Yes(front.Activate())}");
            var live = WriteLive("render-other.live.json", vegas.Handle);
            var trace = Path.Combine(_out, "trace-monitor-host.txt");
            File.Delete(trace);
            var p = Launch($"--render-monitor \"{live}\"", new Dictionary<string, string> { { "VEGAS_ENCODER_STARTUP_TRACE", trace } });
            var mon = FindAppWindow(p.Id);
            var lines = WaitForTrace(trace);
            Thread.Sleep(800);
            var r = Visible(mon);
            Log($"progress window {r}, dpi {Native.GetDpiForWindow(mon)}; on VEGAS's monitor: {Yes(MonitorOf(mon).Handle == other.Handle)}; {CornerCheck(r, other)}");
            Log($"the other app still foreground: {Yes(Native.GetForegroundWindow() == front.Handle)}; owner none: {Yes(Native.GetWindow(mon, Native.GW_OWNER) == IntPtr.Zero)}");
            Log($"  trace: {lines.FirstOrDefault(l => l.Contains("host_bounds")) ?? "(no host_bounds line)"}; shown {Mark(lines, "shown"):0} ms");
            Save(mon, "monitor-window-host.png", 24);
            CloseAndWait(p, mon);

            // A handle that is no longer a window falls back to the foreground's monitor.
            var stale = WriteLive("render-stale.live.json", new IntPtr(0x7FFFFFF0));
            front.Activate();
            p = Launch($"--render-monitor \"{stale}\"");
            mon = FindAppWindow(p.Id);
            Thread.Sleep(800);
            r = Visible(mon);
            Log($"stale hostHwnd: on the foreground window's monitor: {Yes(MonitorOf(mon).Handle == primary.Handle)}; {CornerCheck(r, primary)}");
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
