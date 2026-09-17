# A compact card layout with the Mini usage bars plus reset and plan dates.
# Mini remains the smallest readout; this separate shape adds dates without turning the overlay into the full dashboard.

function Summary-ResetDate($win) {
  if (-not $win -or -not $win.resetsAt) { return '—' }
  $at = [DateTimeOffset]::FromUnixTimeSeconds([long]$win.resetsAt).LocalDateTime
  $at.ToString('d MMM h:mm tt', [Globalization.CultureInfo]::InvariantCulture)
}

function Summary-Box($g, $color, $x, $y, $w, $h, $radius = 9) {
  $path = Rounded-Path-At $x $y $w $h $radius
  $b = Brush $color
  try { $g.FillPath($b, $path) } finally { $b.Dispose(); $path.Dispose() }
  $pen = New-Object Drawing.Pen $edge, 1
  $outline = Rounded-Path-At $x $y $w $h $radius
  try { $g.DrawPath($pen, $outline) } finally { $pen.Dispose(); $outline.Dispose() }
}

function Summary-Bar($g, $x, $y, $label, $win, $weekly, $stale, $barW = 72) {
  $g.DrawString($label, $fSmall, (Brush $labelInk), $x, $y)
  $barX = $x + 22
  $barY = $y + 4
  $g.FillRectangle((Brush $track), $barX, $barY, $barW, 7)
  if ($win) {
    $fill = if ($stale) { $muted } else { Level-Color $win.pct }
    $width = [int]($barW * [Math]::Min(100, [double]$win.pct) / 100)
    if ($width -gt 0) { $g.FillRectangle((Brush $fill), $barX, $barY, $width, 7) }
    $txt = "$($win.pct)%" + $(if ($stale) { '?' })
  } else { $txt = '—' }
  $pctColor = if ($stale) { $muted } elseif ($win -and [int]$win.pct -ge 70) { Level-Color ([int]$win.pct) } else { $ink }
  $g.DrawString($txt, $fText, (Brush $pctColor), ($barX + $barW + 8), ($y - 2))
}

function Summary-ResetRow($g, $x, $y, $label, $win) {
  $g.DrawString($label, $fSmall, (Brush $labelInk), $x, $y)
  $g.DrawString((Summary-ResetDate $win), $fSmall, (Brush $ink), ($x + 24), $y)
}

function Summary-Card($g, $x, $y, $w, $h, $name, $usage, $month, $hasMonth) {
  Summary-Box $g $chip $x $y $w $h 9
  $stale = Is-Stale $usage
  $g.DrawString($name, $fName, (Brush $ink), ($x + 12), ($y + 8))
  if ($stale) { $g.DrawString('last known', $fSmall, (Brush $muted), ($x + $w - 58), ($y + 11)) }

  Summary-Bar $g ($x + 12) ($y + 29) '5h' $usage.fiveHour $false $stale
  Summary-Bar $g ($x + 12) ($y + 49) '7d' $usage.weekly $true $stale

  Summary-ResetRow $g ($x + 12) ($y + 70) '5h' $usage.fiveHour
  Summary-ResetRow $g ($x + 12) ($y + 85) '7d' $usage.weekly

  if ($hasMonth) {
    $g.FillRectangle((Brush $edge), ($x + 12), ($y + 101), ($w - 24), 1)
    $monthText = if ($month -and $null -ne $month.pct) { "mo ~$($month.pct)% used" } else { 'mo —' }
    $monthColor = if ($month -and $null -ne $month.pct) { Month-Color $month } else { $labelInk }
    $g.DrawString($monthText, $fSmall, (Brush $monthColor), ($x + 12), ($y + 106))
    if ($month) {
      $info = Month-Info $month
      if ($info) {
        $plan = Month-Reset $month $info
        $g.DrawString($plan, $fPlan, (Brush (Month-ResetColor $month)), ($x + 88), ($y + 104))
      }
    }
  }
}

function Draw-Summary($g, $sections) {
  $g.DrawString('AI usage', $fName, (Brush $ink), 42, 4)
  $g.DrawString('% used · reset dates · plan dates', $fSmall, (Brush $labelInk), 42, 19)

  $count = $sections.Count
  $cardW = if ($count -gt 1) { 218 } else { 286 }
  $gap = 8
  $left = 10
  $hasMonth = Has-MonthRow $sections
  $cardH = if ($hasMonth) { 132 } else { 112 }
  $cardY = 34
  $maxW = if ($count) { ($left * 2) + ($count * $cardW) + ([Math]::Max(0, $count - 1) * $gap) } else { 300 }

  for ($i = 0; $i -lt $count; $i++) {
    $name, $usage, $month = $sections[$i]
    $x = $left + $i * ($cardW + $gap)
    Summary-Card $g $x $cardY $cardW $cardH $name $usage $month $hasMonth
  }

  $y = $cardY + $cardH
  if (-not $count) {
    Summary-Box $g $chip $left $cardY ($maxW - ($left * 2)) 52 9
    $g.DrawString('No Claude or Codex usage yet', $fText, (Brush $ink), ($left + 12), ($cardY + 12))
    $g.DrawString('Refresh after signing in to a provider.', $fSmall, (Brush $labelInk), ($left + 12), ($cardY + 32))
    $y += 60
  }

  if ($script:data -and $script:data.spotify) {
    $y += 8
    $stripW = $maxW - ($left * 2)
    Summary-Box $g $chip $left $y $stripW 34 9
    $s = $script:data.spotify
    $g.DrawString($s.name, $fName, (Brush $ink), ($left + 12), ($y + 8))
    $label = Plan-Label $s.cancels (Spotify-Date)
    $g.DrawString($label, $fPlan, (Brush (Plan-Color $s.cancels)), ($left + 92), ($y + 8))
    if ($s.price) { $g.DrawString($s.price, $fSmall, (Brush $labelInk), ($left + $stripW - (TextW $g $s.price $fSmall) - 12), ($y + 11)) }
    $y += 34
  }

  return New-Object Drawing.Size([int]$maxW, [int]($y + 8))
}
