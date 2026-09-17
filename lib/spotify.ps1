# Spotify line for widget.ps1 (dot-sourced; uses its colours, fonts, drawing helpers and lib\plan-status.ps1).
# Spotify has no usage data, so it gets one "Spotify   Renews 10 Oct" line at the bottom of the vertical and square
# panels, and a tooltip line with its price. Data: usage-json.js "spotify" (lib\spotify.js).

$spotifyRowH = 22

function Spotify-Date { [DateTime]::ParseExact($script:data.spotify.next, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) }

# Height the Spotify line needs (0 when billing.json has no Spotify entry).
function Spotify-Height { if ($script:data.spotify) { 6 + $spotifyRowH } else { 0 } }

# Width of "Spotify  Renews 10 Oct", so the panel can fit it.
function Spotify-Width($g) {
  $s = $script:data.spotify
  if (-not $s) { return 0 }
  return (TextW $g $s.name $fName) + 12 + (TextW $g (Plan-Label $s.cancels (Spotify-Date)) $fPlan)
}

# A thin separator, then the name on the left and "Renews 10 Oct" on the right of $w.
function Draw-Spotify($g, $x, $y, $w) {
  $s = $script:data.spotify
  if (-not $s) { return }
  $g.FillRectangle((Brush $accent), $x, ($y + 2), $w, 1)
  $y += 6
  $g.DrawString($s.name, $fName, (Brush $ink), $x, (TextY $g $fName $y $spotifyRowH))
  $label = Plan-Label $s.cancels (Spotify-Date)
  $g.DrawString($label, $fPlan, (Brush (Plan-Color $s.cancels)), ($x + $w - (TextW $g $label $fPlan)), (TextY $g $fPlan $y $spotifyRowH))
}

# On the one-line bar it is the last thing on the row, after a separator, like another product:
# "| Spotify  Renews 17 Sep". Returns the x after it.
function Draw-SpotifyInline($g, $x) {
  $s = $script:data.spotify
  if (-not $s) { return $x }
  $g.FillRectangle((Brush $accent), ($x - 3), 7, 1, ($script:rowH - 14))
  $x += 6
  $g.DrawString($s.name, $fName, (Brush $ink), $x, (TextY $g $fName))
  $x += (TextW $g $s.name $fName) + 8
  $label = Plan-Label $s.cancels (Spotify-Date)
  $g.DrawString($label, $fPlan, (Brush (Plan-Color $s.cancels)), $x, (TextY $g $fPlan))
  return $x + (TextW $g $label $fPlan) + 8
}

# Tooltip line: "Spotify: Renews 10 Oct ($11.99)".
function Spotify-TooltipLine {
  $s = $script:data.spotify
  if (-not $s) { return $null }
  "$($s.name): $(Plan-Label $s.cancels (Spotify-Date))" + $(if ($s.price) { " ($($s.price))" })
}
