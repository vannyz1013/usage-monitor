# One-line always-on-top usage bar for Claude + Codex, light blue theme with a butterfly icon.
# Hover for reset times and today's tokens. Drag to move. ⟳ refresh, ✕ puts it away (the desktop pet
# wears the butterfly as a hair clip; tapping that, or the tray icon, brings it back). Right-click → Exit closes it.
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

# Holding the butterfly cycles the shape: one-line bar, the same bar stood on end like a stick (pole),
# stacked (vertical) panel, square. Remembered too.
$layouts = 'horizontal', 'pole', 'vertical', 'square'
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

# Every colour the widget draws with ($bg, $ink, $accent, $track, $warn, $danger, $muted, $labelInk, $wing,
# $wing2, $renewGreen, $edge, $chip), in a light and a dark palette that follows Windows: lib\theme.ps1.
# Dot-sourced here, before the form, because the form's background is one of them.
. (Join-Path $PSScriptRoot 'lib\theme.ps1')

# Font sizes, biggest first: product names (Claude, Codex, Spotify) > Renews / Ends ($fPlan, lib\plan-status.ps1)
# > percentages ($fText) > 5h / 7d / mo labels and reset times ($fSmall).
$fName  = New-Object Drawing.Font('Segoe UI Semibold', 10)
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

# The details panel (reset times, today's tokens, what mo means). It used to pop up whenever the mouse passed
# over the widget, which on an always-on-top bar is most of the time; now it is only the menu's "Details".
$tip = New-Object Windows.Forms.ToolTip
$tip.AutoPopDelay = 30000
$script:tipText = ''

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
  return 'resets ' + $at.ToString($fmt, [Globalization.CultureInfo]::InvariantCulture) + " ($(Until-Text $resetsAt))"
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
# One slot for every row label, wide enough for the widest of them ("mo" is wider than "5h" and "7d").
# Measured, not guessed: a narrower slot let the mo row's bar start on top of its own label.
function Label-Slot($g) {
  if (-not $script:labelSlot) {
    $script:labelSlot = ('5h', '7d', 'mo' | ForEach-Object { TextW $g $_ $fSmall } | Measure-Object -Maximum).Maximum + 2
  }
  $script:labelSlot
}
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
# $showReset is off for the one-line bar: the reset clocks are what made it span the whole screen. They are still
# in right-click -> Details, and in the pole, vertical and square layouts.
function Draw-Window($g, $x, $y, $label, $win, $weekly, $stale, $showReset = $true) {
  $g.DrawString($label, $fSmall, (Brush $labelInk), $x, (TextY $g $fSmall $y))
  $x += (Label-Slot $g)
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
  if (-not $showReset) { return $x + 10 }
  # Fixed slot sized for the widest label, so the bar doesn't jiggle as the countdown changes.
  $widest = if ($weekly) { '↻Wed 12:59PM' } else { '↻12:59PM' }
  if ($win) { $g.DrawString((Short-Reset $win.resetsAt $weekly), $fSmall, (Brush $labelInk), $x, (TextY $g $fSmall $y)) }
  return $x + (TextW $g $widest $fSmall) + 8
}

# The billing-month row (mo): Month-*, Draw-Month, Draw-MonthRing.
. (Join-Path $PSScriptRoot 'lib\month.ps1')
# Green Renews / red Ends label for every plan: Plan-Label, Plan-Color.
. (Join-Path $PSScriptRoot 'lib\plan-status.ps1')
# The Spotify line: Draw-Spotify, Spotify-Height, Spotify-Width.
. (Join-Path $PSScriptRoot 'lib\spotify.ps1')
# Which products this PC has (not everyone uses Claude, Codex and Spotify): Get-Sections, Has-MonthRow.
. (Join-Path $PSScriptRoot 'lib\products.ps1')
# See-through / click-through levels: Ghost-Mode, Apply-SeeThrough, Set-SeeThrough.
. (Join-Path $PSScriptRoot 'lib\see-through.ps1')
# Rounded corners and the thin edge round the panel: Apply-Corners, Draw-Edge, Rounded-Path.
. (Join-Path $PSScriptRoot 'lib\rounded.ps1')
# Pointer feedback on ⟳ ✕ and the butterfly: Set-Hover, Hover-Cursor, Draw-Hover.
. (Join-Path $PSScriptRoot 'lib\hover.ps1')
# "in 2h 14m" next to a reset time in the details panel: Until-Text.
. (Join-Path $PSScriptRoot 'lib\countdown.ps1')
# The one-time note about the controls, on this PC's first run: First-Run-Hint.
. (Join-Path $PSScriptRoot 'lib\first-run.ps1')
# Leaving the month row off the one-line bar, which is what makes it wide: Compact-Bar, Set-Compact.
. (Join-Path $PSScriptRoot 'lib\compact.ps1')
# "At this rate" in the details panel - whether a window runs out before it resets: Pace-Line.
. (Join-Path $PSScriptRoot 'lib\pace.ps1')
# The tray warning at 80% and 95%: Check-Alerts, Set-Warn.
. (Join-Path $PSScriptRoot 'lib\alerts.ps1')
# The pole (stick) layout's rows: Pole-Width, Draw-PoleRow, Draw-PoleMonth.
. (Join-Path $PSScriptRoot 'lib\pole.ps1')

