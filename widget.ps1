# One-line always-on-top usage bar for Claude + Codex, light blue theme with a butterfly icon.
# Hover for reset times and today's tokens. Drag to move. ⟳ refresh, ✕ shrink to the butterfly
# (click it to open again). Right-click → Exit really closes it.
# Polls usage-json.js in the background every 60 s so the UI never freezes.
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# One widget at a time: launching it again (Start menu, Startup) while it runs tells the running one
# to come back (open, on top, on screen) instead of starting a second copy.
$wake = New-Object Threading.EventWaitHandle($false, 'AutoReset', 'Local\AIUsageWidgetShow')
$single = New-Object Threading.Mutex($false, 'Local\AIUsageWidget')
try { if (-not $single.WaitOne(0)) { [void]$wake.Set(); exit } } catch [Threading.AbandonedMutexException] {}
# The command center (Desktop\ai\command-center) hides it for a clean screen and reads whether it is on screen.
$hideSignal = New-Object Threading.EventWaitHandle($false, 'AutoReset', 'Local\AIUsageWidgetHide')
$visibleFlag = New-Object Threading.EventWaitHandle($false, 'ManualReset', 'Local\AIUsageWidgetVisible')

$script = Join-Path $PSScriptRoot 'usage-json.js'
$posFile = Join-Path $env:USERPROFILE '.claude\usage-widget-pos.txt'
$modeFile = Join-Path $env:USERPROFILE '.claude\usage-widget-mode.txt'
$layoutFile = Join-Path $env:USERPROFILE '.claude\usage-widget-layout.txt'

# Holding the butterfly cycles the shape: one-line bar, stacked (vertical) panel, square. Remembered too.
$layouts = 'horizontal', 'vertical', 'square'
$script:layout = 'horizontal'
if (Test-Path $layoutFile) {
  $saved = (Get-Content $layoutFile -Raw).Trim()
  if ($saved -in $layouts) { $script:layout = $saved }
}

# Which products to show: 'both', 'claude' or 'codex'. Remembered across restarts.
$script:mode = 'both'
if (Test-Path $modeFile) {
  $saved = (Get-Content $modeFile -Raw).Trim()
  if ($saved -in 'both', 'claude', 'codex') { $script:mode = $saved }
}

$W = 520; $H = 32; $BTN = 52   # $W is refitted to the content on first paint; $BTN = ⟳ ✕ area
$bg     = [Drawing.Color]::FromArgb(234, 245, 255)   # light blue
$track  = [Drawing.Color]::White                     # bar track
$accent = [Drawing.Color]::FromArgb(110, 175, 235)   # soft blue: bar fill, trim, separator
$warn   = [Drawing.Color]::FromArgb(235, 135, 50)
$danger = [Drawing.Color]::FromArgb(210, 30, 60)
$ink    = [Drawing.Color]::FromArgb(30, 70, 115)     # navy text
$muted  = [Drawing.Color]::FromArgb(100, 135, 170)
$wing   = [Drawing.Color]::FromArgb(160, 210, 250)   # butterfly wings
$wing2  = [Drawing.Color]::FromArgb(70, 145, 215)

$fBold  = New-Object Drawing.Font('Segoe UI Semibold', 9)
$fText  = New-Object Drawing.Font('Segoe UI', 9)
$fSmall = New-Object Drawing.Font('Segoe UI', 7.5)

$form = New-Object Windows.Forms.Form
$form.FormBorderStyle = 'None'
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.BackColor = $bg
$form.Size = New-Object Drawing.Size($W, $H)
$form.StartPosition = 'Manual'
$wa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Location = New-Object Drawing.Point(($wa.Right - $W - 12), ($wa.Bottom - $H - 12))
if (Test-Path $posFile) {
  $xy = (Get-Content $posFile) -split ','
  $form.Location = New-Object Drawing.Point([int]$xy[0], [int]$xy[1])
}
$form.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'Instance,NonPublic').SetValue($form, $true)

