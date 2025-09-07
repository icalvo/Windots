#Requires AutoHotkey v2.0
#SingleInstance Force

; AutoHotkey v2.0 Script - VIM Cursor Mode Toggle
; Press Shift twice to toggle VIM cursor mode
; In VIM mode: H=Left, J=Down, K=Up, L=Right
tip(str := '', fontSize := '') {
    Static size := 36
    Global g
    Try g.Destroy
    If str != '' {
        g := Gui('+AlwaysOnTop -Caption -Border +ToolWindow +Disabled')
        g.SetFont 'bold s' size := fontSize = '' ? size : fontSize, 'Century Gothic'
        g.MarginX := g.MarginY := 5
        g.BackColor := 'Black'
        g.AddText 'cYellow', str
        g.Show 'NoActivate'
	WinSetTransparent 80, g
    }
}
; Variables
vimMode := false
doubleShiftDetected := false
lastShiftTime := 0
doubleClickInterval := 200  ; milliseconds for double-click detection
shiftPressed := false

; Monitor shift key press
$~Shift::
{
    global
    currentTime := A_TickCount
    
    ; Prevent keyboard repeat from being counted as multiple presses
    if (shiftPressed) {
        return
    }
    
    shiftPressed := true
    
    ; Check if this is a double-click
    if (currentTime - lastShiftTime <= doubleClickInterval) {
        doubleShiftDetected := true
        ToggleVimMode()
    } else {
        lastShiftTime := currentTime
    }
}

; Monitor shift key release
$~Shift Up::
{
    global
    shiftPressed := false
    
    ; Reset double-shift detection after the interval
    SetTimer(ResetDoubleShift, doubleClickInterval + 50)
}

ResetDoubleShift() {
    global
    doubleShiftDetected := false
}


; Function to enable VIM mode
EnableVimMode() {
    global
    if (!vimMode) {
        ToggleVimMode()
    }
}

; Function to toggle VIM mode
ToggleVimMode() {
    global
    vimMode := !vimMode
    
    if (vimMode) {
        ; Show tooltip indicating VIM mode is active
        tip("VIM Mode ON")
    } else {
        ; Show tooltip indicating VIM mode is off
        tip("VIM Mode OFF")
        SetTimer(() => tip(), -1000)  ; Hide tooltip after 1 seconds
    }
}
; MAPPINGS

; Enable VIM mode on F14 or any shortcut that brings a menu
F14::
~#x::
~#v::
~#!1::
~#!2::
~#!3::
~#!4::
~#!5::
~#!6::
~#!7::
~#!8::
~#!9::
~AppsKey::EnableVimMode()

; VIM mode key mappings (only active when vimMode is true)
#HotIf vimMode

$h::Send("{Left}")
$j::Send("{Down}")
$k::Send("{Up}")
$l::Send("{Right}")
$^k::Send("{PgUp}")
$^j::Send("{PgDown}")
$+h::Send("+{Left}")
$+j::Send("+{Down}")
$+k::Send("+{Up}")
$+l::Send("+{Right}")
$^h::Send("{Home}")
$^l::Send("{End}")
^+j::WheelDown
~Enter::ToggleVimMode()
~Esc::ToggleVimMode()
CapsLock::ToggleVimMode()
#HotIf  ; End conditional hotkeys

