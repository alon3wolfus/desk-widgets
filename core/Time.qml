pragma Singleton
import Quickshell

// shared minute-resolution clock
Singleton {
    readonly property date now: clock.date
    SystemClock { id: clock; precision: SystemClock.Minutes }
}
