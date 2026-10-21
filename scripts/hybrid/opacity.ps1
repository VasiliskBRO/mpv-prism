# Prism: makes the mpv window see-through (Windows layered window). Started by opacity.lua next to this file.
# mpv writes "<window handle> <alpha away> <alpha under the mouse>" (alpha 0..255, 255 = solid) to the -State file;
# the helper checks it and the mouse 20 times a second, so "solid under the mouse" reacts at once.
# Ends by itself when mpv (-MpvPid) is gone.
# Kept ASCII-only: Windows PowerShell 5.1 reads BOM-less files as cp1251.
param(
    [Parameter(Mandatory)] [string] $State,
    [Parameter(Mandatory)] [int] $MpvPid
)

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class PrismWin {
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
    [DllImport("user32.dll")] public static extern IntPtr GetWindowLongPtr(IntPtr h, int i);
    [DllImport("user32.dll")] public static extern IntPtr SetWindowLongPtr(IntPtr h, int i, IntPtr v);
    [DllImport("user32.dll")] public static extern bool SetLayeredWindowAttributes(IntPtr h, uint key, byte alpha, uint flags);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
    [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);

    const int GWL_EXSTYLE = -20;
    const long WS_EX_LAYERED = 0x80000;

    // 255 takes the layered style off: a normal window again, nothing left behind
    public static void Apply(IntPtr h, int alpha) {
        long ex = GetWindowLongPtr(h, GWL_EXSTYLE).ToInt64();
        if (alpha >= 255) {
            if ((ex & WS_EX_LAYERED) != 0) SetWindowLongPtr(h, GWL_EXSTYLE, new IntPtr(ex & ~WS_EX_LAYERED));
            return;
        }
        if ((ex & WS_EX_LAYERED) == 0) SetWindowLongPtr(h, GWL_EXSTYLE, new IntPtr(ex | WS_EX_LAYERED));
        SetLayeredWindowAttributes(h, 0, (byte)Math.Max(0, alpha), 2);
    }

    // the mouse is over this window (and not over another one covering it)
    public static bool Under(IntPtr h) {
        POINT p;
        if (!GetCursorPos(out p)) return false;
        return GetAncestor(WindowFromPoint(p), 2) == h;
    }
}
"@

$mpv = $null
try { $mpv = [Diagnostics.Process]::GetProcessById($MpvPid) } catch { exit }

$hwnd = [IntPtr]::Zero
$away = 255
$hover = 255
$stamp = [DateTime]::MinValue
$shown = 255   # what the window has now
$step = 64     # a short fade: about 4 ticks from solid to clear

while (-not $mpv.HasExited) {
    try {
        $t = [IO.File]::GetLastWriteTimeUtc($State)
        if ($t -ne $stamp) {
            $stamp = $t
            $parts = [IO.File]::ReadAllText($State).Trim() -split '\s+'
            if ($parts.Count -ge 3) {
                $h = [IntPtr][long]$parts[0]
                if ($h -ne $hwnd -and $hwnd -ne [IntPtr]::Zero -and [PrismWin]::IsWindow($hwnd)) { [PrismWin]::Apply($hwnd, 255) }
                if ($h -ne $hwnd) { $hwnd = $h; $shown = 255 }
                $away = [int]$parts[1]
                $hover = [int]$parts[2]
            }
        }
    } catch {}
    if ($hwnd -ne [IntPtr]::Zero) {
        $want = $away
        if ($hover -ne $away -and [PrismWin]::Under($hwnd)) { $want = $hover }
        if ($want -ne $shown) {
            if ($want -gt $shown) { $shown = [Math]::Min($want, $shown + $step) }
            else { $shown = [Math]::Max($want, $shown - $step) }
            [PrismWin]::Apply($hwnd, $shown)
        }
    }
    Start-Sleep -Milliseconds 50
}
Remove-Item -LiteralPath $State -ErrorAction SilentlyContinue
