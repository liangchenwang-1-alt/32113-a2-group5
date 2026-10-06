# 32113 A2 - desktop UI helper (screen capture + simulated mouse/keyboard).
#
# WHY THIS EXISTS: the user explicitly asked for help driving the browser UI on THEIR machine
# ("用我的电脑进行点击，绕过你接入的输入"). Chromium/Edge does not expose its accessibility tree to
# UI Automation on this machine, so we act on screen coordinates derived from screenshots.
#
# This script ONLY simulates input and captures the screen. It does not install anything, does not
# change any system setting, and does not touch the lab containers or data.
#
# Usage:
#   powershell -File .\ui.ps1 -Action shot  -Out <file.png> [-Region "l,t,w,h"]
#   powershell -File .\ui.ps1 -Action click -X <n> -Y <n> [-Double]
#   powershell -File .\ui.ps1 -Action move  -X <n> -Y <n>
#   powershell -File .\ui.ps1 -Action keys  -Text "<text>"      # types text into the focused window
#   powershell -File .\ui.ps1 -Action key   -Key "ENTER"        # sends a single special key
#   powershell -File .\ui.ps1 -Action focus -WindowTitle "..."  # bring a window to the front
#   powershell -File .\ui.ps1 -Action cursor                   # report current cursor position

param(
  [Parameter(Mandatory = $true)][ValidateSet('shot', 'click', 'move', 'keys', 'key', 'focus', 'focushwnd', 'cursor')][string]$Action,
  [string]$Out,
  [string]$Region,
  [int]$X = -1,
  [int]$Y = -1,
  [switch]$Double,
  [string]$Text,
  [string]$Key,
  [string]$WindowTitle
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class UIWin {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
  public const uint LEFTDOWN = 0x0002;
  public const uint LEFTUP   = 0x0004;
}
"@

function Get-Screenshot([string]$path, $rect) {
  if (-not $rect) { $rect = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds }
  $bmp = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($rect.X, $rect.Y, 0, 0, $bmp.Size)
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  return (Get-Item -LiteralPath $path).Length
}

switch ($Action) {
  'cursor' {
    $p = New-Object UIWin+POINT
    [void][UIWin]::GetCursorPos([ref]$p)
    Write-Output ("cursor: X={0} Y={1}" -f $p.X, $p.Y)
  }
  'focus' {
    $proc = Get-Process | Where-Object { $_.MainWindowTitle -like "*$WindowTitle*" } | Select-Object -First 1
    if (-not $proc) { throw "no window matching '$WindowTitle'" }
    [void][UIWin]::ShowWindow($proc.MainWindowHandle, 9)
    [void][UIWin]::SetForegroundWindow($proc.MainWindowHandle)
    Start-Sleep -Milliseconds 700
    Write-Output ("focused: [{0}] {1}  hwnd={2}" -f $proc.ProcessName, $proc.MainWindowTitle, $proc.MainWindowHandle)
  }
  'focushwnd' {
    # focus by explicit window handle (most reliable: Edge's MainWindowTitle can change/disappear)
    $handle = [IntPtr]$X
    [void][UIWin]::ShowWindow($handle, 9)
    [void][UIWin]::SetForegroundWindow($handle)
    Start-Sleep -Milliseconds 800
    Write-Output ("foreground now: {0} (wanted {1})" -f [UIWin]::GetForegroundWindow(), $handle)
  }
  'shot' {
    $rect = $null
    if ($Region) {
      $p = $Region -split ','
      $rect = New-Object System.Drawing.Rectangle([int]$p[0], [int]$p[1], [int]$p[2], [int]$p[3])
    }
    $len = Get-Screenshot $Out $rect
    Write-Output ("saved: {0} ({1} bytes)" -f $Out, $len)
  }
  'move' {
    [void][UIWin]::SetCursorPos($X, $Y)
    Start-Sleep -Milliseconds 200
    Write-Output ("moved to {0},{1}" -f $X, $Y)
  }
  'click' {
    [void][UIWin]::SetCursorPos($X, $Y)
    Start-Sleep -Milliseconds 350
    [UIWin]::mouse_event([UIWin]::LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [UIWin]::mouse_event([UIWin]::LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
    if ($Double) {
      Start-Sleep -Milliseconds 90
      [UIWin]::mouse_event([UIWin]::LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
      Start-Sleep -Milliseconds 60
      [UIWin]::mouse_event([UIWin]::LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
    }
    Start-Sleep -Milliseconds 500
    Write-Output ("clicked {0},{1}{2}" -f $X, $Y, $(if ($Double) { ' (double)' } else { '' }))
  }
  'keys' {
    [System.Windows.Forms.SendKeys]::SendWait($Text)
    Start-Sleep -Milliseconds 300
    Write-Output ("typed: {0} chars" -f $Text.Length)
  }
  'key' {
    [System.Windows.Forms.SendKeys]::SendWait($Key)
    Start-Sleep -Milliseconds 400
    Write-Output ("sent key: {0}" -f $Key)
  }
}
