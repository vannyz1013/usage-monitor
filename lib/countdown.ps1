# "in 2h 14m" for widget.ps1's details panel (dot-sourced).
# The panel used to give reset times as clock times only ("resets Fri 3:00 AM"), which on a Tuesday is a
# date-arithmetic puzzle. The clock time stays - it is the exact answer - and the countdown goes after it,
# because how long you have left is the thing actually being asked.
#
# All of it is done in unix seconds, on both sides of the subtraction. The first version took the reset time
# into local time and subtracted Get-Date from it, and once produced an answer an hour out: two clocks, two
# chances to disagree about the offset. One clock cannot.

function Until-Text($resetsAt) {
  if (-not $resetsAt) { return '' }
  $left = [double]$resetsAt - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if ($left -le 0) { return 'any moment' }
  if ($left -lt 60) { return 'in under a minute' }
  if ($left -lt 3600) { return "in $([int][Math]::Floor($left / 60))m" }
  if ($left -lt 86400) { return "in $([int][Math]::Floor($left / 3600))h $([int][Math]::Floor(($left % 3600) / 60))m" }
  $days = [int][Math]::Floor($left / 86400)
  return "in $days day$(if ($days -ne 1) { 's' }) $([int][Math]::Floor(($left % 86400) / 3600))h"
}
