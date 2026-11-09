#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

; pathclick: file paths in Windows Terminal behave like links.
;   hover              underline (with a short pulse)
;   Ctrl+Click         open in the default app
;   Ctrl+Shift+Click   "Open with" chooser
; The text under the cursor is read through UI Automation, so it works for
; any path printed in the terminal. Only absolute paths (C:\..., C:/..., ~\...)
; that exist on disk count as paths.

HOVER_MS := 60                                  ; how often the cursor is checked
FADE := [70, 150, 230, 255, 235, 210, 190]     ; underline opacity steps, 30 ms each; last one stays
LINE_PX := 0                                    ; underline thickness; 0 = from text height

DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")  ; physical pixels, same as UIA
CoordMode "Pixel", "Screen"
SetTimer Hover, HOVER_MS

#HotIf OverTerminal()
^LButton::  OnClick(false)
^+LButton:: OnClick(true)
#HotIf

OverTerminal() {
    try {
        MouseGetPos(, , &win)
        return WinGetProcessName(win) = "WindowsTerminal.exe"
    }
    return false
}

CursorPos(&x, &y) {
    pt := Buffer(8)
    DllCall("GetCursorPos", "ptr", pt)
    x := NumGet(pt, 0, "int"), y := NumGet(pt, 4, "int")
}

OnClick(chooseApp) {
    CursorPos(&x, &y)
    hit := ""
    try hit := PathAt(x, y)
    if !hit {
        SendEvent "{Blind}{Click}"  ; not a path: let the terminal have the click (URLs, selection)
        return
    }
    if chooseApp && !InStr(FileExist(hit.path), "D")
        Run 'rundll32.exe shell32.dll,OpenAs_RunDLL ' hit.path
    else
        Run '"' hit.path '"'
}

; ---------------------------------------------------------------- hover line

Hover() {
    static lastX := -1, lastY := -1, lastCheck := 0, shown := ""
    CursorPos(&x, &y)
    ; Same spot: look again only twice a second (the terminal may have scrolled).
    if x = lastX && y = lastY && A_TickCount - lastCheck < 500
        return
    lastX := x, lastY := y, lastCheck := A_TickCount
    hit := ""
    if OverTerminal()
        try hit := PathAt(x, y)
    key := ""
    if hit
        for r in hit.rects
            key .= r.x "," r.y "," r.w "," r.h ";"
    if key = shown
        return
    shown := key
    Underline(hit ? hit.rects : [])
}

Underline(rects) {
    static lines := []
    while lines.Length < rects.Length {
        g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000020")  ; click-through, never focused
        lines.Push(g)
    }
    for i, g in lines {
        if i > rects.Length {
            g.Hide()
            continue
        }
        r := rects[i]
        px := LINE_PX ? LINE_PX : Max(1, Round(r.h / 18))
        ; Light line on a dark terminal, dark line on a light one.
        bg := PixelGetColor(r.x, r.y)
        lum := ((bg >> 16) & 255) * 0.3 + ((bg >> 8) & 255) * 0.59 + (bg & 255) * 0.11
        g.BackColor := lum < 128 ? "E6E6E6" : "202020"
        WinSetTransparent(FADE[1], g)
        g.Show("NA x" r.x " y" (r.y + r.h - px) " w" r.w " h" px)
    }
    Pulse(lines, rects.Length)
}

Pulse(lines, count) {
    static step := 0, tick := 0
    step := 1
    if tick
        SetTimer tick, 0
    tick := Next
    SetTimer tick, 30
    Next() {
        step++
        if step > FADE.Length || !count {
            SetTimer tick, 0
            return
        }
        loop count
            try WinSetTransparent(FADE[step], lines[A_Index])
    }
}

; ------------------------------------------------------------ reading the text

