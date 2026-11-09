#Requires AutoHotkey v2.0
; Self-check. Run: AutoHotkey64.exe /ErrorStdOut tests\pathclick.test.ahk | more
; 1) FindPath on plain strings.
; 2) Live: opens a terminal window that prints paths, then reads them back
;    through UI Automation the same way a hover or click does.
#Include ..\scripts\pathclick.ahk
SetTimer Hover, 0

Out(s) => FileAppend(s "`n", "*")
fails := 0
Check(name, got, want) {
    global fails
    if got != want
        fails++, Out("FAIL " name ": got [" got "] want [" want "]")
    else
        Out("ok   " name)
}
P(text, pos) => (m := FindPath(text, pos)) ? m.path : ""

ini := "C:\Windows\win.ini", cf := "C:\Program Files\Common Files"
Check("plain", P("see " ini " now", 10), ini)
Check("line suffix", P(ini ":12:3", 5), ini)
Check("sentence dot", P("кадр: " ini ".", 12), ini)
Check("spaces", P("open " cf " please", 25), cf)
Check("slashes", P("C:/Windows/win.ini", 4), ini)
Check("click outside", P("word " ini, 2), "")
Check("missing", P("C:\nope\missing.txt", 12), "")
Check("second of two", P("C:\nope\x and " ini, 20), ini)
Check("tilde", P("~\Documents", 4), EnvGet("USERPROFILE") "\Documents")
m := FindPath("see " ini ". ok", 10)
Check("span", m.from "-" m.to, "5-22")

; Live read from a real terminal window. The long path wraps over two rows.
long := A_Temp "\pathclick-test\" Format("{:0120}", 7) "\file.txt"
DirCreate RegExReplace(long, "\\[^\\]+$")
FileAppend "", long
title := "pathclick-test-" A_TickCount
Run 'wt.exe -w new --size 100,20 --title ' title ' cmd /k "echo ' ini ' & echo   see ' cf ' here & echo ' long '"'
if !WinWait(title, , 10) {
    Out("FAIL live: terminal window did not appear")
    ExitApp 1
}
Sleep 2500
WinGetPos(&wx, &wy, &ww, &wh, title)
found := Map(), errors := Map()
y := wy + 40
while y < wy + Min(wh, 400) {
    x := wx + 30
    while x < wx + Min(ww, 900) {
        try {
            if hit := PathAt(x, y)
                found[hit.path] := hit.rects
        } catch as e {
            if !errors.Has(e.Message)
                errors[e.Message] := true, Out("error " e.Message " @ line " e.Line)
        }
        x += 45
    }
    y += 8
}
WinClose title
DirDelete A_Temp "\pathclick-test", true
Check("live plain", found.Has(ini), true)
Check("live spaces", found.Has(cf), true)
Check("live wrapped", found.Has(long), true)
if found.Has(ini) {
    r := found[ini]
    Check("one underline", r.Length, 1)
    Check("underline inside window", r[1].x >= wx && r[1].x + r[1].w <= wx + ww && r[1].w > 50 && r[1].h > 5, true)
}
if found.Has(cf) && found.Has(ini)
    Check("indented underline starts later", found[cf][1].x > found[ini][1].x, true)
if found.Has(long)
    Check("wrapped has two underlines", found[long].Length, 2)
Out(fails ? fails " FAILED" : "ALL OK")
ExitApp fails ? 1 : 0
