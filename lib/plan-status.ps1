# Renews / Ends label for any plan, for widget.ps1 (dot-sourced).
# A plan you keep paying shows "Renews 10 Oct" in green; one set to cancel (billing.json "cancels") shows
# "Ends 5 Oct" in red. Used by the Claude / Codex month row (lib\month.ps1) and Spotify (lib\spotify.ps1).

# Deep green: the lighter (40,150,70) was hard to read on the light-blue panel. About 5.5:1 contrast on it.
$renewGreen = [Drawing.Color]::FromArgb(0, 115, 45)
# One semibold small font for every Renews / Ends label, so they all read the same size and stand out.
$fPlan = New-Object Drawing.Font('Segoe UI Semibold', 8.5)

# "Renews 10 Oct" / "Ends 5 Oct" for a pay date (DateTime).
function Plan-Label($cancels, $date) {
  $when = $date.ToString('d MMM', [Globalization.CultureInfo]::InvariantCulture)
  if ($cancels) { return "Ends $when" }
  return "Renews $when"
}

function Plan-Color($cancels) { if ($cancels) { $danger } else { $renewGreen } }
