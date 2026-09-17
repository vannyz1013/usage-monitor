# Light / dark colours for widget.ps1 (dot-sourced before the form is made; everything else draws with
# these variables, so a theme change is just new values and a repaint).
#
# Three settings, in right-click -> Look, and remembered:
#   auto   follow Windows (Settings -> Personalisation -> Colours -> "Choose your default app mode"). The default.
#   light  the light blue panel the widget has always had
#   dark   a deep navy panel for a dark desktop, where the light blue was a torch in the corner
#
# Auto re-reads Windows every 30 s (widget.ps1's second timer), so switching Windows to dark switches the
# widget too, without a restart.

$themeFile = Join-Path $env:USERPROFILE '.claude\usage-widget-theme.txt'
$themeNames = 'auto', 'light', 'dark'

$script:theme = 'auto'
if (Test-Path $themeFile) {
  $saved = (Get-Content $themeFile -Raw).Trim()
  if ($saved -in $themeNames) { $script:theme = $saved }
}

$PERSONALIZE = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'

# What Windows itself is set to: 'dark' or 'light'. Anything unreadable counts as light, the older default.
function Windows-Theme {
  try {
    $v = (Get-ItemProperty -Path $PERSONALIZE -Name AppsUseLightTheme -ErrorAction Stop).AppsUseLightTheme
    if ($v -eq 0) { return 'dark' }
  } catch {}
  return 'light'
}

# The theme actually drawn: 'auto' asks Windows.
function Theme-Now { if ($script:theme -eq 'auto') { Windows-Theme } else { $script:theme } }

$rgb = { param($r, $g, $b) [Drawing.Color]::FromArgb($r, $g, $b) }

# Both palettes carry the same names. Contrast on their own background: text >= 7:1, labels >= 5:1,
# Renews / Ends >= 5:1 - they are small and semibold, and sit on the panel, not on a bar.
$palettes = @{
  light = @{
    bg = & $rgb 234 245 255; track = & $rgb 255 255 255; accent = & $rgb 110 175 235
    warn = & $rgb 235 135 50; danger = & $rgb 210 30 60
    ink = & $rgb 30 70 115; muted = & $rgb 100 135 170; labelInk = & $rgb 55 90 130
    wing = & $rgb 160 210 250; wing2 = & $rgb 70 145 215
    renewGreen = & $rgb 0 115 45; edge = & $rgb 150 195 235; chip = & $rgb 205 228 248
  }
  dark = @{
    bg = & $rgb 24 31 43; track = & $rgb 52 63 80; accent = & $rgb 96 165 235
    warn = & $rgb 240 165 75; danger = & $rgb 245 95 120
    ink = & $rgb 228 238 250; muted = & $rgb 125 145 170; labelInk = & $rgb 158 182 210
    wing = & $rgb 96 150 210; wing2 = & $rgb 175 215 250
    renewGreen = & $rgb 85 205 135; edge = & $rgb 62 80 105; chip = & $rgb 46 58 76
  }
}

# Load a palette into the drawing variables widget.ps1 and lib\*.ps1 use.
function Use-Palette($name) {
  $p = $palettes[$name]
  foreach ($k in $p.Keys) { Set-Variable -Name $k -Value $p[$k] -Scope Script }
  $script:themeDrawn = $name
}
Use-Palette (Theme-Now)

# Repaint in the current theme. $form doesn't exist yet on the first call from this file, hence the guard.
function Paint-Theme {
  Use-Palette (Theme-Now)
  if (-not $form -or -not $menu) { return }
  $form.BackColor = $bg
  $menu.BackColor = $bg
  $menu.ForeColor = $ink
  foreach ($item in $menu.Items) { Item-Theme $item }
  if (Get-Command Apply-SeeThrough -ErrorAction SilentlyContinue) { Apply-SeeThrough }  # ghost keys out $bg
  $form.Invalidate()
}

# Menus are drawn by Windows, which doesn't follow our palette: colour each item, submenus included.
function Item-Theme($item) {
  $item.BackColor = $bg
  $item.ForeColor = $ink
  if ($item.HasDropDownItems) {
    $item.DropDown.BackColor = $bg
    foreach ($sub in $item.DropDownItems) { Item-Theme $sub }
  }
}

function Set-Theme($name) {
  $script:theme = $name
  foreach ($k in $themeItems.Keys) { $themeItems[$k].Checked = ($k -eq $name) }
  try { $name | Set-Content $themeFile } catch {}
  Paint-Theme
}

# Called on the widget's slow tick: picks up a Windows light/dark switch while 'auto'.
function Follow-Windows-Theme {
  if ($script:theme -eq 'auto' -and (Windows-Theme) -ne $script:themeDrawn) { Paint-Theme }
}