; {path, rects} for an existing path under screen point (x, y), or "".
; rects: one {x, y, w, h} per terminal row the path occupies.
PathAt(x, y) {
    static uia := ComObject("{ff48dba4-60ef-4201-aa87-54103eef594e}", "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}")
    pt := (y << 32) | (x & 0xFFFFFFFF)
    ComCall(7, uia, "int64", pt, "ptr*", &el := 0)                 ; ElementFromPoint
    if !el
        return ""
    el := ComValue(13, el)
    ComCall(16, el, "int", 10014, "ptr*", &unk := 0)               ; GetCurrentPattern(Text)
    if !unk
        return ""
    unk := ComValue(13, unk)
    tp := ComObjQuery(unk, "{32eba289-3583-42c9-9c59-3b6d9a1e9b6a}")
    ComCall(3, tp, "int64", pt, "ptr*", &at := 0)                  ; RangeFromPoint
    if !at
        return ""
    at := ComValue(13, at)

    cur := RowAt(at, 0)
    head := CloneRange(cur.range)
    ComCall(15, head, "int", 1, "ptr", at, "int", 0)               ; end of head = cursor
    col := StrLen(RangeText(head))                                 ; chars before the cursor
    if col < cur.indent || col >= cur.indent + StrLen(cur.text)
        return ""
    prev := "", next := ""
    try prev := RowAt(at, -1)
    try next := RowAt(at, 1)

    ; A long path may be wrapped over rows: glued (hard wrap) or at a space (word wrap).
    for sep in ["", " "] {
        for rows in [[cur, next], [prev, cur, next]] {
            text := "", pos := 0, parts := []
            for row in rows {
                if !row || row.text = ""
                    continue
                if text != ""
                    text .= sep
                parts.Push({row: row, from: StrLen(text) + 1})
                if row = cur
                    pos := StrLen(text) + col - cur.indent + 1
                text .= row.text
            }
            if !(m := FindPath(text, pos))
                continue
            rects := []
            for part in parts {
                a := Max(m.from, part.from), b := Min(m.to, part.from + StrLen(part.row.text) - 1)
                if a <= b && (r := SpanRect(part.row, a - part.from, b - a + 1))
                    rects.Push(r)
            }
            return {path: m.path, rects: rects}
        }
    }
    return ""
}

CloneRange(r) {
    ComCall(3, r, "ptr*", &c := 0)
    return ComValue(13, c)
}

; The terminal row `offset` rows away from range r: {range, text, indent}.
RowAt(r, offset) {
    row := CloneRange(r)
    ComCall(6, row, "int", 3)                                      ; ExpandToEnclosingUnit(Line)
    if offset {
        ComCall(13, row, "int", 3, "int", offset, "int*", &moved := 0)
        if moved != offset
            throw Error("no such row")
        ComCall(6, row, "int", 3)
    }
    raw := RTrim(RangeText(row), " `r`n")
    text := LTrim(raw)
    return {range: row, text: text, indent: StrLen(raw) - StrLen(text)}
}

RangeText(r) {
    ComCall(12, r, "int", -1, "ptr*", &bstr := 0)
    if !bstr
        return ""
    s := StrGet(bstr, "UTF-16")
    DllCall("oleaut32\SysFreeString", "ptr", bstr)
    return s
}

; Screen rectangle of `len` characters starting `skip` characters into the row's text.
SpanRect(row, skip, len) {
    r := CloneRange(row.range)
    ComCall(14, r, "int", 0, "int", 0, "int", row.indent + skip, "int*", &moved := 0)  ; move start
    ComCall(15, r, "int", 1, "ptr", r, "int", 0)                                         ; collapse
    ComCall(14, r, "int", 1, "int", 0, "int", len, "int*", &moved)                      ; extend end
    ComCall(10, r, "ptr*", &psa := 0)                                                    ; GetBoundingRectangles
    if !psa
        return ""
    sa := ComValue(0x2005, psa)
    ComObjFlags(sa, 1)                                                                   ; free with the wrapper
    if sa.MaxIndex() < 3
        return ""
    rect := {x: Round(sa[0]), y: Round(sa[1]), w: Round(sa[2]), h: Round(sa[3])}
    return rect.w > 0 && rect.h > 0 ? rect : ""
}

; Longest existing path in `text` that covers character `pos` (1-based):
; {path, from, to}, or "". Longest-first also drops a trailing ":12", "." or ")".
FindPath(text, pos) {
    from := 1
    while pos && (a := RegExMatch(text, "i)(?<![a-z0-9])[a-z]:[\\/]|~[\\/]", , from)) && a <= pos {
        end := StrLen(text)
        while end >= pos {
            shown := RTrim(SubStr(text, a, end - a + 1), " .")
            cand := StrReplace(shown, "/", "\")
            if SubStr(cand, 1, 1) = "~"
                cand := EnvGet("USERPROFILE") SubStr(cand, 2)
            if StrLen(cand) > 3 && FileExist(cand)
                return {path: cand, from: a, to: a + StrLen(shown) - 1}
            end--
        }
        from := a + 1
    }
    return ""
}
