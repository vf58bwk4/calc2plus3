<#
.SYNOPSIS
Plays the README demo scenario in calc2plus3, records it with ffmpeg and converts it to a GIF.

.DESCRIPTION
Exit calc2plus3 from the tray menu first. Do not use the mouse or keyboard while the script runs.
The script moves %APPDATA%\calc2plus3 aside, records with empty data, then restores the folder.
Run it in a new process: pwsh -NoProfile -File tools\record-demo.ps1
#>
param(
    [string] $Exe = "$PSScriptRoot\..\build\calc2plus3.exe",
    [string] $OutDir = "$PSScriptRoot\..\build\demo",
    [int] $Fps = 15,
    # Values above 1 make all pauses and typing faster.
    [double] $Speed = 1.0,
    # Physical pixels at the current DPI; 27 at 125%.
    [int] $RowHeight = 27
)
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class DemoInput
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr dwExtraInfo; }
    [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr dwExtraInfo; }
    [StructLayout(LayoutKind.Explicit)] struct INPUTUNION { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
    [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public INPUTUNION u; }

    public class Child { public IntPtr Handle; public string Class; public RECT Rect; }

    delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);

    [DllImport("user32.dll")] static extern uint SendInput(uint count, INPUT[] inputs, int size);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr value);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc proc, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc proc, IntPtr lParam);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] static extern IntPtr GetParent(IntPtr hwnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd, StringBuilder s, int n);
    [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr hwnd, int attr, out RECT r, int size);

    const uint INPUT_MOUSE = 0, INPUT_KEYBOARD = 1;
    const uint KEYEVENTF_EXTENDEDKEY = 1, KEYEVENTF_KEYUP = 2, KEYEVENTF_UNICODE = 4;
    const uint MOUSEEVENTF_LEFTDOWN = 2, MOUSEEVENTF_LEFTUP = 4;

    static string Text(IntPtr hwnd) { var s = new StringBuilder(256); GetWindowText(hwnd, s, s.Capacity); return s.ToString(); }
    static string ClassOf(IntPtr hwnd) { var s = new StringBuilder(256); GetClassName(hwnd, s, s.Capacity); return s.ToString(); }

    public static IntPtr FindVisibleWindow(int pid, string title)
    {
        IntPtr found = IntPtr.Zero;
        EnumWindows((h, l) =>
        {
            uint p;
            GetWindowThreadProcessId(h, out p);
            if (p == pid && IsWindowVisible(h) && Text(h) == title) { found = h; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static List<Child> Children(IntPtr parent)
    {
        var list = new List<Child>();
        EnumChildWindows(parent, (h, l) =>
        {
            if (GetParent(h) == parent)
            {
                RECT r;
                GetWindowRect(h, out r);
                list.Add(new Child { Handle = h, Class = ClassOf(h), Rect = r });
            }
            return true;
        }, IntPtr.Zero);
        return list;
    }

    // The visible frame, without the invisible resize borders that GetWindowRect includes.
    public static RECT FrameRect(IntPtr hwnd)
    {
        RECT r;
        if (DwmGetWindowAttribute(hwnd, 9, out r, Marshal.SizeOf(typeof(RECT))) != 0) { GetWindowRect(hwnd, out r); }
        return r;
    }

    static INPUT Key(ushort vk, ushort scan, uint flags)
    {
        var i = new INPUT { type = INPUT_KEYBOARD };
        i.u.ki = new KEYBDINPUT { wVk = vk, wScan = scan, dwFlags = flags };
        return i;
    }

    static uint Extended(ushort vk) { return (vk >= 0x21 && vk <= 0x28) || vk == 0x2D || vk == 0x2E ? KEYEVENTF_EXTENDEDKEY : 0; }

    static void Send(List<INPUT> inputs) { SendInput((uint)inputs.Count, inputs.ToArray(), Marshal.SizeOf(typeof(INPUT))); }

    public static void Chord(ushort[] keys)
    {
        var inputs = new List<INPUT>();
        foreach (var vk in keys) { inputs.Add(Key(vk, 0, Extended(vk))); }
        for (int k = keys.Length - 1; k >= 0; k--) { inputs.Add(Key(keys[k], 0, Extended(keys[k]) | KEYEVENTF_KEYUP)); }
        Send(inputs);
    }

    public static void Char(char c)
    {
        Send(new List<INPUT> { Key(0, c, KEYEVENTF_UNICODE), Key(0, c, KEYEVENTF_UNICODE | KEYEVENTF_KEYUP) });
    }

    public static void LeftClick()
    {
        var down = new INPUT { type = INPUT_MOUSE };
        down.u.mi = new MOUSEINPUT { dwFlags = MOUSEEVENTF_LEFTDOWN };
        var up = new INPUT { type = INPUT_MOUSE };
        up.u.mi = new MOUSEINPUT { dwFlags = MOUSEEVENTF_LEFTUP };
        Send(new List<INPUT> { down, up });
    }
}
'@

# ffmpeg captures physical pixels, so all coordinates here must be physical too.
[void][DemoInput]::SetProcessDpiAwarenessContext([IntPtr]::new(-4))

$VirtualKeys = @{
    Ctrl = 0x11; Alt = 0x12; Shift = 0x10; Enter = 0x0D; Esc = 0x1B; Backspace = 0x08; Tab = 0x09
    Up = 0x26; Down = 0x28; Delete = 0x2E; NumPlus = 0x6B; NumMinus = 0x6D; K = 0x4B; Y = 0x59; Z = 0x5A
}
$AppTitle = '2 + 3'
$DataDir = Join-Path $env:APPDATA 'calc2plus3'
$RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$Padding = 28
$CaptionHeight = 64

function Wait-Ms([int] $Ms) {
    $end = [DateTime]::UtcNow.AddMilliseconds($Ms / $Speed)
    while ([DateTime]::UtcNow -lt $end) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 10
    }
}

function Send-Keys([string] $Chord) {
    [DemoInput]::Chord([uint16[]]@($Chord -split '\+' | ForEach-Object { $VirtualKeys[$_] }))
    Wait-Ms 150
}

function Send-Text([string] $Text) {
    foreach ($c in $Text.ToCharArray()) {
        [DemoInput]::Char($c)
        Wait-Ms 110
    }
}

function Move-Mouse([int] $X, [int] $Y) {
    $from = [DemoInput+POINT]::new()
    [void][DemoInput]::GetCursorPos([ref] $from)
    $steps = 20
    for ($i = 1; $i -le $steps; $i++) {
        $t = $i / $steps
        $t = $t * $t * (3 - 2 * $t)
        [void][DemoInput]::SetCursorPos([int]($from.X + ($X - $from.X) * $t), [int]($from.Y + ($Y - $from.Y) * $t))
        Wait-Ms 15
    }
}

function Click-At([int] $X, [int] $Y, [switch] $Double) {
    Move-Mouse $X $Y
    Wait-Ms 150
    [DemoInput]::LeftClick()
    if ($Double) {
        Start-Sleep -Milliseconds 60
        [DemoInput]::LeftClick()
    }
    Wait-Ms 250
}

function Show-Caption([string] $Text) {
    $script:Caption.Text = $Text
    $script:Caption.Refresh()
    Wait-Ms 700
}

function Get-Controls([IntPtr] $Window) {
    $children = @([DemoInput]::Children($Window))
    $edits = @($children | Where-Object Class -eq 'Edit' | Sort-Object { $_.Rect.Left })
    $grids = @($children | Where-Object { $_.Class -ne 'Edit' -and $_.Class -notmatch 'statusbar' -and ($_.Rect.Bottom - $_.Rect.Top) -gt 100 } |
        Sort-Object { $_.Rect.Top })
    if ($edits.Count -ne 2 -or $grids.Count -ne 2) {
        throw "Unexpected window layout: $(($children | ForEach-Object Class) -join ', ')"
    }
    [pscustomobject]@{ VarName = $edits[0].Rect; Expression = $edits[1].Rect; History = $grids[0].Rect; VarList = $grids[1].Rect }
}

function Wait-WindowVisible([int] $ProcessId, [bool] $Visible) {
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    while ([DateTime]::UtcNow -lt $deadline) {
        $hwnd = [DemoInput]::FindVisibleWindow($ProcessId, $AppTitle)
        if (($hwnd -ne [IntPtr]::Zero) -eq $Visible) { return $hwnd }
        Wait-Ms 100
    }
    throw "The '$AppTitle' window did not become $(if ($Visible) { 'visible' } else { 'hidden' })."
}

function Invoke-Scenario($Controls, [int] $ProcessId) {
    $c = $Controls
    $clickVarName = { Click-At ($c.VarName.Left + 20) (($c.VarName.Top + $c.VarName.Bottom) / 2) }
    $clickExpression = { Click-At ($c.Expression.Right - 20) (($c.Expression.Top + $c.Expression.Bottom) / 2) }
    $clearExpression = { Send-Keys Esc; Send-Keys Esc }

    Show-Caption 'Alt+K shows 2 + 3 from anywhere'
    Send-Keys Alt+K
    $hwnd = Wait-WindowVisible $ProcessId $true
    [void][DemoInput]::SetForegroundWindow($hwnd)
    Wait-Ms 900

    Show-Caption 'Type an expression, press Enter'
    Send-Text '2+3'
    Wait-Ms 400
    Send-Keys Enter
    Wait-Ms 1200

    Show-Caption 'The result stays: keep calculating'
    Send-Text '*12'
    Wait-Ms 400
    Send-Keys Enter
    Wait-Ms 1200

    Show-Caption 'Esc twice clears the line'
    & $clearExpression
    Wait-Ms 600

    Show-Caption 'Functions and powers'
    Send-Text 'sqrt(2^10)'
    Wait-Ms 400
    Send-Keys Enter
    Wait-Ms 1200

    Show-Caption 'Type a variable name'
    & $clickVarName
    Send-Keys Ctrl+Backspace
    Send-Text 'rate'
    Wait-Ms 600

    Show-Caption 'Ctrl+Enter stores the result in it'
    & $clickExpression
    & $clearExpression
    Send-Text '1.25'
    Wait-Ms 400
    Send-Keys Ctrl+Enter
    Wait-Ms 1200

    Show-Caption 'Use variables in expressions'
    & $clearExpression
    Send-Text '96*rate'
    Wait-Ms 400
    Send-Keys Enter
    Wait-Ms 1200

    Show-Caption 'Ctrl++ adds the result to a variable'
    & $clickVarName
    Send-Keys Ctrl+Backspace
    Send-Text 'total'
    & $clickExpression
    Wait-Ms 300
    Send-Keys Ctrl+NumPlus
    Wait-Ms 1000
    & $clearExpression
    Send-Text '35'
    Wait-Ms 400
    Send-Keys Ctrl+NumPlus
    Wait-Ms 1200

    Show-Caption 'Double-click History to insert a value'
    & $clearExpression
    Send-Text 'total-'
    # Row 2 holds 32, the result of sqrt(2^10).
    Click-At ($c.History.Left + 40) ($c.History.Top + 2 + 2 * $RowHeight + $RowHeight / 2) -Double
    Wait-Ms 600
    Send-Keys Enter
    Wait-Ms 1500

    Show-Caption 'Esc on an empty line hides it to the tray'
    & $clearExpression
    Wait-Ms 500
    Send-Keys Esc
    Wait-Ms 1500
}

if (Get-Process -Name calc2plus3 -ErrorAction SilentlyContinue) {
    throw 'calc2plus3 is running. Exit it from the tray menu, then run this script again.'
}
$Exe = (Resolve-Path $Exe).Path
$ffmpeg = Join-Path $env:USERPROFILE 'scoop\apps\ffmpeg\current\bin\ffmpeg.exe'
if (-not (Test-Path $ffmpeg)) { $ffmpeg = (Get-Command ffmpeg).Source }
$leftover = Get-ChildItem $env:APPDATA -Directory -Filter 'calc2plus3.demo-backup-*'
if ($leftover) {
    throw "A backup from an earlier run exists: $($leftover[0].FullName). Restore it to $DataDir first."
}
New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$video = Join-Path $OutDir 'demo.mkv'
$gif = Join-Path $OutDir 'demo.gif'

$backup = Join-Path $env:APPDATA ('calc2plus3.demo-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$runValue = (Get-ItemProperty -Path $RunKey -Name calc2plus3 -ErrorAction SilentlyContinue).calc2plus3
$app = $null
$recorder = $null
$form = $null
$isolated = $false
try {
    if (Test-Path $DataDir) { Move-Item $DataDir $backup }
    $isolated = $true

    # With no data the first start is hidden. Alt+K is lost until the app registers it.
    $app = Start-Process -FilePath $Exe -PassThru
    $hwnd = [IntPtr]::Zero
    for ($try = 0; $try -lt 10 -and $hwnd -eq [IntPtr]::Zero; $try++) {
        Wait-Ms 1000
        Send-Keys Alt+K
        Wait-Ms 500
        $hwnd = [DemoInput]::FindVisibleWindow($app.Id, $AppTitle)
    }
    if ($hwnd -eq [IntPtr]::Zero) { throw "The '$AppTitle' window did not appear." }
    [void][DemoInput]::SetForegroundWindow($hwnd)

    $window = [DemoInput+RECT]::new()
    [void][DemoInput]::GetWindowRect($hwnd, [ref] $window)
    $frame = [DemoInput]::FrameRect($hwnd)
    $left = 40 + $Padding
    $top = 40 + $Padding
    [void][DemoInput]::SetWindowPos($hwnd, [IntPtr]::Zero, $left - ($frame.Left - $window.Left), $top - ($frame.Top - $window.Top), 0, 0, 0x15)
    Wait-Ms 300
    $frame = [DemoInput]::FrameRect($hwnd)
    $controls = Get-Controls $hwnd

    $width = ($frame.Right - $frame.Left) + 2 * $Padding
    $height = ($frame.Bottom - $frame.Top) + 2 * $Padding + $CaptionHeight
    $width += $width % 2
    $height += $height % 2
    $form = [System.Windows.Forms.Form]::new()
    $form.FormBorderStyle = 'None'
    $form.ShowInTaskbar = $false
    $form.StartPosition = 'Manual'
    $form.BackColor = [System.Drawing.Color]::FromArgb(0, 128, 116)
    $script:Caption = [System.Windows.Forms.Label]::new()
    $script:Caption.Dock = 'Bottom'
    $script:Caption.Height = $CaptionHeight
    $script:Caption.TextAlign = 'MiddleCenter'
    $script:Caption.ForeColor = [System.Drawing.Color]::White
    $script:Caption.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 22, [System.Drawing.GraphicsUnit]::Pixel)
    $form.Controls.Add($script:Caption)
    $form.Show()
    $form.Bounds = [System.Drawing.Rectangle]::new($frame.Left - $Padding, $frame.Top - $Padding, $width, $height)
    Wait-Ms 200
    $area = $form.Bounds

    # Hide the window, so that the recording starts with Alt+K.
    [void][DemoInput]::SetForegroundWindow($hwnd)
    for ($i = 0; $i -lt 4 -and [DemoInput]::IsWindowVisible($hwnd); $i++) { Send-Keys Esc }
    [void](Wait-WindowVisible $app.Id $false)
    $form.Activate()
    [void][DemoInput]::SetCursorPos($area.Right + 60, $area.Bottom - 120)
    Wait-Ms 300

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new($ffmpeg)
    foreach ($arg in '-hide_banner', '-loglevel', 'error', '-y', '-f', 'gdigrab', '-framerate', "$Fps", '-draw_mouse', '1',
        '-offset_x', "$($area.Left)", '-offset_y', "$($area.Top)", '-video_size', "$($area.Width)x$($area.Height)",
        '-i', 'desktop', '-c:v', 'libx264rgb', '-crf', '0', '-preset', 'ultrafast', $video) {
        $startInfo.ArgumentList.Add($arg)
    }
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $recorder = [System.Diagnostics.Process]::Start($startInfo)
    Wait-Ms 1500

    Invoke-Scenario $controls $app.Id

    Show-Caption ''
    Wait-Ms 500
    $recorder.StandardInput.Write('q')
    $recorder.StandardInput.Flush()
    if (-not $recorder.WaitForExit(30000)) { throw 'ffmpeg did not stop.' }
}
finally {
    if ($recorder -and -not $recorder.HasExited) { $recorder.Kill() }
    if ($form) { $form.Close() }
    if ($app -and -not $app.HasExited) {
        Stop-Process -Id $app.Id -Force
        $app.WaitForExit(10000) | Out-Null
    }
    if ($isolated) {
        if (Test-Path $DataDir) { Remove-Item -Recurse -Force $DataDir }
        if (Test-Path $backup) { Move-Item $backup $DataDir }
    }
    if ($null -eq $runValue) {
        Remove-ItemProperty -Path $RunKey -Name calc2plus3 -ErrorAction SilentlyContinue
    }
    else {
        Set-ItemProperty -Path $RunKey -Name calc2plus3 -Value $runValue
    }
}

# Few colors and no dithering keep the UI text sharp; diff_mode redraws only the changed rectangle.
& $ffmpeg -hide_banner -loglevel error -y -i $video -filter_complex `
    "[0:v]split[a][b];[a]palettegen=stats_mode=diff:max_colors=128[p];[b][p]paletteuse=dither=none:diff_mode=rectangle" `
    -loop 0 $gif
if ($LASTEXITCODE -ne 0) { throw "GIF conversion failed with exit code $LASTEXITCODE." }
'{0} ({1:N0} KB)' -f $gif, ((Get-Item $gif).Length / 1KB)
