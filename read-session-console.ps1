# Prints "<ownerWindowHandle> <base64Utf8Title>" for the console attached to -TargetPid (the `claude`
# process hosting the session). notify.ps1 runs inside a tool subprocess with its own console
# (`claude → cmd.exe|bash → pwsh`), so neither its [Console]::Title nor its window ancestry points at
# the Windows Terminal tab. A process can hold only one console, so this runs as a throwaway child:
# it detaches, attaches to the target's console and reads:
#   - the console title, i.e. the tab title Claude Code sets;
#   - the root owner of the console's pseudo-window, i.e. the Windows Terminal window hosting the tab
#     (0 when the console isn't hosted by Windows Terminal).
# The title goes out as Base64 so the caller's console code page (cp850 under Git Bash) can't garble it.
param(
    [Parameter(Mandatory)][int]$TargetPid
)

$ErrorActionPreference = 'Stop'

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class SessionConsoleReader {
    [DllImport("kernel32.dll")] static extern bool FreeConsole();
    [DllImport("kernel32.dll")] static extern bool AttachConsole(uint pid);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern uint GetConsoleTitleW(StringBuilder buf, uint size);
    [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] static extern IntPtr GetAncestor(IntPtr hWnd, uint flags);

    const uint GA_ROOTOWNER = 3;

    public static string Read(uint pid) {
        FreeConsole();
        if (!AttachConsole(pid)) { return "0 "; }
        var title = new StringBuilder(1024);
        GetConsoleTitleW(title, (uint)title.Capacity);
        var consoleWindow = GetConsoleWindow();
        var owner = consoleWindow == IntPtr.Zero ? IntPtr.Zero : GetAncestor(consoleWindow, GA_ROOTOWNER);
        if (owner == consoleWindow) { owner = IntPtr.Zero; }
        FreeConsole();
        return (long)owner + " " + Convert.ToBase64String(Encoding.UTF8.GetBytes(title.ToString()));
    }
}
"@

[Console]::Out.Write([SessionConsoleReader]::Read([uint32]$TargetPid))
