# An independent, clickable menu handle over the click-through mini readout.
# A child control would inherit the readout's mouse transparency, so use an owned form.
function Sync-MiniHandle {
  if (-not $script:miniHandle -or $script:miniHandle.IsDisposed) { return }
  if (-not $form.Visible) { $script:miniHandle.Hide(); return }
  $script:miniHandle.Location = New-Object Drawing.Point(($form.Left + 3), ($form.Top + 3))
  $script:miniHandle.BackColor = $chip
  $script:miniHandleButton.BackColor = $chip
  $script:miniHandleButton.ForeColor = $ink
  if (-not $script:miniHandle.Visible) { $script:miniHandle.Show($form) }
}

function Initialize-MiniHandle {
  $script:miniHandle = New-Object Windows.Forms.Form
  $script:miniHandle.FormBorderStyle = 'None'
  $script:miniHandle.ShowInTaskbar = $false
  $script:miniHandle.TopMost = $true
  $script:miniHandle.StartPosition = 'Manual'
  $script:miniHandle.AutoScaleMode = 'None'
  $script:miniHandle.MinimumSize = New-Object Drawing.Size(1, 1)
  $script:miniHandle.MaximumSize = New-Object Drawing.Size(28, 26)
  $script:miniHandle.ClientSize = New-Object Drawing.Size(28, 26)
  $script:miniHandleButton = New-Object Windows.Forms.Button
  $script:miniHandleButton.Text = '≡'
  $script:miniHandleButton.Font = New-Object Drawing.Font('Segoe UI', 14)
  $script:miniHandleButton.AccessibleName = 'Usage menu: change plans and layout. Drag to move.'
  $script:miniHandleButton.Dock = 'Fill'
  $script:miniHandleButton.FlatStyle = 'Flat'
  $script:miniHandleButton.FlatAppearance.BorderSize = 0
  $script:miniHandleButton.Cursor = 'Hand'
  $script:miniHandle.Controls.Add($script:miniHandleButton)
  $script:miniHandle.ContextMenuStrip = $menu
  $script:miniHandleButton.ContextMenuStrip = $menu
  $tip.SetToolTip($script:miniHandleButton, 'Click: plans, layouts and appearance. Drag: move widget.')
  $script:miniHandleButton.Add_MouseDown({
    if ($_.Button -ne 'Left') { return }
    $script:handleStart = [Windows.Forms.Cursor]::Position
    $script:handleOrigin = $form.Location
    $script:handleMoved = $false
  })
  $script:miniHandleButton.Add_MouseMove({
    if (-not $script:handleStart -or $_.Button -ne 'Left') { return }
    $now = [Windows.Forms.Cursor]::Position
    $dx = $now.X - $script:handleStart.X; $dy = $now.Y - $script:handleStart.Y
    if ([Math]::Abs($dx) + [Math]::Abs($dy) -gt 4) { $script:handleMoved = $true }
    if ($script:handleMoved) { $form.Location = New-Object Drawing.Point(($script:handleOrigin.X + $dx), ($script:handleOrigin.Y + $dy)) }
  })
  $script:miniHandleButton.Add_MouseUp({
    if ($_.Button -ne 'Left') { return }
    $script:handleStart = $null
    if ($script:handleMoved) {
      Keep-OnScreen $form.Right
      try { "$($form.Left),$($form.Top)" | Set-Content $posFile } catch {}
    }
  })
  $script:miniHandleButton.Add_Click({
    if (-not $script:handleMoved) { $menu.Show($script:miniHandleButton, (New-Object Drawing.Point(0, 26))) }
  })
  $script:miniHandleButton.Add_KeyDown({ $script:handleMoved = $false })
  $form.Add_LocationChanged({ Sync-MiniHandle })
  $form.Add_VisibleChanged({ Sync-MiniHandle })
  $form.Add_FormClosed({ $script:miniHandle.Dispose() })
}
