# Windows Notification Skill

Send native Windows toast notifications from PowerShell via the WinRT `ToastNotificationManager` API. Clicking a notification refocuses the originating terminal window and tab.

## Features

- **Native Windows Toasts** — Uses WinRT API for authentic Windows 10/11 toast notifications
- **Smart Tab Refocusing** — Clicking the notification returns focus to the exact terminal tab that triggered it
- **Claude Branding** — Toasts display with the Claude Code logo and AppUserModelId
- **Zero Dependencies** — No external packages required; uses built-in Windows PowerShell 5.1
- **Portable** — Registers `claude-focus:` protocol under HKCU on first run; no admin privileges needed
- **Multilingual** — Recognizes trigger phrases in English and Portuguese

## Usage

Invoke via PowerShell:

```powershell
& "$env:USERPROFILE\.claude\skills\windows-notification\notify.ps1" "TITLE HERE" "MESSAGE HERE"
```

### Parameters

- **First argument** — Notification title
- **Second argument** — Notification message body

### Examples

```powershell
& "$env:USERPROFILE\.claude\skills\windows-notification\notify.ps1" "Build Complete" "Your project compiled successfully"

& "$env:USERPROFILE\.claude\skills\windows-notification\notify.ps1" "CI Checks Passed" "All tests passed. Ready to merge!"
```

## How It Works

1. **PowerShell Delegation** — When invoked in pwsh 7 (which lacks WinRT support), the script delegates to Windows PowerShell 5.1 for display
2. **Protocol Registration** — On first run, registers the `claude-focus:` URL protocol under `HKCU\Software\Classes\claude-focus` (no admin needed)
3. **AppUserModelId** — Creates a branded app identity (`Claude.Code.Notify`) so toasts display with the Claude logo
4. **Window & Tab Matching** — Reads from the console of the `claude` ancestor process (tool commands run in their own console) both the tab title and the Windows Terminal window that owns that console. The window comes from the console's owner rather than `MainWindowHandle`, because one WT process hosts all its windows and `MainWindowHandle` is just the frontmost (wrong when ours is minimized). UI Automation then matches the title against that window's tab names, falling back to tab index
5. **Focus Handler** — Clicking the toast invokes the `claude-focus:` handler, which refocuses the terminal and navigates to the correct tab

## Files

- **notify.ps1** — Main entry point; delegates to `show-toast.ps1` and manages tab focusing
- **show-toast.ps1** — Runs under Windows PowerShell 5.1; creates and displays the WinRT toast
- **focus-window.ps1** — Handles the focus and tab-selection logic via UI Automation
- **wt-helpers.ps1** — Windows Terminal integration utilities (title normalization, WT window enumeration, tab lookup)
- **read-session-console.ps1** — Child process that attaches to the `claude` process's console and prints its owner window handle and its title (Base64, immune to the caller's code page)
- **claude-logo.png** — Claude logo displayed on toasts

## Important Notes

### Tab Title Comes From the `claude` Process

Claude Code runs tool commands in a separate console (`claude → cmd.exe|bash → pwsh`), so the script's own `[Console]::Title` is the shell path, never the tab title. `notify.ps1` therefore reads the title and the owning WT window of the `claude` ancestor's console via `read-session-console.ps1`; it falls back to its own console title and `MainWindowHandle` only when run by hand outside Claude Code. The title travels as Base64 because under Git Bash the console code page is cp850, which would garble the spinner glyph (`◐` → `Ôùæ`) and break the match. Prefer the PowerShell tool since the script is pwsh, but matching works from either tool.

### Timing

Fire notifications **immediately** when a condition triggers (e.g., CI passes, build finishes), then report the result in chat:

```
1. Condition flips (build done) → send notification
2. Report outcome in chat
```

## First Run Setup

No manual setup required. On first invocation:

- Registers `claude-focus:` protocol handler
- Creates `Claude.Code.Notify` AppUserModelId
- Sets up necessary registry entries (all under HKCU, requires no admin)

All operations are idempotent; running the script multiple times is safe.

## Platform Support

- **Windows 10/11** — Full support
- **WSL / Other Platforms** — Not supported; uses Windows-specific APIs

## Troubleshooting

### Notification doesn't appear

- Check Windows notifications are enabled in Settings > System > Notifications
- Verify the script ran without errors in the terminal output

### Clicking notification focuses wrong tab

- The tab title could not be resolved, so the launch URI has no `?tab=` segment and the click only brings the window forward
- Check that a `claude` process is an ancestor of the script and that `read-session-console.ps1` prints a non-zero window handle and a Base64 title for its PID

### Clicking notification focuses the wrong window

- With several Windows Terminal windows open, the launch URI's handle must be the owner of the `claude` console, not the WT process's `MainWindowHandle` — check the first field `read-session-console.ps1` prints

### Protocol registration fails

- Ensure the user has write access to `HKCU\Software\Classes\claude-focus`
- Run the script as the same user that invoked it


