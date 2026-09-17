# Hover feedback for widget.ps1 (dot-sourced; uses its $form, colours and $script:btnAt).
# ⟳ and ✕ were two thin glyphs with nothing round them: you could not tell they were buttons, or whether the
# pointer was on one before clicking. Now the one under the pointer gets a rounded chip, and the pointer itself
# says what a press will do - a hand over the two buttons and over the butterfly (which changes what is shown),
# the move cursor everywhere else, because everywhere else drags the widget.

$script:hoverBtn = $null

# 'refresh', 'close' or $null for the pointer's position. Shares the hit areas with the click handler,
# so what lights up is exactly what a click hits.
function Button-Under($e) {
  if (-not (On-Buttons $e)) { return $null }
  if (On-Close $e) { return 'close' }
  return 'refresh'
}

# Returns $true if the repaint is needed (the hovered button changed).
function Set-Hover($e) {
  $now = if ($e) { Button-Under $e } else { $null }
  if ($now -eq $script:hoverBtn) { return $false }
  $script:hoverBtn = $now
  return $true
}

function Hover-Cursor($e) {
  if ((On-Buttons $e) -or (On-Butterfly $e)) { return 'Hand' }
  return 'SizeAll'
}

# The chip behind the hovered glyph. Ghost mode already gives both buttons a solid chip to be pressed on
# (lib\see-through.ps1), so there it brightens that one instead of adding a second.
function Draw-Hover($g, $bx, $by) {
  if (-not $script:hoverBtn) { return }
  $x = if ($script:hoverBtn -eq 'close') { $bx + 22 } else { $bx - 2 }
  $path = Rounded-Path-At $x ($by + 3) 24 ($script:rowH - 6) 5
  $g.FillPath((Brush $chip), $path)
  $path.Dispose()
}

# Rounded rectangle anywhere, not just at the window's origin (lib\rounded.ps1 shapes the window itself).
function Rounded-Path-At($x, $y, $w, $h, $r) {
  $path = New-Object Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $path.AddArc($x, $y, $d, $d, 180, 90)
  $path.AddArc(($x + $w - $d), $y, $d, $d, 270, 90)
  $path.AddArc(($x + $w - $d), ($y + $h - $d), $d, $d, 0, 90)
  $path.AddArc($x, ($y + $h - $d), $d, $d, 90, 90)
  $path.CloseFigure()
  return $path
}
