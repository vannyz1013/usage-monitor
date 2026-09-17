' Opens settings in the existing widget, or starts the widget with settings open.
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
CreateObject("WScript.Shell").Run "powershell -NoProfile -ExecutionPolicy Bypass -STA -File """ & dir & "\widget.ps1"" -Settings", 0, False
