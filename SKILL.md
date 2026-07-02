---
name: windows-notification
description: Show a native Windows desktop notification (toast) from PowerShell. Use whenever the user asks to be notified, pinged, or alerted when something happens — e.g. "me avise quando os checks passarem", "show me a notification when the build finishes", "ping me when X completes", "notifica quando terminar", "send a Windows notification". Also use when the user explicitly asks to display a notification right now.
disable-model-invocation: false
allowed-tools: PowerShell(& "$env:USERPROFILE\.claude\skills\windows-notification\notify.ps1":*)
---

# Windows Notification

Send a native Windows toast via the WinRT `ToastNotificationManager`, always carrying the
Claude logo. Clicking the toast brings the originating terminal window back to the foreground.

Run it with the **PowerShell tool** (pwsh), never the Bash tool:

```powershell
& "$env:USERPROFILE\.claude\skills\windows-notification\notify.ps1" "TITLE HERE" "MESSAGE HERE"
```

- First argument is the title; the second is the body.
- IMPORTANT: invoke this via the PowerShell tool, not Bash. The skill re-focuses the originating
  Windows Terminal tab by matching the console title against the tab names; running through Bash
  puts a `bash.exe` in the process tree that overwrites the console title, so the tab match fails
  and clicking the toast lands on the wrong tab (the window still comes forward).
- Clicking the notification focuses the terminal that fired it — and, in Windows Terminal,
  re-selects the exact tab that fired it (matched by tab title via UI Automation, falling
  back to the tab index). This works via a `claude-focus:` URL protocol that `notify.ps1`
  self-registers under HKCU on first run — no manual setup, so the skill folder is portable.
- No installable dependencies. `notify.ps1` runs in pwsh 7 (which doesn't project the WinRT
  toast APIs), so it hands the actual display to `show-toast.ps1` under Windows PowerShell 5.1
  (always present on Win10/11). On first run it registers, under HKCU, the `claude-focus:`
  protocol and the `Claude.Code.Notify` AppUserModelId (DisplayName "Claude Code" + logo, so
  the toast is branded as Claude Code) — both idempotent, no admin, folder stays portable.
- When notifying on a condition (CI passes, build finishes, task completes), fire this the
  moment the condition flips, then also report in chat.
