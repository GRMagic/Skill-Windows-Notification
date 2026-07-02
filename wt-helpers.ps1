# Shared helpers for locating the Windows Terminal tab that owns the current session.
# Dot-sourced by notify.ps1 (to record the tab) and focus-window.ps1 (to re-select it).

# Strip a leading run of symbols/spinner/whitespace (e.g. Claude Code's animated braille
# spinner "⠂" or a "✳" prefix) so two snapshots of the same title compare equal.
function ConvertTo-NormTitle([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return '' }
    return ($s -replace '^[^\p{L}\p{N}]+', '').Trim()
}

# Return the TabItem UIAutomation elements (in tab order) for the Windows Terminal window
# identified by the given native window handle. Empty collection if not found.
function Get-WtTabElements([int]$hwnd) {
    Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $cond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NativeWindowHandleProperty, [int]$hwnd)
    $win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
    if (-not $win) { return @() }
    $tabCond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::TabItem)
    return $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tabCond)
}