$centre = New-Object Drawing.StringFormat
$centre.Alignment = 'Center'
$centre.LineAlignment = 'Center'
function Draw-Centered($g, $s, $f, $color, $x, $y, $w, $h) {
  $g.DrawString($s, $f, (Brush $color), (New-Object Drawing.RectangleF($x, $y, $w, $h)), $centre)
}

# Square layout gauge: a ring filling clockwise from the top, % inside, reset clock time below.
# Cells are 96 px wide so a 9 pt "Renews 5 Oct" under the month ring fits.
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
  if ($win.resetsAt) { Draw-Centered $g (Short-Reset $win.resetsAt $weekly) $fSmall $labelInk $x ($y + $d + 2) $w 16 }
}

# Older than 6 min: Claude's API is only asked every 5 min, so anything past that is a missed update.
function Is-Stale($usage) {
  if (-not $usage) { return $false }
  if (-not $usage.asOf) { return $true }
  return ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [double]$usage.asOf) -gt 360
}

# One product on the one-line bar: its name, then 5h, 7d and (with a pay day in billing.json) the mo row, the
# same three rows the other layouts show.
function Draw-Section($g, $x, $name, $usage, $month) {
  $g.DrawString($name, $fName, (Brush $ink), $x, (TextY $g $fName))
  $x += (TextW $g $name $fName) + 4
  $stale = Is-Stale $usage
  $x = Draw-Window $g $x 0 '5h' $usage.fiveHour $false $stale $false
  $x = Draw-Window $g $x 0 '7d' $usage.weekly $true $stale $false
  if ($month -and -not (Compact-Bar)) { $x = Draw-Month $g $x 0 $month }
  return $x
}

# The refresh and close glyphs. In ghost mode the panel behind them is click-through, so they get a solid
# chip to be pressed on; thin glyph strokes on their own are a hard target.
function Draw-Buttons($g, $bx, $by) {
  if (Ghost-Mode) { $g.FillRectangle((Brush $track), ($bx - 2), ($by + 4), 48, ($script:rowH - 8)) }
  Draw-Hover $g $bx $by
  $ty = TextY $g $fText $by
  $g.DrawString('⟳', $fText, (Brush $ink), ($bx + 2), $ty)
  $g.DrawString('✕', $fText, (Brush $ink), ($bx + 26), $ty)
}

