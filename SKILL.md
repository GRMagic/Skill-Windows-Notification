---
name: windows-notification
description: Show a native Windows desktop notification (toast) from PowerShell. Use whenever the user asks to be notified, pinged, or alerted when something happens — e.g. "me avise quando os checks passarem", "show me a notification when the build finishes", "ping me when X completes", "notifica quando terminar", "send a Windows notification". Also use when the user explicitly asks to display a notification right now.
disable-model-invocation: false
allowed-tools: PowerShell(& "${CLAUDE_SKILL_DIR}\notify.ps1":*)
---

# Windows Notification

Send a native Windows toast via the WinRT `ToastNotificationManager`, always carrying the
Claude logo. Clicking the toast brings the originating terminal window back to the foreground.

Run it with the **PowerShell tool** (pwsh):

```powershell
& "${CLAUDE_SKILL_DIR}\notify.ps1" "TITLE HERE" "MESSAGE HERE"
```

- First argument is the title; the second is the body.
- Optional third argument is the sound: an `ms-winsoundevent:*` URI played when the toast
  appears. Defaults to `ms-winsoundevent:Notification.Default`. Pass an empty string (`""`)
  for a silent toast. Other built-in options include `ms-winsoundevent:Notification.IM`,
  `.Mail`, `.Reminder`, `.SMS`, and the looping `.Looping.Alarm` / `.Looping.Call` events.
  ```powershell
  & "${CLAUDE_SKILL_DIR}\notify.ps1" "Build done" "All checks passed" "ms-winsoundevent:Notification.IM"
  ```
- Tab re-focus does not depend on which tool fires it: tool commands run in their own console
  (`claude → cmd.exe|bash → pwsh`), so `notify.ps1` reads, via `read-session-console.ps1`, the
  `claude` ancestor's console title (matched against the tab names) and the Windows Terminal window
  that owns that console (so the right window is targeted even when it is minimized).
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
