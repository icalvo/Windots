#include VimMode.ahk

; Mappings that apply globally, both VIM mode and standard mode
CapsLock::Esc
#!j::
{
    Try {
        WinMinimize "A"
    }
}
#!k::WinMaximize "A"
#!y::WinClose "A"
#!r::Reload