$tip = New-Object Windows.Forms.ToolTip
$tip.InitialDelay = 300
$tip.AutoPopDelay = 20000

$script:data = $null
$script:updatedAt = $null

function Brush($c) { New-Object Drawing.SolidBrush $c }

function Level-Color($pct) {
  if ($pct -ge 90) { return $danger }
  if ($pct -ge 70) { return $warn }
  return $accent
}

function Reset-Text($resetsAt, $weekly) {
  if (-not $resetsAt) { return '' }
  $at = [DateTimeOffset]::FromUnixTimeSeconds([long]$resetsAt).LocalDateTime
  $fmt = if ($weekly -or $at.Date -ne (Get-Date).Date) { 'ddd d MMM h:mm tt' } else { 'h:mm tt' }
  return 'resets ' + $at.ToString($fmt, [Globalization.CultureInfo]::InvariantCulture)
}

function Short-Num($n) {
  if ($n -ge 1e9) { return ('{0:0.#}B' -f ($n / 1e9)) }
  if ($n -ge 1e8) { return ('{0:0}M' -f ($n / 1e6)) }
  if ($n -ge 1e6) { return ('{0:0.#}M' -f ($n / 1e6)) }
  if ($n -ge 1e3) { return ('{0:0.#}K' -f ($n / 1e3)) }
  return "$n"
}

# Butterfly icon: two upper wings, two smaller lower wings, body and antennae.
function Draw-Butterfly($g, $cx, $cy) {
  $edge = New-Object Drawing.Pen $wing2, 1
  # Ellipse of size w x h centred at offset (dx, dy) from the body, tilted by $angle degrees.
  $wingAt = {
    param($dx, $dy, $w, $h, $angle)
    $g.TranslateTransform(($cx + $dx), ($cy + $dy))
    $g.RotateTransform($angle)
    $g.FillEllipse((Brush $wing), (-$w / 2), (-$h / 2), $w, $h)
    $g.DrawEllipse($edge, (-$w / 2), (-$h / 2), $w, $h)
    $g.ResetTransform()
  }
  & $wingAt -4.5 -3 8 10 -35   # upper left
  & $wingAt  4.5 -3 8 10  35   # upper right
  & $wingAt -3.5  4 6 7   30   # lower left
  & $wingAt  3.5  4 6 7  -30   # lower right
  $g.FillEllipse((Brush $ink), ($cx - 1), ($cy - 6), 2, 12)
  $antenna = New-Object Drawing.Pen $ink, 1
  $g.DrawLine($antenna, $cx, ($cy - 5), ($cx - 3), ($cy - 9))
  $g.DrawLine($antenna, $cx, ($cy - 5), ($cx + 3), ($cy - 9))
}

# Text widths are measured, not assumed, so the layout survives display scaling.
function TextW($g, $s, $f) { [int][Math]::Ceiling($g.MeasureString($s, $f).Width) }
# Vertical centre within a row that starts at $y and is $rh tall (default: one bar row).
function TextY($g, $f, $y = 0, $rh = $script:rowH) { [int]($y + ($rh - $g.MeasureString('0', $f).Height) / 2) }

# Compact reset clock time: "↻6:50AM" for the session, "↻Fri 3:00AM" for the week.
function Short-Reset($resetsAt, $weekly) {
  if (-not $resetsAt) { return '' }
  $at = [DateTimeOffset]::FromUnixTimeSeconds([long]$resetsAt).LocalDateTime
  $fmt = if ($weekly) { 'ddd h:mmtt' } else { 'h:mmtt' }
  return '↻' + $at.ToString($fmt, [Globalization.CultureInfo]::InvariantCulture)
}