$form.Add_Paint({
  $g = $_.Graphics
  $g.SmoothingMode = 'AntiAlias'
  # ClearType blends every letter's edge into the background, and in ghost mode that background is keyed out, so
  # the blend is left behind as a pale blue halo round every word. Plain crisp text has no edge to leave behind.
  $g.TextRenderingHint = if (Ghost-Mode) { 'SingleBitPerPixelGridFit' } else { 'ClearTypeGridFit' }
  # The one-line bar's real height (display scaling can make it differ from $H), taken before any
  # layout switch changes the window height. One row is that minus the trim; helper functions see it.
  if (-not $script:barH) { $script:barH = $form.ClientSize.Height }
  $rh = $script:rowH = $script:barH - 4
  # Blue trim along the bottom.
  $g.FillRectangle((Brush $accent), 0, ($form.ClientSize.Height - 4), $form.ClientSize.Width, 4)
  Draw-Butterfly $g 16 ([int]($rh / 2) + 1)

  $d = $script:data
  $sections = Get-Sections $d $script:mode
  $wantH = $script:barH

  if (Nothing-Found $d $sections) {
    $wantW = 32 + (Draw-NothingFound $g 32 0 $rh) + 8 + $BTN
    $bx = $form.ClientSize.Width - $BTN
  } elseif ($script:layout -eq 'square') {
    # Ring gauges: a column per product, a row per window (5h, 7d) plus the billing month. The panel is kept square.
    $labelW = 20; $cellW = 96; $ringD = 44; $cellH = $ringD + 20; $nameH = 20
    $gridW = $labelW + $cellW * $sections.Count
    $monthRow = Has-MonthRow $sections
    $rows = if ($sections.Count) { 2 + [int]$monthRow } else { 0 }
    $side = [Math]::Max([Math]::Max($gridW, (Spotify-Width $g)) + 16, $rh + $nameH + $rows * $cellH + 8 + (Spotify-Height))
    $x0 = [int](($form.ClientSize.Width - $gridW) / 2)
    for ($i = 0; $i -lt $sections.Count; $i++) {
      Draw-Centered $g $sections[$i][0] $fName $ink ($x0 + $labelW + $i * $cellW) $rh $cellW $nameH
    }
    $y = $rh + $nameH
    $windowRows = if ($sections.Count) { @(@('5h', 'fiveHour', $false), @('7d', 'weekly', $true)) } else { @() }
    foreach ($row in $windowRows) {
      $g.DrawString($row[0], $fSmall, (Brush $labelInk), $x0, (TextY $g $fSmall $y $ringD))
      for ($i = 0; $i -lt $sections.Count; $i++) {
        $usage = $sections[$i][1]
        Draw-Ring $g ($x0 + $labelW + $i * $cellW) $y $cellW $ringD $usage.($row[1]) $row[2] (Is-Stale $usage)
      }
      $y += $cellH
    }
    if ($monthRow) {
      $g.DrawString('mo', $fSmall, (Brush $labelInk), $x0, (TextY $g $fSmall $y $ringD))
      for ($i = 0; $i -lt $sections.Count; $i++) {
        # A product without a billing.json entry leaves its cell empty.
        if ($sections[$i][2]) { Draw-MonthRing $g ($x0 + $labelW + $i * $cellW) $y $cellW $ringD $sections[$i][2] }
      }
      $y += $cellH
    }
    $spotifyW = [Math]::Max($gridW, (Spotify-Width $g))
    Draw-Spotify $g ([int](($form.ClientSize.Width - $spotifyW) / 2)) $y $spotifyW
    $wantW = $wantH = $side
    $bx = $form.ClientSize.Width - $BTN
  } elseif ($script:layout -eq 'vertical') {
    # Stacked: butterfly and ⟳ ✕ on top, then per product a name row and its 5h / 7d rows.
    $y = $rh; $maxX = 0
    for ($i = 0; $i -lt $sections.Count; $i++) {
      $name, $usage, $month = $sections[$i]
      if ($i) { $g.FillRectangle((Brush $accent), 10, ($y + 2), ($form.ClientSize.Width - 20), 1); $y += 5 }
      $g.DrawString($name, $fName, (Brush $ink), 10, (TextY $g $fName $y 22)); $y += 22
      $stale = Is-Stale $usage
      $maxX = [Math]::Max($maxX, (Draw-Window $g 12 $y '5h' $usage.fiveHour $false $stale)); $y += $rh
      $maxX = [Math]::Max($maxX, (Draw-Window $g 12 $y '7d' $usage.weekly $true $stale)); $y += $rh
      if ($month) { $maxX = [Math]::Max($maxX, (Draw-Month $g 12 $y $month)); $y += $rh }
    }
    $spotifyW = Spotify-Width $g
    Draw-Spotify $g 10 $y ([Math]::Max($maxX - 20, $spotifyW))
    $wantW = [Math]::Max([Math]::Max($maxX, 32 + $BTN), $spotifyW + 20)
    $wantH = $y + (Spotify-Height) + 4
    $bx = $form.ClientSize.Width - $BTN
  } elseif ($script:layout -eq 'pole') {
    # A stick: one narrow column with everything stacked down it. The text stays the right way up - turning the
    # whole bar on its side made a stick you could not read. Reset times are the one thing left out, because they
    # are what makes a row wide; they are still in the tooltip and in the other three layouts.
    $stickW = [Math]::Max(62, (Pole-Width $g $sections))
    $y = $rh
    for ($i = 0; $i -lt $sections.Count; $i++) {
      $name, $usage, $month = $sections[$i]
      if ($i) { $g.FillRectangle((Brush $accent), 10, ($y + 2), ($stickW - 20), 1); $y += 6 }
      Draw-Centered $g $name $fName $ink 0 $y $stickW 20; $y += 20
      $stale = Is-Stale $usage
      $y = Draw-PoleRow $g $y $stickW '5h' $usage.fiveHour $stale
      $y = Draw-PoleRow $g $y $stickW '7d' $usage.weekly $stale
      if ($month) { $y = Draw-PoleMonth $g $y $stickW $month }
    }
    $y = Draw-PoleSpotify $g $y $stickW
    $bx = [int](($stickW - 44) / 2)
    $by = $y + 2
    $wantW = $stickW
    $wantH = $by + $rh + 2
  } else {
    $x = 32
    for ($i = 0; $i -lt $sections.Count; $i++) {
      if ($i) { $g.FillRectangle((Brush $accent), ($x - 3), 7, 1, ($rh - 14)); $x += 6 }
      $x = Draw-Section $g $x $sections[$i][0] $sections[$i][1] $sections[$i][2]
    }
    $x = Draw-SpotifyInline $g $x
    $wantW = $x + $BTN
    $bx = $x
  }
  if ($null -eq $by) { $by = 0 }
  Draw-Buttons $g $bx $by
  $script:btnAt = New-Object Drawing.Rectangle($bx, $by, $BTN, $rh)

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
  Apply-Corners
  Draw-Edge $g
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

# Tray icon click, "Show widget", the pet's butterfly clip, or launching it again: bring it back and to the front.
function Show-Widget {
  $form.Show()
  [void]$visibleFlag.Set()
  Ensure-OnScreen
  Pin-OnTop
  $form.Invalidate()
}

# ✕ puts it away completely. It used to shrink to a butterfly, but the butterfly now belongs to the desktop
# pet, which wears it as a hair clip - tapping that clip (or the tray icon) is what brings the widget back.
function Hide-Widget {
  $form.Hide()
  [void]$visibleFlag.Reset()
}

# Asked for from the menu: the details panel, just under the widget, until it is clicked away or 30 s pass.
function Show-Details {
  if ($script:tipText) { $tip.Show($script:tipText, $form, 8, ($form.Height + 4), 30000) }
}

function Update-Tooltip {
  $d = $script:data
  $lines = @()
  # Only the products this PC has (lib\products.ps1).
  foreach ($section in (Get-Sections $d $script:mode)) {
    $name, $u, $m = $section
    $t = if ($u) { $d.tokens.($name.ToLower()) }   # today's tokens are all 0 for a product never used here
    $head = $name + $(if ($u.plan) { " ($($u.plan))" }) + $(if ($u.asOf) { ' — as of ' + [DateTimeOffset]::FromUnixTimeSeconds([long]$u.asOf).LocalDateTime.ToString('ddd h:mm tt', [Globalization.CultureInfo]::InvariantCulture) }) + $(if (Is-Stale $u) { ' — OUT OF DATE (rate-limited, token expired, or offline; retries automatically)' })
    $lines += $head
    if ($u.fiveHour) {
      $lines += "  Session $($u.fiveHour.pct)% used, $(100 - $u.fiveHour.pct)% left, $(Reset-Text $u.fiveHour.resetsAt $false)"
      $pace = Pace-Line $u.fiveHour 'fiveHour'; if ($pace) { $lines += $pace }
    }
    if ($u.weekly) {
      $lines += "  Weekly  $($u.weekly.pct)% used, $(100 - $u.weekly.pct)% left, $(Reset-Text $u.weekly.resetsAt $true)"
      $pace = Pace-Line $u.weekly 'weekly'; if ($pace) { $lines += $pace }
    }
    if ($t) { $lines += "  Today $(Short-Num $t.total) tokens ($(Short-Num $t.inOut) in/out)" }
    $monthLine = Month-TooltipLine $m
    if ($monthLine) { $lines += $monthLine }
  }
  if (Nothing-Found $d (Get-Sections $d $script:mode)) { $lines += $nothingText }
  $spotifyLine = Spotify-TooltipLine
  if ($spotifyLine) { $lines += $spotifyLine }
  $lines += ''
  $lines += "Updated $($script:updatedAt.ToString('h:mm:ss tt')) · drag to move · ✕ puts it away (the pet's butterfly clip or the tray icon brings it back) · right-click → Exit closes"
  if (Has-MonthRow (Get-Sections $d $script:mode)) { $lines += 'mo = this billing month (pay day in billing.json), ~% estimated as weekly limit × weeks in the month (no official monthly limit)' }
  $lines += 'Click the butterfly to show Claude / Codex / both · hold it to change shape · right-click → Look for light, dark and see-through'
  $script:tipText = $lines -join "`n"
  # Tray hover text (Windows cuts it at 63 characters).
  $short = foreach ($p in @(@('Claude', $d.claude), @('Codex', $d.codex))) {
    if ($p[1].fiveHour) { "$($p[0]) $($p[1].fiveHour.pct)%/$($p[1].weekly.pct)%" }
  }
  $trayText = 'AI Usage' + $(if ($short) { ': ' + ($short -join ', ') })
  $tray.Text = $trayText.Substring(0, [Math]::Min(63, $trayText.Length))
}

# Background poll: start node, pick up its output on a fast timer.
$script:proc = $null
$script:out = $null
# $fresh: also skip the 5-minute ccusage cache (lib/token-cache.js). The timer polls without it;
# the buttons and the menu ask for it, because a refresh that returns cached numbers is not a refresh.
function Start-Poll($fresh = $false) {
  if ($script:out) { return }
  $nodeArgs = if ($fresh) { "`"$script`" fresh" } else { "`"$script`"" }
  $psi = New-Object Diagnostics.ProcessStartInfo 'node', $nodeArgs
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
      Check-Alerts
      $form.Invalidate()
      First-Run-Hint
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
  if ((++$script:ticks % 30) -eq 0 -and -not $menu.Visible) { Pin-OnTop; Ensure-OnScreen; Follow-Windows-Theme }
  $form.Invalidate()
})
$tick.Start()

# Every 60 s: faster polling got the Claude usage endpoint to 429 us indefinitely.
$poll = New-Object Windows.Forms.Timer
$poll.Interval = 60000
$poll.Add_Tick({ Start-Poll })
$poll.Start()

# Drag to move; remember position. Right-hand buttons: ⟳ refresh, ✕ put it away.
# The butterfly on the bar cycles Claude / Codex / both (the user's choice, twice).
$script:moved = $false

function Set-Layout($name) {
  $script:layout = $name
  foreach ($k in $layoutItems.Keys) { $layoutItems[$k].Checked = ($k -eq $name) }
  try { $name | Set-Content $layoutFile } catch {}
  Apply-SeeThrough   # ghost is for the one-line bar only, so a panel gets its background back
  $script:anchorBottom = $form.Bottom
  $form.Invalidate()   # Paint refits both width and height
}

# Hit areas. The butterfly is always the top-left of the first row; ⟳ ✕ move around between layouts (bottom of
# the pole, top-right of the panels), so Paint records where it put them in $script:btnAt.
function On-Butterfly($e) { $e.X -le 30 -and $e.Y -le $script:rowH }
function On-Buttons($e) { $null -ne $script:btnAt -and $script:btnAt.Contains($e.Location) }
function On-Close($e) { (On-Buttons $e) -and $e.X -ge ($script:btnAt.X + 24) }

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
  if (On-Close $_) { Hide-Widget; return }
  if (On-Buttons $_) { Start-Poll $true; return }
  # The mode only changes on release, so a hold doesn't also switch Claude / Codex.
  if (On-Butterfly $_) { $script:butterflyDown = $true }
  # The butterfly drags too. It is the obvious handle at the left end, and returning here instead left it as the
  # one spot on the bar you could press and not move the thing at all.
  $script:drag = $_.Location
})
$form.Add_MouseMove({
  if ($script:drag) {
    $dx = $_.X - $script:drag.X; $dy = $_.Y - $script:drag.Y
    if ([Math]::Abs($dx) + [Math]::Abs($dy) -gt 3) { $script:moved = $true; $hold.Stop(); $script:pressAt = $null }
    if ($script:moved) { $form.Location = New-Object Drawing.Point(($form.Left + $dx), ($form.Top + $dy)) }
  } else {
    $form.Cursor = Hover-Cursor $_
    if (Set-Hover $_) { $form.Invalidate() }
  }
})
$form.Add_MouseUp({
  $hold.Stop()
  if ($null -ne $script:pressAt -and (Held-Ms) -ge $HOLD_MS) { Do-Hold }
  elseif ($script:butterflyDown -and -not $script:moved) {
    $next = @{ both = 'claude'; claude = 'codex'; codex = 'both' }
    Set-Mode $next[$script:mode]
  }
  elseif ($script:drag -and $script:moved) { "$($form.Left),$($form.Top)" | Set-Content $posFile }
  $script:butterflyDown = $false
  $script:pressAt = $null
  $script:drag = $null
})
# Leaving the widget unlights whatever button was lit.
$form.Add_MouseLeave({ if (Set-Hover $null) { $form.Invalidate() } })

