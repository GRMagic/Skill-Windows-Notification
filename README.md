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
2. **Protocol Registration** — On first run, registers the `claude-focus:` URL protocol under `HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths` (no admin needed)
3. **AppUserModelId** — Creates a branded app identity (`Claude.Code.Notify`) so toasts display with the Claude logo
4. **Tab Matching** — Uses UI Automation to match the console window title against Windows Terminal tab names, falling back to tab index
5. **Focus Handler** — Clicking the toast invokes the `claude-focus:` handler, which refocuses the terminal and navigates to the correct tab

## Files

- **notify.ps1** — Main entry point; delegates to `show-toast.ps1` and manages tab focusing
- **show-toast.ps1** — Runs under Windows PowerShell 5.1; creates and displays the WinRT toast
- **focus-window.ps1** — Handles the focus and tab-selection logic via UI Automation
- **wt-helpers.ps1** — Windows Terminal integration utilities
- **claude-logo.png** — Claude logo displayed on toasts

## Important Notes

### Use PowerShell, Not Bash

Always invoke via the **PowerShell tool** (`pwsh`), never Bash:

```powershell
# ✅ Correct
& "$env:USERPROFILE\.claude\skills\windows-notification\notify.ps1" "Title" "Message"

# ❌ Wrong (Bash will break tab matching)
bash -c 'powershell -Command "& \"%USERPROFILE%\.claude\skills\windows-notification\notify.ps1\" \"Title\" \"Message\""'
```

Running through Bash adds `bash.exe` to the process tree, which overwrites the console title and breaks the tab-matching logic.

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

- Ensure you're using the **PowerShell tool**, not Bash
- Check Windows notifications are enabled in Settings > System > Notifications
- Verify the script ran without errors in the terminal output

### Clicking notification focuses wrong tab

- This indicates the script was run through Bash instead of PowerShell
- Re-run using the PowerShell tool directly

### Protocol registration fails

- Ensure the user has write access to `HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths`
- Run the script as the same user that invoked it


