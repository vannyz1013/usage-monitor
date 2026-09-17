# Solid/faded backgrounds and full mouse pass-through for the mini overlay.
$seeFile = Join-Path $env:USERPROFILE '.claude\usage-widget-seethrough.txt'
$seeLevels = 'soft', 'solid'
$SEE_SOFT = 0.78   # faded enough to read through, solid enough to still read the numbers

# Layered + transparent passes clicks through the entire usage window, including its text.
Add-Type -Namespace Widget -Name Overlay -MemberDefinition @'
[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int index);
[DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int index, int value);
'@
# Every shape is an informational overlay. Only the separate menu handle is interactive.
function Widget-PassThrough { $true }

$script:seeThrough = 'solid'
if (Test-Path $seeFile) {
  $saved = (Get-Content $seeFile -Raw).Trim()
  if ($saved -in $seeLevels) { $script:seeThrough = $saved }
}

# Legacy drawing helpers call this; the broken color-key mode has been removed.
function Ghost-Mode { $false }

function Apply-SeeThrough {
  $passThrough = Widget-PassThrough
  $form.Opacity = if ($passThrough) { if ($script:seeThrough -eq 'soft') { $SEE_SOFT } else { 0.86 } } else { 1.0 }
  # Empty puts the background back rather than leaving holes in it.
  $form.TransparencyKey = [Drawing.Color]::Empty
  $style = [Widget.Overlay]::GetWindowLong($form.Handle, -20)
  if ($passThrough) { $style = $style -bor 0x80000 -bor 0x20 -bor 0x08000000 }
  else { $style = $style -band (-bnot (0x20 -bor 0x08000000)) }
  [void][Widget.Overlay]::SetWindowLong($form.Handle, -20, $style)
}

function Set-SeeThrough($name) {
  $script:seeThrough = $name
  foreach ($k in $seeItems.Keys) { $seeItems[$k].Checked = ($k -eq $name) }
  try { $name | Set-Content $seeFile } catch {}
  Apply-SeeThrough
  $form.Invalidate()
}