$menu = New-Object Windows.Forms.ContextMenuStrip
# What you reach for most is on top; every setting is one of three submenus, so the list stays short
# enough to read at a glance. The same menu serves the widget and the tray icon.
$menu.ShowImageMargin = $false
[void]$menu.Items.Add('Details', $null, { Show-Details })
[void]$menu.Items.Add('Refresh now', $null, { Start-Poll $true })
[void]$menu.Items.Add('Show widget', $null, { Show-Widget })
[void]$menu.Items.Add('-')

$showMenu = $menu.Items.Add('Show')
$modeItems = @{
  both   = $showMenu.DropDownItems.Add('Claude and Codex', $null, { Set-Mode 'both' })
  claude = $showMenu.DropDownItems.Add('Claude only', $null, { Set-Mode 'claude' })
  codex  = $showMenu.DropDownItems.Add('Codex only', $null, { Set-Mode 'codex' })
}

function Set-Mode($mode) {
  $script:mode = $mode
  foreach ($k in $modeItems.Keys) { $modeItems[$k].Checked = ($k -eq $mode) }
  try { $mode | Set-Content $modeFile } catch {}
  if ($script:data) { Update-Tooltip }
  $form.Invalidate()   # Paint refits the width, keeping the right edge put
}
foreach ($k in $modeItems.Keys) { $modeItems[$k].Checked = ($k -eq $script:mode) }

