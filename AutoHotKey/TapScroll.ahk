#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreadsPerHotkey 1

; Tap-tempo scroll: F17 = up, F18 = down
; Velocity continuously chases the implied tap frequency. Slowing your
; taps (or pausing) lowers the target smoothly — you don't have to wait
; for the next tap for speed to fall.

; --- tuning ---------------------------------------------------------------
GAIN            := 8.0    ; notches/sec at 1 tap/sec  (v = GAIN * Hz)
MAX_HZ          := 8.0     ; clamp absolute frequency
INTERVAL_ALPHA  := 0.40    ; EMA of inter-tap interval on each tap (higher = snappier)
CHASE_ALPHA     := 0.18    ; per-tick velocity chase toward target (higher = snappier)
TICK_MS         := 16      ; scroll engine period (~60 Hz)
STOP_EPS        := 0.12    ; notches/sec — treat as stopped
MIN_INTERVAL_MS := 50      ; debounce / ignore absurdly fast repeats
MAX_INTERVAL_MS := 2500    ; beyond this, treat as a fresh phrase
; --------------------------------------------------------------------------

dir           := 0      ; -1 up, +1 down, 0 idle
velocity      := 0.0    ; signed notches per second (negative = up)
accum         := 0.0
lastTapTick   := 0
lastTapDir    := 0
emaInterval   := 0.0    ; ms — smoothed inter-tap interval; 0 = no tempo yet
active        := false

SetTimer(ScrollEngine, TICK_MS)

F17:: {
    TapScroll(-1)
    KeyWait("F17")
}
F18:: {
    TapScroll(1)
    KeyWait("F18")
}

TapScroll(newDir) {
    global
    now := A_TickCount
    interval := now - lastTapTick
    sameDir := (newDir = lastTapDir)

    if (newDir != dir) {
        ; Direction change: reset tempo, keep a soft seed until 2nd tap.
        emaInterval := 0.0
        velocity *= 0.25
    }

    if (sameDir && emaInterval > 0 && interval >= MIN_INTERVAL_MS && interval <= MAX_INTERVAL_MS) {
        emaInterval := emaInterval * (1 - INTERVAL_ALPHA) + interval * INTERVAL_ALPHA
    } else if (sameDir && emaInterval = 0 && interval >= MIN_INTERVAL_MS && interval <= MAX_INTERVAL_MS) {
        ; Second tap of a phrase — lock initial tempo.
        emaInterval := interval
    } else if (!sameDir || interval > MAX_INTERVAL_MS || emaInterval = 0) {
        ; First tap: no interval yet; engine will use elapsed time as implied rate.
        emaInterval := 0.0
    }

    dir         := newDir
    lastTapDir  := newDir
    lastTapTick := now
    active      := true
}

ScrollEngine() {
    global
    if !active {
        return
    }

    elapsed := A_TickCount - lastTapTick

    ; Implied interval is the slower of (EMA tempo, time since last tap).
    ; Waiting past the expected beat continuously lowers frequency.
    if (emaInterval > 0)
        implied := Max(emaInterval, elapsed)
    else
        implied := Max(elapsed, MIN_INTERVAL_MS)

    if (implied > MAX_INTERVAL_MS) {
        ; Phrase ended.
        velocity := 0
        accum := 0
        dir := 0
        emaInterval := 0
        active := false
        return
    }

    hz := Clamp(1000.0 / implied, 0.0, MAX_HZ)
    target := dir * GAIN * hz

    velocity += (target - velocity) * CHASE_ALPHA

    if (Abs(velocity) < STOP_EPS && elapsed > emaInterval && emaInterval > 0) {
        velocity := 0
        accum := 0
        return
    }

    accum += velocity * (TICK_MS / 1000.0)
    while (accum >= 1.0) {
        Send("{WheelDown}")
        accum -= 1.0
    }
    while (accum <= -1.0) {
        Send("{WheelUp}")
        accum += 1.0
    }
}

Clamp(v, lo, hi) {
    return Max(lo, Min(hi, v))
}
