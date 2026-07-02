# Invoked by the `claude-focus:` URL protocol when a notification toast is clicked.
# Receives "claude-focus:<hwnd>[?tab=<i>&title=<urlencoded>]" and brings that terminal
# window — and, for Windows Terminal, the originating tab — to the foreground.
param(
    [Parameter(Position = 0)][string]$Uri
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'wt-helpers.ps1')

try {
    # Strip the scheme (Windows may append a trailing slash), then split handle from query.
    $rest = ($Uri -replace '^claude-focus:', '').TrimEnd('/')
    $hwndPart, $queryPart = $rest -split '\?', 2

    $digits = ($hwndPart -replace '[^0-9]', '')
    if ([string]::IsNullOrWhiteSpace($digits)) { return }
    $hwnd = [IntPtr][int64]$digits

    $tabIndex = -1
    $tabTitle = ''
    if ($queryPart) {
        foreach ($pair in $queryPart -split '&') {
            $k, $v = $pair -split '=', 2
            if ($k -eq 'tab') { $tabIndex = [int]$v }
            elseif ($k -eq 'title') { $tabTitle = [uri]::UnescapeDataString($v) }
        }
    }

    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class WinFocus {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    const int SW_RESTORE = 9;
    const int SW_MINIMIZE = 6;
    const int SW_SHOW = 5;
    const byte VK_MENU = 0x12;
    const uint KEYEVENTF_KEYUP = 0x2;

    public static bool Focus(IntPtr hWnd) {
        if (!IsWindow(hWnd)) { return false; }
        if (IsIconic(hWnd)) { ShowWindow(hWnd, SW_RESTORE); } else { ShowWindow(hWnd, SW_SHOW); }

        // Simulate an ALT keypress so Windows lifts the foreground lock for our process.
        keybd_event(VK_MENU, 0, 0, UIntPtr.Zero);
        keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);

        // Attaching to the current foreground thread further relaxes the restriction.
        uint dummy;
        uint fgThread = GetWindowThreadProcessId(GetForegroundWindow(), out dummy);
        uint tgtThread = GetWindowThreadProcessId(hWnd, out dummy);
        bool attached = false;
        if (fgThread != tgtThread) { attached = AttachThreadInput(fgThread, tgtThread, true); }
        BringWindowToTop(hWnd);
        bool ok = SetForegroundWindow(hWnd);
        if (attached) { AttachThreadInput(fgThread, tgtThread, false); }

        // Fallback: a minimize+restore cycle reliably forces the window to the foreground.
        if (!ok || GetForegroundWindow() != hWnd) {
            ShowWindow(hWnd, SW_MINIMIZE);
            ShowWindow(hWnd, SW_RESTORE);
            ok = SetForegroundWindow(hWnd);
        }
        return ok;
    }
}
"@

    # Select the originating Windows Terminal tab, if one was recorded. Prefer matching by
    # (normalized) title — a positive id even if tabs were reordered — and fall back to the
    # recorded index when the title has since changed (Claude Code updates it as it works).
    if ($tabIndex -ge 0 -or $tabTitle) {
        try {
            $tabs = Get-WtTabElements ([int]([int64]$hwnd))
            $target = $null
            if ($tabTitle) {
                $norm = ConvertTo-NormTitle $tabTitle
                for ($i = 0; $i -lt $tabs.Count; $i++) {
                    if ((ConvertTo-NormTitle $tabs[$i].Current.Name) -eq $norm) { $target = $tabs[$i]; break }
                }
            }
            if (-not $target -and $tabIndex -ge 0 -and $tabIndex -lt $tabs.Count) {
                $target = $tabs[$tabIndex]
            }
            if ($target) {
                $target.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern).Select()
            }
        } catch { }
    }

    [WinFocus]::Focus($hwnd) | Out-Null
}
catch { }