# "5h ▬▬▬ 41% ↻4h09" — returns the x after it.
# $stale: numbers are last-known from local logs, not live — drawn grey with a "?" so they can't pass for live.
function Draw-Window($g, $x, $y, $label, $win, $weekly, $stale) {
  $g.DrawString($label, $fSmall, (Brush $muted), $x, (TextY $g $fSmall $y))
  $x += (TextW $g $label $fSmall)
  $barY = [int]($y + $script:rowH / 2) - 3
  $g.FillRectangle((Brush $track), $x, $barY, 40, 6)
  if ($win) {
    $fill = if ($stale) { $muted } else { Level-Color $win.pct }
    $g.FillRectangle((Brush $fill), $x, $barY, [int](40 * [Math]::Min(100, $win.pct) / 100), 6)
    $txt = "$($win.pct)%" + $(if ($stale) { '?' })
  } else { $txt = '—' }
  $x += 42
  $pctColor = if ($stale) { $muted } elseif ([int]$win.pct -ge 70) { Level-Color ([int]$win.pct) } else { $ink }
  $g.DrawString($txt, $fText, (Brush $pctColor), $x, (TextY $g $fText $y))
  $x += (TextW $g '100%?' $fText)
  # Fixed slot sized for the widest label, so the bar doesn't jiggle as the countdown changes.
  $widest = if ($weekly) { '↻Wed 12:59PM' } else { '↻12:59PM' }
  if ($win) { $g.DrawString((Short-Reset $win.resetsAt $weekly), $fSmall, (Brush $muted), $x, (TextY $g $fSmall $y)) }
  return $x + (TextW $g $widest $fSmall) + 8
}

# The billing-month row (mo): Month-*, Draw-Month, Draw-MonthRing.
. (Join-Path $PSScriptRoot 'lib\month.ps1')

$centre = New-Object Drawing.StringFormat
$centre.Alignment = 'Center'
$centre.LineAlignment = 'Center'
function Draw-Centered($g, $s, $f, $color, $x, $y, $w, $h) {
  $g.DrawString($s, $f, (Brush $color), (New-Object Drawing.RectangleF($x, $y, $w, $h)), $centre)
}

# Square layout gauge: a ring filling clockwise from the top, % inside, reset clock time below.
function Draw-Ring($g, $x, $y, $w, $d, $win, $weekly, $stale) {
  $rx = $x + [int](($w - $d) / 2)
  $g.DrawEllipse((New-Object Drawing.Pen $track, 5), $rx, $y, $d, $d)
  if ($win) {
    $fill = if ($stale) { $muted } else { Level-Color $win.pct }
    $g.DrawArc((New-Object Drawing.Pen $fill, 5), $rx, $y, $d, $d, -90, [float](360 * [Math]::Min(100, $win.pct) / 100))
    $txt = "$($win.pct)%" + $(if ($stale) { '?' })
  } else { $txt = '—' }
  $color = if ($stale) { $muted } elseif ([int]$win.pct -ge 70) { Level-Color ([int]$win.pct) } else { $ink }
  Draw-Centered $g $txt $fSmall $color $x $y $w $d
  if ($win.resetsAt) { Draw-Centered $g (Short-Reset $win.resetsAt $weekly) $fSmall $muted $x ($y + $d + 2) $w 16 }
}

# Older than 6 min: Claude's API is only asked every 5 min, so anything past that is a missed update.
function Is-Stale($usage) {
  if (-not $usage) { return $false }
  if (-not $usage.asOf) { return $true }
  return ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [double]$usage.asOf) -gt 360
}

function Draw-Section($g, $x, $name, $usage) {
  $g.DrawString($name, $fBold, (Brush $ink), $x, (TextY $g $fBold))
  $x += (TextW $g $name $fBold) + 4
  $stale = Is-Stale $usage
  $x = Draw-Window $g $x 0 '5h' $usage.fiveHour $false $stale
  $x = Draw-Window $g $x 0 '7d' $usage.weekly $true $stale
  return $x
}

