# How much you can see through the widget (dot-sourced by widget.ps1; uses its $form, $bg and $menu).
#
# It sits on top of everything, so on a busy screen it hides whatever is under it - the taskbar especially, where
# it covered buttons that then could not be pressed. Three levels, in the right-click menu and remembered:
#
#   solid   the light blue panel, as it always was. The default: it is the only one that stays readable over a
#           busy page, and ✕ now puts the widget away entirely, so it is easy enough to get out of the way
#   soft    the whole window faded, enough to read what is behind it. Solid to clicks, draggable anywhere
#   ghost   **one-line bar only.** The light blue is gone: only the text, bars and butterfly are left floating, and
#           everything else is see-through AND click-through, so the taskbar and windows underneath still take
#           clicks. The pole, vertical and square panels ignore it and stay solid - see Ghost-Mode below
#
# Ghost uses TransparencyKey: Windows makes exactly the pixels of that colour both invisible and click-through.
# So in ghost the widget is dragged by something actually drawn - its numbers, the bars, the trim or the butterfly -
# and Draw-Buttons in widget.ps1 puts a small solid chip behind the refresh and close glyphs so those stay easy to
# hit. Nothing else is needed: the panel and its blank space are simply not there any more.

$seeFile = Join-Path $env:USERPROFILE '.claude\usage-widget-seethrough.txt'
$seeLevels = 'ghost', 'soft', 'solid'
$SEE_SOFT = 0.78   # faded enough to read through, solid enough to still read the numbers

$script:seeThrough = 'solid'
if (Test-Path $seeFile) {
  $saved = (Get-Content $seeFile -Raw).Trim()
  if ($saved -in $seeLevels) { $script:seeThrough = $saved }
}

# Ghost only applies to the one-line bar, which is the shape it was asked for: a thin strip lying over the taskbar,
# where having no panel is the whole point. The pole, vertical and square layouts ARE panels. Take the panel away and
# the ring gauges lose their antialiased edges into the keyed-out colour, the labels have nothing holding them
# together, and the buttons float off in a corner - marks scattered over whatever is behind them. Those three stay
# solid whatever this is set to, and the setting is remembered for when the bar comes back.
function Ghost-Mode { $script:seeThrough -eq 'ghost' -and $script:layout -eq 'horizontal' }

function Apply-SeeThrough {
  $form.Opacity = if ($script:seeThrough -eq 'soft') { $SEE_SOFT } else { 1.0 }
  # Empty puts the background back rather than leaving holes in it.
  $form.TransparencyKey = if (Ghost-Mode) { $bg } else { [Drawing.Color]::Empty }
}

function Set-SeeThrough($name) {
  $script:seeThrough = $name
  foreach ($k in $seeItems.Keys) { $seeItems[$k].Checked = ($k -eq $name) }
  try { $name | Set-Content $seeFile } catch {}
  Apply-SeeThrough
  $form.Invalidate()
}
