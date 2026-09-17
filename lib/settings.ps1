# One settings window, reachable from the Command Center and widget menu.
function Show-UsageSettings {
  if ($script:usageSettings -and -not $script:usageSettings.IsDisposed) {
    $script:usageSettings.Show(); $script:usageSettings.Activate(); return
  }
  $script:usageSettings = New-Object Windows.Forms.Form
  $panel = $script:usageSettings
  $panel.Text = 'AI usage settings'
  $panel.StartPosition = 'CenterScreen'
  $panel.FormBorderStyle = 'FixedDialog'
  $panel.MaximizeBox = $false; $panel.MinimizeBox = $false
  $panel.Font = $fText
  $panel.ClientSize = New-Object Drawing.Size(380, 340)
  $panel.BackColor = $bg; $panel.ForeColor = $ink
  $script:usageChoices = @{}
  $rows = @(
    @('Plans', @('both','claude','codex'), @('Claude and Codex','Claude only','Codex only'), $script:mode),
    @('Layout', @('mini','summary','dashboard','horizontal','pole','vertical','square'), @('Mini','Mini + dates','Dashboard','Bar','Pole','Tall panel','Square gauges'), $script:layout),
    @('Theme', @('auto','light','dark'), @('Follow Windows','Light','Dark'), $script:theme),
    @('Background', @('solid','soft'), @('Solid','Faded'), $script:seeThrough)
  )
  $y = 20
  foreach ($row in $rows) {
    $label = New-Object Windows.Forms.Label
    $label.Text = $row[0]; $label.SetBounds(20, ($y + 5), 96, 24)
    $panel.Controls.Add($label)
    $box = New-Object Windows.Forms.ComboBox
    $box.DropDownStyle = 'DropDownList'; $box.SetBounds(120, $y, 238, 28)
    $box.AccessibleName = $row[0]
    [void]$box.Items.AddRange([object[]]$row[2])
    $box.Tag = $row[1]; $box.SelectedIndex = [Math]::Max(0, [array]::IndexOf($row[1], $row[3]))
    $script:usageChoices[$row[0]] = $box
    $panel.Controls.Add($box)
    $y += 43
  }
  $note = New-Object Windows.Forms.Label
  $note.Text = 'Every shape is click-through. Tap the pet butterfly to show or hide usage. Drag the small ≡ button to move any shape.'
  $note.SetBounds(20, 199, 340, 56); $panel.Controls.Add($note)
  $apply = New-Object Windows.Forms.Button
  $apply.Text = 'Apply'; $apply.SetBounds(150, 280, 100, 32)
  $apply.Add_Click({
    $choices = $script:usageChoices
    Set-Mode $choices.Plans.Tag[$choices.Plans.SelectedIndex]
    Set-Layout $choices.Layout.Tag[$choices.Layout.SelectedIndex]
    Set-Theme $choices.Theme.Tag[$choices.Theme.SelectedIndex]
    Set-SeeThrough $choices.Background.Tag[$choices.Background.SelectedIndex]
    Show-Widget
    $script:usageSettings.Activate()
  })
  $panel.Controls.Add($apply); $panel.AcceptButton = $apply
  $close = New-Object Windows.Forms.Button
  $close.Text = 'Close'; $close.SetBounds(260, 280, 100, 32)
  $close.Add_Click({ $script:usageSettings.Close() })
  $panel.Controls.Add($close); $panel.CancelButton = $close
  $panel.Show(); $panel.Activate()
}
