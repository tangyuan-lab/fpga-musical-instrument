Option Explicit

Dim shell, fso, root, requirements, checkCode, installCode
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

root = fso.GetParentFolderName(WScript.ScriptFullName)
requirements = fso.BuildPath(root, "host_app\requirements.txt")
shell.CurrentDirectory = root

' Check pyserial silently; no terminal window is shown.
checkCode = shell.Run("py -c ""import serial""", 0, True)
If checkCode <> 0 Then
    installCode = shell.Run("py -m pip install -r """ & requirements & """", 0, True)
    If installCode <> 0 Then
        MsgBox "pyserial installation failed. Check Python 3.10+ and network access.", 16, "FPGA host startup failed"
        WScript.Quit 1
    End If
End If

' pyw.exe does not create a console window.
shell.Run "pyw -m host_app.gui", 0, False
