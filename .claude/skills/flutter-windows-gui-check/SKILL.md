---
name: flutter-windows-gui-check
description: >
  Launch and drive the actual Windows desktop build of Projector Grid to visually verify a
  UI/theme change — screenshot the running window, click menus/buttons, and screenshot the
  result. Use this whenever a change touches anything visual (theme, dialog, layout, widget)
  and needs a real look, not just `flutter analyze`/`flutter test`. Covers the two gotchas that
  make naive PowerShell screenshot/click scripts silently capture the wrong window: Windows'
  foreground-lock blocking `SetForegroundWindow`, and focus reverting to the calling terminal
  between separate tool calls.
---

# Flutter Windows GUI check

`flutter analyze` and `flutter test` don't catch whether a theme/dialog change actually
*looks* right. This skill drives the real `projector_grid.exe` window and captures what a
user would see — verified working end-to-end (launch, activate, screenshot, click, screenshot
again) on this machine.

## The two gotchas

1. **`SetForegroundWindow` from a background process is silently ignored.** Windows'
   foreground-lock only lets the currently-focused process (or one using a documented
   workaround) steal focus. Don't call the raw Win32 API — use the `WScript.Shell` COM
   object's `AppActivate`, which is exempt from the restriction:
   ```powershell
   $wshell = New-Object -ComObject wscript.shell
   $wshell.AppActivate($processId) | Out-Null   # or AppActivate("window title")
   ```

2. **Focus reverts to the calling terminal between separate tool invocations.** Activating
   the app window in one PowerShell call, then screenshotting in a *second* call, captures
   whatever regained focus in between (this environment's own editor/terminal) — not the
   app. **Always combine activate + (click +) screenshot in one PowerShell script.**

A third, smaller gotcha: don't reuse a previously-known window rect. The window may have
moved, resized, or been maximized since — re-read it with `GetForegroundWindow` +
`GetWindowRect` right before computing screenshot bounds or click coordinates, inside the
same script.

## Recipe

### 1. Get a running instance

Prefer reusing an already-built debug exe over a fresh `flutter run` (much faster):

```powershell
Get-Process -Name "projector_grid" -ErrorAction SilentlyContinue
```

If nothing's running, launch the existing debug build directly (no rebuild):

```powershell
Start-Process "D:\Flutter\projector-grid\build\windows\x64\runner\Debug\projector_grid.exe"
Start-Sleep -Seconds 2
```

If there's no debug build yet, or the change needs a rebuild to show up, use the Bash tool
(not PowerShell) with `run_in_background: true`:

```bash
cd "D:/Flutter/projector-grid" && flutter run -d windows
```

### 2. Activate + screenshot the whole window (one script)

```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinApi {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
$p = Get-Process -Name "projector_grid" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$wshell = New-Object -ComObject wscript.shell
$wshell.AppActivate($p.Id) | Out-Null
Start-Sleep -Milliseconds 500

$h = [WinApi]::GetForegroundWindow()
$rect = New-Object WinApi+RECT
[WinApi]::GetWindowRect($h, [ref]$rect) | Out-Null

Add-Type -AssemblyName System.Drawing
$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
$bmp = New-Object System.Drawing.Bitmap $width, $height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
$outPath = "$env:TEMP\pg_screenshot.png"
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output $outPath
```

Then **view it with the Read tool** on the printed path (`%TEMP%\pg_screenshot.png`) — Claude
Code reads images directly. Look at it; a blank/wrong-window capture means the two gotchas
above weren't respected.

### 3. Click something, then screenshot again (one script)

Compute click coordinates as `window_rect.Left/Top + offset_seen_in_the_last_screenshot` —
read them off the image you just looked at, don't guess. Combine activate + click +
screenshot in one script, same reasoning as step 2:

```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinClick {
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    public const uint LEFTDOWN = 0x0002;
    public const uint LEFTUP = 0x0004;
}
"@
function Click($x, $y) {
    [WinClick]::SetCursorPos($x, $y) | Out-Null
    Start-Sleep -Milliseconds 120
    [WinClick]::mouse_event([WinClick]::LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [WinClick]::mouse_event([WinClick]::LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
}

$p = Get-Process -Name "projector_grid" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$wshell = New-Object -ComObject wscript.shell
$wshell.AppActivate($p.Id) | Out-Null
Start-Sleep -Milliseconds 500

Click <absoluteX> <absoluteY>
Start-Sleep -Milliseconds 400

Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap 1280, 720
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(<windowLeft>, <windowTop>, 0, 0, $bmp.Size)
$bmp.Save("$env:TEMP\pg_click.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "saved"
```

Repeat step 3 (new coordinates each time, read off the latest screenshot) to walk through
menus, open a dialog, toggle a control, etc. — whatever the change actually needs seen.

## Notes

- This app has no headless/CI screenshot path — it's a real Win32 window, so this needs an
  actual interactive Windows session (the user's own machine), not a sandboxed/CI container.
- 20 dummy projectors (`192.168.0.10`–`.29`) are typically already in the open project when
  testing locally — fine for layout/theme checks; they'll show Offline since they're not real
  hardware.
- Don't close the app or kill the process unless asked — the user may have it open for their
  own testing too.
