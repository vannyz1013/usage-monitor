' Launches widget.ps1 with no console window (used by the Startup shortcut).
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
CreateObject("WScript.Shell").Run "powershell -NoProfile -ExecutionPolicy Bypass -STA -File """ & dir & "\widget.ps1""", 0, False