$form.Add_Paint({
  $g = $_.Graphics
  $g.SmoothingMode = 'AntiAlias'
  $g.TextRenderingHint = 'ClearTypeGridFit'
  # The one-line bar's real height (display scaling can make it differ from $H), taken before any
  # layout switch changes the window height. One row is that minus the trim; helper functions see it.
  if (-not $script:barH) { $script:barH = $form.ClientSize.Height }
  $rh = $script:rowH = $script:barH - 4
  # Blue trim along the bottom.
  $g.FillRectangle((Brush $accent), 0, ($form.ClientSize.Height - 4), $form.ClientSize.Width, 4)
  Draw-Butterfly $g 16 ([int]($rh / 2) + 1)

  $d = $script:data
  $sections = @()
  if ($script:mode -ne 'codex') { $sections += , @('Claude', $d.claude, $d.month.claude) }
  if ($script:mode -ne 'claude') { $sections += , @('Codex', $d.codex, $d.month.codex) }
  $wantH = $script:barH

  if ($script:collapsed) {
    $wantW = 32   # butterfly only
  } elseif ($script:layout -eq 'square') {
    # Ring gauges: a column per product, a row per window (5h, 7d) plus the billing month. The panel is kept square.
    $labelW = 20; $cellW = 76; $ringD = 44; $cellH = $ringD + 20; $nameH = 18
    $gridW = $labelW + $cellW * $sections.Count
    $side = [Math]::Max($gridW + 16, $rh + $nameH + 3 * $cellH + 8)
    $x0 = [int](($form.ClientSize.Width - $gridW) / 2)
    for ($i = 0; $i -lt $sections.Count; $i++) {
      Draw-Centered $g $sections[$i][0] $fBold $ink ($x0 + $labelW + $i * $cellW) $rh $cellW $nameH
    }
    $y = $rh + $nameH
    foreach ($row in @(@('5h', 'fiveHour', $false), @('7d', 'weekly', $true))) {
      $g.DrawString($row[0], $fSmall, (Brush $muted), $x0, (TextY $g $fSmall $y $ringD))
      for ($i = 0; $i -lt $sections.Count; $i++) {
        $usage = $sections[$i][1]
        Draw-Ring $g ($x0 + $labelW + $i * $cellW) $y $cellW $ringD $usage.($row[1]) $row[2] (Is-Stale $usage)
      }
      $y += $cellH
    }
    $g.DrawString('mo', $fSmall, (Brush $muted), $x0, (TextY $g $fSmall $y $ringD))
    for ($i = 0; $i -lt $sections.Count; $i++) {
      Draw-MonthRing $g ($x0 + $labelW + $i * $cellW) $y $cellW $ringD $sections[$i][2]
    }
    $wantW = $wantH = $side
    $bx = $form.ClientSize.Width - $BTN
  } elseif ($script:layout -eq 'vertical') {
    # Stacked: butterfly and ⟳ ✕ on top, then per product a name row and its 5h / 7d rows.
    $y = $rh; $maxX = 0
    for ($i = 0; $i -lt $sections.Count; $i++) {
      $name, $usage, $month = $sections[$i]
      if ($i) { $g.FillRectangle((Brush $accent), 10, ($y + 2), ($form.ClientSize.Width - 20), 1); $y += 5 }
      $g.DrawString($name, $fBold, (Brush $ink), 10, (TextY $g $fBold $y 20)); $y += 20
      $stale = Is-Stale $usage
      $maxX = [Math]::Max($maxX, (Draw-Window $g 12 $y '5h' $usage.fiveHour $false $stale)); $y += $rh
      $maxX = [Math]::Max($maxX, (Draw-Window $g 12 $y '7d' $usage.weekly $true $stale)); $y += $rh
      $maxX = [Math]::Max($maxX, (Draw-Month $g 12 $y $month)); $y += $rh
    }
    $wantW = [Math]::Max($maxX, 32 + $BTN)
    $wantH = $y + 4
    $bx = $form.ClientSize.Width - $BTN
  } else {
    $x = 32
    for ($i = 0; $i -lt $sections.Count; $i++) {
      if ($i) { $g.FillRectangle((Brush $accent), ($x - 3), 7, 1, ($rh - 14)); $x += 6 }
      $x = Draw-Section $g $x $sections[$i][0] $sections[$i][1]
    }
    $wantW = $x + $BTN
    $bx = $x
  }
  if (-not $script:collapsed) {
    $ty = TextY $g $fText
    $g.DrawString('⟳', $fText, (Brush $ink), ($bx + 2), $ty)
    $g.DrawString('✕', $fText, (Brush $ink), ($bx + 26), $ty)
  }

  # Fit the window to its content (one resize, then it's stable).
  # Grow leftwards so ⟳ ✕ stay put, and never past the screen edge.
  # Right after a layout switch the bottom edge stays put instead of the top.
  # The very first fit keeps the saved top-left corner instead (the window opened at a placeholder width).
  if ($wantW -ne $form.ClientSize.Width -or $wantH -ne $form.ClientSize.Height -or -not $script:placed) {
    $right = if ($script:placed) { $form.Right } else { $form.Left + $form.Width - $form.ClientSize.Width + $wantW }
    $script:placed = $true
    $bottom = $script:anchorBottom
    $form.ClientSize = New-Object Drawing.Size($wantW, $wantH)
    if ($bottom) { $form.Top = $bottom - $form.Height }
    Keep-OnScreen $right
    # A layout switch moved the top-left corner, so a restart must reopen it here, not where it was.
    if ($bottom) { try { "$($form.Left),$($form.Top)" | Set-Content $posFile } catch {} }
  }
  $script:anchorBottom = $null
  $script:W = $form.ClientSize.Width
})

