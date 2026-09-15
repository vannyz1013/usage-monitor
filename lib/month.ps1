# Billing-month row for widget.ps1 (dot-sourced; uses its colours, fonts and drawing helpers).
# A billing month runs pay day to pay day (billing.json). Its % is an estimate from usage-json.js / lib\month.js:
# no provider has a monthly limit, so it is measured against the weekly limit times the weeks in the month.
# Shown with "~" so it can't pass for an official number.

# Dates of the billing month, how far through it we are and the days left.
function Month-Info($m) {
  if (-not $m) { return $null }
  $inv = [Globalization.CultureInfo]::InvariantCulture
  $start = [DateTime]::ParseExact($m.start, 'yyyy-MM-dd', $inv)
  $end = [DateTime]::ParseExact($m.end, 'yyyy-MM-dd', $inv)
  $now = Get-Date
  @{
    start = $start; end = $end
    elapsed = [Math]::Min(1, [Math]::Max(0, ($now - $start).TotalDays / ($end - $start).TotalDays))
    daysLeft = [Math]::Max(0, [int][Math]::Ceiling(($end - $now).TotalDays))
  }
}

# When the billing month ends (the next pay day), like the other rows' reset time: "↻Tue 22 Sep".
function Month-Reset($info) { '↻' + $info.end.ToString('ddd d MMM', [Globalization.CultureInfo]::InvariantCulture) }

function Month-Text($m) {
  if ($null -eq $m.pct) { return '—' }
  return "~$($m.pct)%"
}

function Month-Color($m) {
  if ($null -ne $m.pct -and $m.pct -ge 70) { return Level-Color $m.pct }
  return $ink
}

# "mo ▬▬▬ ~74% ↻Tue 22 Sep" — same columns as Draw-Window; returns the x after it.
function Draw-Month($g, $x, $y, $m) {
  $g.DrawString('mo', $fSmall, (Brush $muted), $x, (TextY $g $fSmall $y))
  $x += (TextW $g '5h' $fSmall)
  $barY = [int]($y + $script:rowH / 2) - 3
  $g.FillRectangle((Brush $track), $x, $barY, 40, 6)
  if ($null -ne $m.pct) { $g.FillRectangle((Brush (Level-Color $m.pct)), $x, $barY, [int](40 * [Math]::Min(100, $m.pct) / 100), 6) }
  $x += 42
  $g.DrawString((Month-Text $m), $fText, (Brush (Month-Color $m)), $x, (TextY $g $fText $y))
  $x += (TextW $g '100%?' $fText)
  $info = Month-Info $m
  if ($info) { $g.DrawString((Month-Reset $info), $fSmall, (Brush $muted), $x, (TextY $g $fSmall $y)) }
  return $x + (TextW $g '↻Wed 12:59PM' $fSmall) + 8
}

# Square layout month cell: ring of the estimated month %, when it ends below.
function Draw-MonthRing($g, $x, $y, $w, $d, $m) {
  $rx = $x + [int](($w - $d) / 2)
  $g.DrawEllipse((New-Object Drawing.Pen $track, 5), $rx, $y, $d, $d)
  if ($null -ne $m.pct) {
    $g.DrawArc((New-Object Drawing.Pen (Level-Color $m.pct), 5), $rx, $y, $d, $d, -90, [float](360 * [Math]::Min(100, $m.pct) / 100))
  }
  Draw-Centered $g (Month-Text $m) $fSmall (Month-Color $m) $x $y $w $d
  $info = Month-Info $m
  if ($info) { Draw-Centered $g (Month-Reset $info) $fSmall $muted $x ($y + $d + 2) $w 16 }
}

# Tooltip line: "  Month ~74% used (estimate), 22 Aug → 22 Sep, 6 days left, 2.1B tokens".
function Month-TooltipLine($m) {
  $mi = Month-Info $m
  if (-not $mi) { return $null }
  $inv = [Globalization.CultureInfo]::InvariantCulture
  "  Month ~$($m.pct)% used (estimate), $($mi.start.ToString('d MMM', $inv)) → $($mi.end.ToString('d MMM', $inv)), $($mi.daysLeft) days left, $(Short-Num $m.total) tokens"
}
