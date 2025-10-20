#Requires AutoHotkey v2.0
#SingleInstance Force

#HotIf WinActive("ahk_exe Dorico5.exe")

$h::Send("{Left}")
$j::Send("{Down}")
$k::Send("{Up}")
$l::Send("{Right}")
; $^k::Send("{PgUp}")
; $^j::Send("{PgDown}")
; $+h::Send("+{Left}")
; $+j::Send("+{Down}")
; $+k::Send("+{Up}")
; $+l::Send("+{Right}")
; $^h::Send("{Home}")
; $^l::Send("{End}")
; ^+j::WheelDown

#HotIf  ; End conditional hotkeys

