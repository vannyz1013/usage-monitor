# Readable overview alongside the small desktop layouts. Buttons are native controls
# so Tab, Enter, screen readers and mouse users share the same actions.
$script:dashboardControls = @()
$dashTitle = New-Object Drawing.Font('Segoe UI Semibold', 20, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel))
$dashName = New-Object Drawing.Font('Segoe UI Semibold', 16, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel))
$dashText = New-Object Drawing.Font('Segoe UI', 13, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel))
$dashSmall = New-Object Drawing.Font('Segoe UI', 12, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel))

function Dashboard-Text($g, $text, $font, $color, $x, $y) {
  $b = Brush $color
  try { $g.DrawString([string]$text, $font, $b, [float]$x, [float]$y) } finally { $b.Dispose() }
}
function Dashboard-Box($g, $color, $x, $y, $w, $h, $radius = 10) {
  $path = Rounded-Path-At $x $y $w $h $radius
  $b = Brush $color
  try { $g.FillPath($b, $path) } finally { $b.Dispose(); $path.Dispose() }
}
function Initialize-DashboardControls {
  $actions = @(
    @('All plans', { Set-Mode 'both' }), @('Claude', { Set-Mode 'claude' }), @('Codex', { Set-Mode 'codex' }),
    @('Details', { Show-Details }), @('Refresh', { Start-Poll $true }),
    @('Customize', { $menu.Show($form, (New-Object Drawing.Point(16, 60))) })
  )
  foreach ($action in $actions) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $action[0]; $b.AccessibleName = $action[0]
    $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 0
    $b.Font = $fText; $b.Cursor = 'Hand'
    $b.Add_Click($action[1]); $form.Controls.Add($b)
    $script:dashboardControls += $b
  }
}
function Draw-Dashboard($g, $sections) {
  $scale = $g.DpiX / 96
  $state = $g.Save()
  $g.ScaleTransform($scale, $scale)
  try {
    Dashboard-Text $g 'AI usage' $dashTitle $ink 38 5
    Dashboard-Text $g 'Your limits, resets and renewals at a glance.' $dashSmall $labelInk 18 39
    Dashboard-Text $g 'Click the ≡ button for plans and layouts.' $dashSmall $labelInk 18 76
    $y = 106
    foreach ($section in $sections) {
      $name, $usage, $month = $section
      $stale = Is-Stale $usage
      $cardH = if ($month) { 204 } else { 178 }
      $surface = if ($script:themeDrawn -eq 'dark') { [Drawing.Color]::FromArgb(32, 42, 57) } else { [Drawing.Color]::White }
      Dashboard-Box $g $surface 16 $y 368 $cardH
      Dashboard-Text $g $name $dashName $ink 30 ($y + 12)
      $status = if (-not $usage) { 'Waiting for data' } elseif ($stale) { 'Out of date' } else { 'Latest reading' }
      Dashboard-Text $g $status $dashSmall $labelInk 264 ($y + 16)
      $rowY = $y + 44
      foreach ($row in @(@('Session · 5 hours', $usage.fiveHour), @('Weekly · 7 days', $usage.weekly))) {
        $win = $row[1]
        $hasValue = $null -ne $win -and $null -ne $win.pct
        $value = if ($hasValue) { "$($win.pct)% used" } else { 'Unavailable' }
        $color = if ($stale -or -not $hasValue) { $labelInk } else { Level-Color $win.pct }
        Dashboard-Text $g $row[0] $dashText $ink 30 $rowY
        $valueColor = if ($stale -or -not $hasValue) { $labelInk } elseif ($win.pct -ge 70) { $color } else { $ink }
        Dashboard-Text $g $value $dashText $valueColor 282 $rowY
        Dashboard-Box $g $chip 30 ($rowY + 24) 340 6 3
        if ($hasValue) {
          $width = 340 * [Math]::Max(0, [Math]::Min(100, [double]$win.pct)) / 100
          if ($width -ge 6) { Dashboard-Box $g $color 30 ($rowY + 24) $width 6 3 }
          elseif ($width -gt 0) {
            $b = Brush $color
            try { $g.FillRectangle($b, [float]30, [float]($rowY + 24), [float]$width, [float]6) } finally { $b.Dispose() }
          }
        }
        $reset = if ($win.resetsAt) { 'Resets ' + (Until-Text $win.resetsAt) } else { 'Reset time unavailable' }
        if ($stale) { $reset += ' · last known' }
        Dashboard-Text $g $reset $dashSmall $labelInk 30 ($rowY + 35)
        $rowY += 64
      }
      if ($month) {
        $info = Month-Info $month
        Dashboard-Text $g (Month-Reset $month $info) $dashSmall (Month-ResetColor $month) 30 ($y + 179)
        Dashboard-Text $g ('Month estimate ' + (Month-Text $month)) $dashSmall $labelInk 222 ($y + 179)
      }
      $y += $cardH + 12
    }
    if (-not $sections.Count -and -not $script:data.spotify) {
      Dashboard-Text $g 'No plans found yet' $dashName $ink 24 $y
      Dashboard-Text $g 'Sign in to Claude Code or Codex, then refresh.' $dashSmall $labelInk 24 ($y + 30)
      Dashboard-Text $g 'Add renewal dates in billing.json (see README).' $dashSmall $labelInk 24 ($y + 51)
      $y += 90
    }
    if ($script:data.spotify) {
      Dashboard-Box $g $chip 16 $y 368 42
      Dashboard-Text $g 'Spotify' $dashText $ink 30 ($y + 12)
      Dashboard-Text $g (Plan-Label $script:data.spotify.cancels (Spotify-Date)) $dashText (Plan-Color $script:data.spotify.cancels) 248 ($y + 12)
      $y += 54
    }
    $status = if ($script:out) { 'Refreshing usage…' } elseif ($script:pollError) { 'Could not refresh · retrying automatically' } elseif ($script:updatedAt) { 'Updated ' + $script:updatedAt.ToString('h:mm tt') + ' · checks every minute' } else { 'Connecting to your local usage data…' }
    Dashboard-Text $g $status $dashSmall $labelInk 18 $y
    $footerY = $y + 25
    Dashboard-Text $g 'Click-through overlay · click ≡ for controls' $dashSmall $labelInk 18 ($footerY + 6)
  } finally { $g.Restore($state) }
  for ($i = 0; $i -lt $script:dashboardControls.Count; $i++) {
    $b = $script:dashboardControls[$i]
    $b.SetBounds([int]((18 + ($i % 3) * 123) * $scale), [int]($(if ($i -lt 3) { 66 } else { $footerY }) * $scale), [int](118 * $scale), [int](28 * $scale))
    $selected = $i -lt 3 -and @('both', 'claude', 'codex')[$i] -eq $script:mode
    $b.BackColor = if ($selected) { $ink } else { $chip }
    $b.ForeColor = if ($selected) { $bg } else { $ink }
    if ($i -eq 4) { $b.Enabled = -not $script:out }
  }
  return New-Object Drawing.Size([int](400 * $scale), [int](($footerY + 42) * $scale))
}
