# "At this rate" for widget.ps1's details panel (dot-sourced; uses Until-Text from lib\countdown.ps1).
#
# A percentage answers "how much have I used", not the question you actually have, which is "will I run out
# before this resets". 88% with six days still to go is a problem; 88% with two hours to go is not. Both look
# the same on the bar, so the difference goes in Details, where there is room to say it in words.
#
# The maths is only the two numbers already on screen: the % used, and how much of the window is gone. Nothing
# is fetched and nothing is stored - and because it assumes the next hours look like the last ones, it is always
# worded as an estimate.

# How long each window is. Claude and Codex both reset five hours after the window's first message, and both
# weekly windows are seven days.
$WINDOW_S = @{ fiveHour = 5 * 3600; weekly = 7 * 86400 }
$PACE_MIN_ELAPSED_S = 900   # under 15 minutes in, one busy minute would project to anything

function At-Text($unix) {
  $at = [DateTimeOffset]::FromUnixTimeSeconds([long]$unix).LocalDateTime
  $fmt = if ($at.Date -ne (Get-Date).Date) { 'ddd h:mm tt' } else { 'h:mm tt' }
  return $at.ToString($fmt, [Globalization.CultureInfo]::InvariantCulture)
}

# One indented line for the details panel, or $null when there is nothing honest to say yet.
function Pace-Line($win, $kind) {
  if (-not $win -or -not $win.resetsAt -or $win.pct -le 0) { return $null }
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $left = [double]$win.resetsAt - $now
  if ($left -le 0) { return $null }
  if ($win.pct -ge 100) { return '    At this rate: nothing left until it resets' }
  $elapsed = $WINDOW_S[$kind] - $left
  if ($elapsed -lt $PACE_MIN_ELAPSED_S) { return $null }

  $perSecond = $win.pct / $elapsed
  $toFull = (100 - $win.pct) / $perSecond
  if ($toFull -lt $left) {
    return "    At this rate: full about $(At-Text ($now + $toFull)) ($(Until-Text ($now + $toFull))), before it resets"
  }
  return "    At this rate: about $([int][Math]::Round($win.pct + $perSecond * $left))% by the reset"
}
