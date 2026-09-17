# The one-line bar's compact setting, for widget.ps1 (dot-sourced).
# With Claude, Codex and Spotify all shown, the bar is about 1170 px of a 1536 px screen - most of the taskbar.
# Compact leaves the month row out of the bar only, which takes roughly 360 px off it. The month is still
# there in right-click -> Details, and in the pole, tall and square shapes, which have the room for it.
# Off by default: nothing disappears unless it is asked for.

$compactFile = Join-Path $env:USERPROFILE '.claude\usage-widget-compact.txt'
$script:compact = (Test-Path $compactFile) -and (Get-Content $compactFile -Raw).Trim() -eq 'on'

# Only the bar. The other three shapes stack downwards, where an extra row costs nothing.
function Compact-Bar { $script:compact -and $script:layout -eq 'horizontal' }

function Set-Compact($on) {
  $script:compact = $on
  $compactItem.Checked = $on
  try { $(if ($on) { 'on' } else { 'off' }) | Set-Content $compactFile } catch {}
  $form.Invalidate()   # Paint refits the width, keeping the right edge put
}
