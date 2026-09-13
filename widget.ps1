# One-line always-on-top usage bar for Claude + Codex, light blue theme with a butterfly icon.
# Hover for reset times and today's tokens. Drag to move. ⟳ refresh, ✕ shrink to the butterfly
# (click it to open again). Right-click → Exit really closes it.
# Polls usage-json.js in the background every 60 s so the UI never freezes.
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# One widget at a time: launching it again (Start menu, Startup) while it runs does nothing.
$single = New-Object Threading.Mutex($false, 'Local\AIUsageWidget')
try { if (-not $single.WaitOne(0)) { exit } } catch [Threading.AbandonedMutexException] {}

$script = Join-Path $PSScriptRoot 'usage-json.js'
$posFile = Join-Path $env:USERPROFILE '.claude\usage-widget-pos.txt'
$modeFile = Join-Path $env:USERPROFILE '.claude\usage-widget-mode.txt'

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
function TextY($g, $f) { [int](($H - 4 - $g.MeasureString('0', $f).Height) / 2) }

# Compact reset clock time: "↻6:50AM" for the session, "↻Fri 3:00AM" for the week.
function Short-Reset($resetsAt, $weekly) {
  if (-not $resetsAt) { return '' }
  $at = [DateTimeOffset]::FromUnixTimeSeconds([long]$resetsAt).LocalDateTime
  $fmt = if ($weekly) { 'ddd h:mmtt' } else { 'h:mmtt' }
  return '↻' + $at.ToString($fmt, [Globalization.CultureInfo]::InvariantCulture)
}

# "5h ▬▬▬ 41% ↻4h09" — returns the x after it.
# $stale: numbers are last-known from local logs, not live — drawn grey with a "?" so they can't pass for live.
function Draw-Window($g, $x, $label, $win, $weekly, $stale) {
  $g.DrawString($label, $fSmall, (Brush $muted), $x, (TextY $g $fSmall))
  $x += (TextW $g $label $fSmall)
  $barY = [int](($H - 4) / 2) - 3
  $g.FillRectangle((Brush $track), $x, $barY, 40, 6)
  if ($win) {
    $fill = if ($stale) { $muted } else { Level-Color $win.pct }
    $g.FillRectangle((Brush $fill), $x, $barY, [int](40 * [Math]::Min(100, $win.pct) / 100), 6)
    $txt = "$($win.pct)%" + $(if ($stale) { '?' })
  } else { $txt = '—' }
  $x += 42
  $pctColor = if ($stale) { $muted } elseif ([int]$win.pct -ge 70) { Level-Color ([int]$win.pct) } else { $ink }
  $g.DrawString($txt, $fText, (Brush $pctColor), $x, (TextY $g $fText))
  $x += (TextW $g '100%?' $fText)
  # Fixed slot sized for the widest label, so the bar doesn't jiggle as the countdown changes.
  $widest = if ($weekly) { '↻Wed 12:59PM' } else { '↻12:59PM' }
  if ($win) { $g.DrawString((Short-Reset $win.resetsAt $weekly), $fSmall, (Brush $muted), $x, (TextY $g $fSmall)) }
  return $x + (TextW $g $widest $fSmall) + 8
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
  $x = Draw-Window $g $x '5h' $usage.fiveHour $false $stale
  $x = Draw-Window $g $x '7d' $usage.weekly $true $stale
  return $x
}

$form.Add_Paint({
  $g = $_.Graphics
  $g.SmoothingMode = 'AntiAlias'
  $g.TextRenderingHint = 'ClearTypeGridFit'
  # Real client height (display scaling can make it differ from $H); helper functions see this.
  $H = $form.ClientSize.Height
  # Blue trim along the bottom.
  $g.FillRectangle((Brush $accent), 0, ($H - 4), $form.ClientSize.Width, 4)
  Draw-Butterfly $g 16 ([int](($H - 4) / 2) + 1)

  if ($script:collapsed) {
    $want = 32   # butterfly only
  } else {
    $d = $script:data
    $x = 32
    if ($script:mode -ne 'codex') { $x = Draw-Section $g $x 'Claude' $d.claude }
    if ($script:mode -eq 'both') {
      $g.FillRectangle((Brush $accent), ($x - 3), 7, 1, ($H - 18))
      $x += 6
    }
    if ($script:mode -ne 'claude') { $x = Draw-Section $g $x 'Codex' $d.codex }

    $ty = TextY $g $fText
    $g.DrawString('⟳', $fText, (Brush $ink), ($x + 2), $ty)
    $g.DrawString('✕', $fText, (Brush $ink), ($x + 26), $ty)
    $want = $x + $BTN
  }

  # Fit the window to its content (one resize, then it's stable).
  # Grow leftwards so ⟳ ✕ stay put, and never past the screen edge.
  if ($want -ne $form.ClientSize.Width) {
    $right = $form.Right
    $form.ClientSize = New-Object Drawing.Size($want, $form.ClientSize.Height)
    Keep-OnScreen $right
  }
  $script:W = $form.ClientSize.Width
})