$shapeMenu = $menu.Items.Add('Shape')
$layoutItems = @{
  horizontal = $shapeMenu.DropDownItems.Add('Bar (one line)', $null, { Set-Layout 'horizontal' })
  pole       = $shapeMenu.DropDownItems.Add('Pole (the bar stood on end)', $null, { Set-Layout 'pole' })
  vertical   = $shapeMenu.DropDownItems.Add('Tall panel', $null, { Set-Layout 'vertical' })
  square     = $shapeMenu.DropDownItems.Add('Square (ring gauges)', $null, { Set-Layout 'square' })
}
foreach ($k in $layoutItems.Keys) { $layoutItems[$k].Checked = ($k -eq $script:layout) }

# Look: the colours (lib\theme.ps1) and how much you can see through it (lib\see-through.ps1).
$lookMenu = $menu.Items.Add('Look')
$themeItems = @{
  auto  = $lookMenu.DropDownItems.Add('Follow Windows', $null, { Set-Theme 'auto' })
  light = $lookMenu.DropDownItems.Add('Light', $null, { Set-Theme 'light' })
  dark  = $lookMenu.DropDownItems.Add('Dark', $null, { Set-Theme 'dark' })
}
foreach ($k in $themeItems.Keys) { $themeItems[$k].Checked = ($k -eq $script:theme) }
[void]$lookMenu.DropDownItems.Add('-')
$seeItems = @{
  solid = $lookMenu.DropDownItems.Add('Solid', $null, { Set-SeeThrough 'solid' })
  soft  = $lookMenu.DropDownItems.Add('Faded', $null, { Set-SeeThrough 'soft' })
  ghost = $lookMenu.DropDownItems.Add('See through it (bar only; clicks go past it)', $null, { Set-SeeThrough 'ghost' })
}
foreach ($k in $seeItems.Keys) { $seeItems[$k].Checked = ($k -eq $script:seeThrough) }
[void]$lookMenu.DropDownItems.Add('-')
$compactItem = $lookMenu.DropDownItems.Add('Compact bar (no month row)', $null, { Set-Compact (-not $script:compact) })
$compactItem.Checked = $script:compact
Apply-SeeThrough
[void]$menu.Items.Add('-')
$warnItem = $menu.Items.Add('Warn me near the limit', $null, { Set-Warn (-not $script:warnOn) })
$warnItem.Checked = $script:warnOn
[void]$menu.Items.Add('Exit', $null, { $form.Close() })
$form.ContextMenuStrip = $menu
Paint-Theme   # the menu exists now, so it can be coloured too

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
