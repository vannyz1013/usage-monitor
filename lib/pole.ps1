# The pole layout's rows (dot-sourced by widget.ps1; uses its colours, fonts and drawing helpers).
#
# The pole is a stick: one narrow column, everything stacked down it, every word the right way up. The first try
# turned the whole one-line bar on its side, which fitted the shape but left the text unreadable.
#
# A row is three lines - the label (5h / 7d / mo), a bar the width of the stick, then the percentage - so nothing
# has to fit side by side. Reset times are the one thing dropped: they are what makes a row wide. They are still in
# the tooltip and in the horizontal, vertical and square layouts.

$poleLabelH = 13
$poleBarH = 7
$polePctH = 17

# Spotify has no usage, so on the stick it is its name with its Renews / Ends line stacked under it, like every
# other row here. Nothing at all when billing.json has no Spotify entry.
function Draw-PoleSpotify($g, $y, $w) {
  $s = $script:data.spotify
  if (-not $s) { return $y }
  $g.FillRectangle((Brush $accent), 10, ($y + 2), ($w - 20), 1)
  $y += 6
  Draw-Centered $g $s.name $fName $ink 0 $y $w 20
  $y += 20
  Draw-Centered $g (Plan-Label $s.cancels (Spotify-Date)) $fPlan (Plan-Color $s.cancels) 0 $y $w 16
  $y + 16
}

# Wide enough for the widest thing that goes on it: a product name, or "~100%".
function Pole-Width($g, $sections) {
  $w = TextW $g '~100%?' $fText
  foreach ($section in $sections) { $w = [Math]::Max($w, (TextW $g $section[0] $fName)) }
  foreach ($label in (Pole-MonthLabels $sections)) { $w = [Math]::Max($w, (TextW $g $label $fPlan)) }
  $sp = $script:data.spotify
  if ($sp) {
    $w = [Math]::Max($w, (TextW $g $sp.name $fName))
    $w = [Math]::Max($w, (TextW $g (Plan-Label $sp.cancels (Spotify-Date)) $fPlan))
  }
  $w + 16
}

# "Ends 22 Sep" / "Renews 17 Sep" go under the mo bar, and they are the widest line on the stick.
function Pole-MonthLabels($sections) {
  $out = @()
  foreach ($section in $sections) {
    $info = if ($section[2]) { Month-Info $section[2] }
    if ($info) { $out += Month-Reset $section[2] $info }
  }
  $out
}

# The bar itself: full width of the stick less a small margin, filled left to right.
function Draw-PoleBar($g, $y, $w, $pct, $color) {
  $x = 8
  $g.FillRectangle((Brush $track), $x, $y, ($w - 16), $poleBarH)
  if ($null -ne $pct) {
    $g.FillRectangle((Brush $color), $x, $y, [int](($w - 16) * [Math]::Min(100, $pct) / 100), $poleBarH)
  }
}

# One 5h or 7d row; returns the y after it.
function Draw-PoleRow($g, $y, $w, $label, $win, $stale) {
  Draw-Centered $g $label $fSmall $labelInk 0 $y $w $poleLabelH
  $y += $poleLabelH
  $fill = if ($stale) { $muted } else { Level-Color ([int]$win.pct) }
  Draw-PoleBar $g $y $w $(if ($win) { $win.pct }) $fill
  $y += $poleBarH
  $txt = if ($win) { "$($win.pct)%" + $(if ($stale) { '?' }) } else { '—' }
  $pctColor = if ($stale) { $muted } elseif ([int]$win.pct -ge 70) { Level-Color ([int]$win.pct) } else { $ink }
  Draw-Centered $g $txt $fText $pctColor 0 $y $w $polePctH
  $y + $polePctH + 3
}

# The billing-month row, with its green Renews / red Ends line in place of a reset time.
function Draw-PoleMonth($g, $y, $w, $m) {
  Draw-Centered $g 'mo' $fSmall $labelInk 0 $y $w $poleLabelH
  $y += $poleLabelH
  Draw-PoleBar $g $y $w $m.pct (Level-Color $m.pct)
  $y += $poleBarH
  Draw-Centered $g (Month-Text $m) $fText (Month-Color $m) 0 $y $w $polePctH
  $y += $polePctH
  $info = Month-Info $m
  if ($info) {
    Draw-Centered $g (Month-Reset $m $info) $fPlan (Month-ResetColor $m) 0 $y $w 16
    $y += 16
  }
  $y + 3
}