function Keep-OnScreen($right) {
  $area = [Windows.Forms.Screen]::FromControl($form).WorkingArea
  $left = [Math]::Min($right, $area.Right) - $form.Width
  $top = [Math]::Min([Math]::Max($form.Top, $area.Top), $area.Bottom - $form.Height)
  $form.Location = New-Object Drawing.Point([Math]::Max($area.Left, $left), $top)
}

function Update-Tooltip {
  $d = $script:data
  $lines = @()
  foreach ($p in @(@('Claude', $d.claude, $d.tokens.claude), @('Codex', $d.codex, $d.tokens.codex))) {
    if ($script:mode -ne 'both' -and $script:mode -ne $p[0].ToLower()) { continue }
    $u = $p[1]; $t = $p[2]
    $head = $p[0] + $(if ($u.plan) { " ($($u.plan))" }) + $(if ($u.asOf) { ' — as of ' + [DateTimeOffset]::FromUnixTimeSeconds([long]$u.asOf).LocalDateTime.ToString('ddd h:mm tt', [Globalization.CultureInfo]::InvariantCulture) }) + $(if (Is-Stale $u) { ' — OUT OF DATE (rate-limited, token expired, or offline; retries automatically)' })
    $lines += $head
    if ($u.fiveHour) { $lines += "  Session $($u.fiveHour.pct)% used, $(100 - $u.fiveHour.pct)% left, $(Reset-Text $u.fiveHour.resetsAt $false)" }
    if ($u.weekly)   { $lines += "  Weekly  $($u.weekly.pct)% used, $(100 - $u.weekly.pct)% left, $(Reset-Text $u.weekly.resetsAt $true)" }
    if ($t) { $lines += "  Today $(Short-Num $t.total) tokens ($(Short-Num $t.inOut) in/out)" }
  }
  $lines += ''
  $lines += "Updated $($script:updatedAt.ToString('h:mm:ss tt')) · drag to move · ✕ shrinks to the butterfly · right-click → Exit closes"
  $lines += 'Click the butterfly (or right-click) to show Claude / Codex / both'
  $tip.SetToolTip($form, ($lines -join "`n"))
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
$tick.Add_Tick({ $form.Invalidate() })
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

$script:drag = $null
$form.Add_MouseDown({
  if ($_.Button -ne 'Left') { return }
  $script:moved = $false
  if ($script:collapsed) { $script:drag = $_.Location; return }
  if ($_.X -ge ($W - 28)) { Set-Collapsed $true; return }
  if ($_.X -ge ($W - $BTN)) { Start-Poll; return }
  if ($_.X -le 30) {
    $next = @{ both = 'claude'; claude = 'codex'; codex = 'both' }
    Set-Mode $next[$script:mode]
    return
  }
  $script:drag = $_.Location
})
$form.Add_MouseMove({
  if ($script:drag) {
    $dx = $_.X - $script:drag.X; $dy = $_.Y - $script:drag.Y
    if ([Math]::Abs($dx) + [Math]::Abs($dy) -gt 3) { $script:moved = $true }
    if ($script:moved) { $form.Location = New-Object Drawing.Point(($form.Left + $dx), ($form.Top + $dy)) }
  } else {
    $form.Cursor = if ($script:collapsed -or $_.X -ge ($W - $BTN) -or $_.X -le 30) { 'Hand' } else { 'SizeAll' }
  }
})
$form.Add_MouseUp({
  if ($script:drag -and $script:moved) { "$($form.Left),$($form.Top)" | Set-Content $posFile }
  elseif ($script:drag -and $script:collapsed) { Set-Collapsed $false }
  $script:drag = $null
})

$menu = New-Object Windows.Forms.ContextMenuStrip
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

[void]$menu.Items.Add('Refresh', $null, { Start-Poll })
[void]$menu.Items.Add('Exit', $null, { $form.Close() })
$form.ContextMenuStrip = $menu

$form.Add_Shown({ Keep-OnScreen $form.Right; Start-Poll })
[Windows.Forms.Application]::Run($form)