function Keep-OnScreen($right) {
  $area = [Windows.Forms.Screen]::FromControl($form).WorkingArea
  $left = [Math]::Min($right, $area.Right) - $form.Width
  $top = [Math]::Min([Math]::Max($form.Top, $area.Top), $area.Bottom - $form.Height)
  $form.Location = New-Object Drawing.Point([Math]::Max($area.Left, $left), $top)
}

Add-Type -Namespace Widget -Name Z -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);'
# Back to the top of the always-on-top band without moving, resizing or stealing focus.
function Pin-OnTop { [void][Widget.Z]::SetWindowPos($form.Handle, [IntPtr](-1), 0, 0, 0, 0, 0x13) }

# Not on any screen at all (monitor unplugged, resolution changed): put it back bottom-right.
function Ensure-OnScreen {
  $r = $form.Bounds
  if (@([Windows.Forms.Screen]::AllScreens | Where-Object { $_.WorkingArea.IntersectsWith($r) }).Count) { return }
  $area = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
  $form.Location = New-Object Drawing.Point(($area.Right - $form.Width - 12), ($area.Bottom - $form.Height - 12))
  try { "$($form.Left),$($form.Top)" | Set-Content $posFile } catch {}
}

# Tray icon click, "Show widget", or launching it again: open it fully and bring it forward.
function Show-Widget {
  $form.Show()
  [void]$visibleFlag.Set()
  Ensure-OnScreen
  $script:collapsed = $false
  Pin-OnTop
  $form.Invalidate()
}

