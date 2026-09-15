# Which products the widget shows, for widget.ps1 (dot-sourced).
# Not everyone has Claude, Codex and Spotify. A product is shown only if this PC has something for it:
#   - usage (Claude Code / Codex logged in or used here), or
#   - a pay day in billing.json (you subscribe, even if you haven't used it here yet).
# Its month row needs a billing.json entry, and Spotify needs its own entry (lib\spotify.ps1).
# Until the first reading arrives, both are shown as placeholders so the window doesn't jump from tiny to full.

function Has-Product($d, $key) { $null -ne $d.$key -or $null -ne $d.month.$key }

# @(@(name, usage, month), ...) for the chosen mode (both / claude / codex), leaving out products this PC
# doesn't have. If the chosen one isn't there but the other is, the other is shown rather than nothing.
function Get-Sections($d, $mode) {
  $all = @(@('Claude', 'claude'), @('Codex', 'codex'))
  $wanted = @($all | Where-Object { $mode -eq 'both' -or $mode -eq $_[1] })
  if ($d) {
    $wanted = @($wanted | Where-Object { Has-Product $d $_[1] })
    if (-not $wanted.Count) { $wanted = @($all | Where-Object { Has-Product $d $_[1] }) }
  }
  $sections = @()
  foreach ($p in $wanted) { $sections += , @($p[0], $d.($p[1]), $d.month.($p[1])) }
  return , $sections
}

# True if any shown product has a billing month, i.e. the "mo" row is worth drawing.
function Has-MonthRow($sections) { @($sections | Where-Object { $null -ne $_[2] }).Count -gt 0 }

# Nothing at all on this PC: one line telling the user what the widget looks for. Returns its width.
$nothingText = 'No Claude, Codex or Spotify found (see billing.example.json)'
function Nothing-Found($d, $sections) { $d -and -not $sections.Count -and -not $d.spotify }
function Draw-NothingFound($g, $x, $y, $h) {
  $g.DrawString($nothingText, $fSmall, (Brush $labelInk), $x, (TextY $g $fSmall $y $h))
  return (TextW $g $nothingText $fSmall)
}
