# A compact mini readout with reset dates and plan renewal dates.
# It keeps the small two-bar pattern, while putting the dates underneath each product.

function Summary-ResetDate($win) {
  if (-not $win -or -not $win.resetsAt) { return '—' }
  $at = [DateTimeOffset]::FromUnixTimeSeconds([long]$win.resetsAt).LocalDateTime
  $at.ToString('d MMM h:mm tt', [Globalization.CultureInfo]::InvariantCulture)
}

function Summary-ResetLine($usage) {
  $five = if ($usage -and $usage.fiveHour) { '5h ' + (Summary-ResetDate $usage.fiveHour) } else { '5h —' }
  $week = if ($usage -and $usage.weekly) { '7d ' + (Summary-ResetDate $usage.weekly) } else { '7d —' }
  "$five  ·  $week"
}

function Draw-Summary($g, $sections) {
  $oldRowH = $script:rowH
  $rowH = 25
  $script:rowH = $rowH
  try {
    $g.DrawString('Usage: % used · reset dates', $fSmall, (Brush $labelInk), 34, (TextY $g $fSmall))
    $y = $rowH + 2
    $maxX = 280

    foreach ($section in $sections) {
      $name, $usage, $month = $section
      $g.DrawString($name, $fName, (Brush $ink), 10, (TextY $g $fName $y))
      $x = 72
      $stale = Is-Stale $usage
      $x = Draw-Window $g $x $y '5h' $usage.fiveHour $false $stale $false
      $x = Draw-Window $g $x $y '7d' $usage.weekly $true $stale $false
      $maxX = [Math]::Max($maxX, $x)

      $resetLine = Summary-ResetLine $usage
      $g.DrawString($resetLine, $fSmall, (Brush $labelInk), 10, ($y + $rowH - 1))
      $maxX = [Math]::Max($maxX, 10 + (TextW $g $resetLine $fSmall))
      $block = $rowH + 16

      if ($month) {
        $info = Month-Info $month
        if ($info) {
          $plan = Month-Reset $month $info
          $g.DrawString($plan, $fPlan, (Brush (Month-ResetColor $month)), 10, ($y + $rowH + 14))
          $maxX = [Math]::Max($maxX, 10 + (TextW $g $plan $fPlan))
          $block += 14
        }
      }
      $y += $block + 4
    }

    if (-not $sections.Count) {
      $message = if ($script:data -and $script:data.spotify) { 'No usage yet' } else { 'No usage yet; open details from the tray' }
      $g.DrawString($message, $fSmall, (Brush $labelInk), 10, (TextY $g $fSmall $y))
      $maxX = [Math]::Max($maxX, 10 + (TextW $g $message $fSmall))
      $y += $rowH + 4
    }

    if ($script:data -and $script:data.spotify) {
      $g.FillRectangle((Brush $accent), 10, ($y + 2), ($maxX - 20), 1)
      $s = $script:data.spotify
      $g.DrawString($s.name, $fName, (Brush $ink), 10, ($y + 7))
      $label = Plan-Label $s.cancels (Spotify-Date)
      $labelX = 10 + (TextW $g $s.name $fName) + 12
      $g.DrawString($label, $fPlan, (Brush (Plan-Color $s.cancels)), $labelX, ($y + 7))
      $maxX = [Math]::Max($maxX, $labelX + (TextW $g $label $fPlan))
      $y += 28
    }

    return New-Object Drawing.Size([int]($maxX + 14), [int]($y + 6))
  } finally {
    $script:rowH = $oldRowH
  }
}