function Update-Tooltip {
  $d = $script:data
  $lines = @()
  foreach ($p in @(@('Claude', $d.claude, $d.tokens.claude, $d.month.claude), @('Codex', $d.codex, $d.tokens.codex, $d.month.codex))) {
    if ($script:mode -ne 'both' -and $script:mode -ne $p[0].ToLower()) { continue }
    $u = $p[1]; $t = $p[2]; $m = $p[3]
    $head = $p[0] + $(if ($u.plan) { " ($($u.plan))" }) + $(if ($u.asOf) { ' — as of ' + [DateTimeOffset]::FromUnixTimeSeconds([long]$u.asOf).LocalDateTime.ToString('ddd h:mm tt', [Globalization.CultureInfo]::InvariantCulture) }) + $(if (Is-Stale $u) { ' — OUT OF DATE (rate-limited, token expired, or offline; retries automatically)' })
    $lines += $head
    if ($u.fiveHour) { $lines += "  Session $($u.fiveHour.pct)% used, $(100 - $u.fiveHour.pct)% left, $(Reset-Text $u.fiveHour.resetsAt $false)" }
    if ($u.weekly)   { $lines += "  Weekly  $($u.weekly.pct)% used, $(100 - $u.weekly.pct)% left, $(Reset-Text $u.weekly.resetsAt $true)" }
    if ($t) { $lines += "  Today $(Short-Num $t.total) tokens ($(Short-Num $t.inOut) in/out)" }
    $monthLine = Month-TooltipLine $m
    if ($monthLine) { $lines += $monthLine }

  }
  $lines += ''
  $lines += "Updated $($script:updatedAt.ToString('h:mm:ss tt')) · drag to move · ✕ shrinks to the butterfly · right-click → Exit closes"
  $lines += 'mo = this billing month (pay day in billing.json), ~% estimated as weekly limit × weeks in the month (no official monthly limit)'
  $lines += 'Click the butterfly (or right-click) to show Claude / Codex / both · hold it to switch horizontal / vertical / square'
  $tip.SetToolTip($form, ($lines -join "`n"))
  # Tray hover text (Windows cuts it at 63 characters).
  $short = foreach ($p in @(@('Claude', $d.claude), @('Codex', $d.codex))) {
    if ($p[1].fiveHour) { "$($p[0]) $($p[1].fiveHour.pct)%/$($p[1].weekly.pct)%" }
  }
  $trayText = 'AI Usage: ' + ($short -join ', ')
  $tray.Text = $trayText.Substring(0, [Math]::Min(63, $trayText.Length))
}

