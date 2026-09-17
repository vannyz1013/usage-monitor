# Rounded corners and a thin edge for widget.ps1 (dot-sourced; uses its $form and colours).
# A borderless WinForms window is a bare rectangle with hard corners: next to anything else on the desktop it
# reads as an error box. Windows can clip a window to any shape, so the panel gets 8 px corners and a 1 px edge
# drawn just inside them, which is also what separates a dark panel from a dark wallpaper.
#
# Ghost mode (lib\see-through.ps1) has no panel at all - only floating numbers - so it gets no edge. The corners
# are still clipped, which costs nothing there.

$CORNER = 8

function Rounded-Path($w, $h, $r) {
  $path = New-Object Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $path.AddArc(0, 0, $d, $d, 180, 90)
  $path.AddArc(($w - $d - 1), 0, $d, $d, 270, 90)
  $path.AddArc(($w - $d - 1), ($h - $d - 1), $d, $d, 0, 90)
  $path.AddArc(0, ($h - $d - 1), $d, $d, 90, 90)
  $path.CloseFigure()
  return $path
}

# Clip the window to rounded corners. Called after every resize (the shape has to match the new size).
function Apply-Corners {
  $w = $form.ClientSize.Width; $h = $form.ClientSize.Height
  if ($w -lt 2 * $CORNER -or $h -lt 2 * $CORNER) { return }
  if ($script:shapedAt -eq "$w x $h") { return }
  $path = Rounded-Path $w $h $CORNER
  $old = $form.Region
  $form.Region = New-Object Drawing.Region $path
  if ($old) { $old.Dispose() }
  $path.Dispose()
  $script:shapedAt = "$w x $h"
}

# The edge, drawn last so nothing sits on top of it.
function Draw-Edge($g) {
  if (Ghost-Mode) { return }
  $path = Rounded-Path $form.ClientSize.Width $form.ClientSize.Height $CORNER
  $pen = New-Object Drawing.Pen $edge, 1
  $g.DrawPath($pen, $path)
  $pen.Dispose()
  $path.Dispose()
}
