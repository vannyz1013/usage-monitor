# The one-time "how to use it" note for widget.ps1 (dot-sourced; uses its $form and $tip).
# The readout is click-through; controls live on the small ≡ handle and in the pet/tray menus. The first time
# it runs on this PC it explains that once, under the widget, for 12 seconds. After that the
# marker file keeps it quiet for good; delete the file to see it again.

$hintFile = Join-Path $env:USERPROFILE '.claude\usage-widget-hint.txt'

$hintText = @'
Welcome — your Claude, Codex and Spotify plan limits.

  Click ≡                   plans, details, layouts and settings
  Drag ≡                    move the widget
  Pet butterfly             show usage; click again to hide it
  Command Center            Usage settings
  Usage area                click-through to the app underneath

This note is only shown once.
'@

# Called once the first real numbers are in, so it appears under the finished panel and not a placeholder.
function First-Run-Hint {
  if (Test-Path $hintFile) { return }
  try { 'shown' | Set-Content $hintFile } catch { return }
  $tip.Show($hintText, $form, 8, ($form.Height + 4), 12000)
}