# Background poll: start node, pick up its output on a fast timer.
$script:proc = $null
$script:out = $null
function Start-Poll {
  if ($script:out) { return }
  $psi = New-Object Diagnostics.ProcessStartInfo 'node', "`"$script`""
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.CreateNoWindow = $true
  try {
    $script:proc = [Diagnostics.Process]::Start($psi)
    $script:out = $script:proc.StandardOutput.ReadToEndAsync()
  } catch {}
}

$check = New-Object Windows.Forms.Timer
$check.Interval = 250
$check.Add_Tick({
  if (-not $script:out -or -not $script:out.IsCompleted) { return }
  try {
    $json = $script:out.Result
    if ($json) {
      $script:data = $json | ConvertFrom-Json
      $script:updatedAt = Get-Date
      Update-Tooltip
      $form.Invalidate()
    }
  } catch {}
  $script:out = $null
})
$check.Start()

# Repaint every second (local only, costs nothing) so stale greying and reset rollovers show promptly.
$tick = New-Object Windows.Forms.Timer
$tick.Interval = 1000
$script:ticks = 0
$tick.Add_Tick({
  if ($wake.WaitOne(0)) { Show-Widget }
  if ($hideSignal.WaitOne(0)) { $form.Hide(); [void]$visibleFlag.Reset() }
  # Every 30 s: Windows can drop it out of the topmost band (sleep, full-screen apps, Explorer restart)
  # or a display change can leave it off screen, and with no taskbar button it then looks gone.
  if ((++$script:ticks % 30) -eq 0 -and -not $menu.Visible) { Pin-OnTop; Ensure-OnScreen }
  $form.Invalidate()
})
$tick.Start()

# Every 60 s: faster polling got the Claude usage endpoint to 429 us indefinitely.
$poll = New-Object Windows.Forms.Timer
$poll.Interval = 60000
$poll.Add_Tick({ Start-Poll })
$poll.Start()

# Drag to move; remember position. Right-hand buttons: ⟳ refresh, ✕ close.
# ✕ shrinks to just the butterfly; clicking it (without dragging) opens it again.
# On the open bar the butterfly cycles Claude / Codex / both (the user's choice, twice).
$script:collapsed = $false
$script:moved = $false
function Set-Collapsed($on) {
  $script:collapsed = $on
  $form.Invalidate()   # Paint refits the width, keeping the right edge put
}

function Set-Layout($name) {
  $script:layout = $name
  foreach ($k in $layoutItems.Keys) { $layoutItems[$k].Checked = ($k -eq $name) }
  try { $name | Set-Content $layoutFile } catch {}
  $script:anchorBottom = $form.Bottom
  $form.Invalidate()   # Paint refits both width and height
}

# Hit areas. In the vertical and square panels the butterfly and ⟳ ✕ share the top row only.
function In-TopRow($e) { $script:collapsed -or $script:layout -eq 'horizontal' -or $e.Y -le $script:rowH }
function On-Butterfly($e) { $e.X -le 30 -and (In-TopRow $e) }
function On-Buttons($e) { -not $script:collapsed -and $e.X -ge ($W - $BTN) -and (In-TopRow $e) }

# Holding the butterfly this long switches the layout; a shorter press is a normal click.
# The timer switches while still held, but a busy UI thread can starve it (timer messages wait for an
# empty queue), so release also checks how long the press really was, using the messages' own times.
Add-Type -Namespace Widget -Name Msg -MemberDefinition '[DllImport("user32.dll")] public static extern int GetMessageTime();'
$HOLD_MS = 600
$hold = New-Object Windows.Forms.Timer
$hold.Interval = $HOLD_MS
function Do-Hold {
  $hold.Stop()
  $script:pressAt = $null
  $script:butterflyDown = $false
  $script:drag = $null
  $script:collapsed = $false
  Set-Layout $layouts[([array]::IndexOf($layouts, $script:layout) + 1) % $layouts.Count]
}
$hold.Add_Tick({ Do-Hold })
# Milliseconds since the press. Message times are a 32-bit tick count that wraps (goes negative after ~24.8 days).
function Held-Ms { ([long][Widget.Msg]::GetMessageTime() - [long]$script:pressAt + 4294967296) % 4294967296 }

$script:drag = $null
$script:butterflyDown = $false
$script:pressAt = $null
$form.Add_MouseDown({
  if ($_.Button -ne 'Left') { return }
  $script:moved = $false
  if (On-Butterfly $_) { $script:pressAt = [Widget.Msg]::GetMessageTime(); $hold.Start() }
  if ($script:collapsed) { $script:drag = $_.Location; return }
  if ((On-Buttons $_) -and $_.X -ge ($W - 28)) { Set-Collapsed $true; return }
  if (On-Buttons $_) { Start-Poll; return }
  # The mode only changes on release, so a hold doesn't also switch Claude / Codex.
  if (On-Butterfly $_) { $script:butterflyDown = $true; return }
  $script:drag = $_.Location
})
$form.Add_MouseMove({
  if ($script:drag) {
    $dx = $_.X - $script:drag.X; $dy = $_.Y - $script:drag.Y
    if ([Math]::Abs($dx) + [Math]::Abs($dy) -gt 3) { $script:moved = $true; $hold.Stop(); $script:pressAt = $null }
    if ($script:moved) { $form.Location = New-Object Drawing.Point(($form.Left + $dx), ($form.Top + $dy)) }
  } else {
    $form.Cursor = if ((On-Butterfly $_) -or (On-Buttons $_)) { 'Hand' } else { 'SizeAll' }
  }
})
$form.Add_MouseUp({
  $hold.Stop()
  if ($null -ne $script:pressAt -and (Held-Ms) -ge $HOLD_MS) { Do-Hold }
  elseif ($script:butterflyDown) {
    $next = @{ both = 'claude'; claude = 'codex'; codex = 'both' }
    Set-Mode $next[$script:mode]
  }
  elseif ($script:drag -and $script:moved) { "$($form.Left),$($form.Top)" | Set-Content $posFile }
  elseif ($script:drag -and $script:collapsed) { Set-Collapsed $false }
  $script:butterflyDown = $false
  $script:pressAt = $null
  $script:drag = $null
})

$menu = New-Object Windows.Forms.ContextMenuStrip
[void]$menu.Items.Add('Show widget', $null, { Show-Widget })
[void]$menu.Items.Add('-')
$modeItems = @{
  both   = $menu.Items.Add('Show both', $null, { Set-Mode 'both' })
  claude = $menu.Items.Add('Show Claude only', $null, { Set-Mode 'claude' })
  codex  = $menu.Items.Add('Show Codex only', $null, { Set-Mode 'codex' })
}
[void]$menu.Items.Add('-')

function Set-Mode($mode) {
  $script:mode = $mode
  foreach ($k in $modeItems.Keys) { $modeItems[$k].Checked = ($k -eq $mode) }
  try { $mode | Set-Content $modeFile } catch {}
  if ($script:data) { Update-Tooltip }
  $form.Invalidate()   # Paint refits the width, keeping the right edge put
}
foreach ($k in $modeItems.Keys) { $modeItems[$k].Checked = ($k -eq $script:mode) }

$layoutItems = @{
  horizontal = $menu.Items.Add('Horizontal', $null, { Set-Layout 'horizontal' })
  vertical   = $menu.Items.Add('Vertical', $null, { Set-Layout 'vertical' })
  square     = $menu.Items.Add('Square', $null, { Set-Layout 'square' })
}
foreach ($k in $layoutItems.Keys) { $layoutItems[$k].Checked = ($k -eq $script:layout) }
[void]$menu.Items.Add('-')
[void]$menu.Items.Add('Refresh', $null, { Start-Poll })
[void]$menu.Items.Add('Exit', $null, { $form.Close() })
$form.ContextMenuStrip = $menu

# Tray icon (notification area), so the widget can always be found even when shrunk or covered.
# Left-click brings it back; right-click gives the same menu as the widget.
# (No ScaleTransform here: Draw-Butterfly resets the transform after every wing.)
$trayBmp = New-Object Drawing.Bitmap 22, 22
$tg = [Drawing.Graphics]::FromImage($trayBmp)
$tg.SmoothingMode = 'AntiAlias'
Draw-Butterfly $tg 11 12
$tg.Dispose()
$tray = New-Object Windows.Forms.NotifyIcon
$tray.Icon = [Drawing.Icon]::FromHandle($trayBmp.GetHicon())
$tray.Text = 'AI Usage'
$tray.ContextMenuStrip = $menu
$tray.Add_MouseClick({ if ($_.Button -eq 'Left') { Show-Widget } })
$tray.Visible = $true
$form.Add_FormClosed({ $tray.Visible = $false; $tray.Dispose(); [void]$visibleFlag.Reset() })

# No full Keep-OnScreen here: the window still has its placeholder width, so that would shift it.
# The first paint fits it and keeps it on screen, but Windows never paints a window that is entirely
# off screen (e.g. saved on a monitor that is gone), so first just bring its top-left corner on.
$form.Add_Shown({
  $area = [Windows.Forms.Screen]::FromControl($form).WorkingArea
  $form.Location = New-Object Drawing.Point(
    [Math]::Min([Math]::Max($form.Left, $area.Left), $area.Right - 32),
    [Math]::Min([Math]::Max($form.Top, $area.Top), $area.Bottom - 32))
  [void]$visibleFlag.Set()
  Start-Poll
})
[Windows.Forms.Application]::Run($form)
