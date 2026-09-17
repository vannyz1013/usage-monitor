# The one-time "how to use it" note for widget.ps1 (dot-sourced; uses its $form and $tip).
# Everything the widget can do is behind a click, a hold or a right-click, and none of that is written on it.
# So the very first time it runs on this PC it says so once, under the bar, for 12 seconds. After that the
# marker file keeps it quiet for good; delete the file to see it again.

$hintFile = Join-Path $env:USERPROFILE '.claude\usage-widget-hint.txt'

$hintText = @'
Welcome — your Claude, Codex and Spotify plan limits.

  Click the butterfly     Claude / Codex / both
  Hold the butterfly      change the shape: bar, pole, tall, square
  Drag anywhere           move it
  Right-click             details, light/dark, see-through, exit
  ⟳ refresh   ✕ put it away (the tray butterfly brings it back)

This note is only shown once.
'@

# Called once the first real numbers are in, so it appears under the finished panel and not a placeholder.
function First-Run-Hint {
  if (Test-Path $hintFile) { return }
  try { 'shown' | Set-Content $hintFile } catch { return }
  $tip.Show($hintText, $form, 8, ($form.Height + 4), 12000)
}
