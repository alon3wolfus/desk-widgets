# desk-widgets

Desktop widgets for [Quickshell](https://quickshell.org) on Wayland. Catppuccin Frappé, translucent cards that sit on the wallpaper layer below every window, so they never get in the way. Drop a file in a folder to turn a widget on, move it out to turn it off.

![desktop](screenshots/1.png)

## Widgets

| | | |
|:--:|:--:|:--:|
| ![](screenshots/2.png)<br>**Photo frame** | ![](screenshots/3.png)<br>**Calendar** | ![](screenshots/4.png)<br>**Weather** |
| ![](screenshots/5.png)<br>**Pomodoro** | ![](screenshots/6.png)<br>**Clock** | ![](screenshots/7.png)<br>**Audio visualiser** |
| ![](screenshots/8.png)<br>**Now playing** | ![](screenshots/9.png)<br>**System stats** | ![](screenshots/10.png)<br>**Battery** |
| ![](screenshots/11.png)<br>**Network speed** | ![](screenshots/12.png)<br>**To-do** | ![](screenshots/13.png)<br>**Countdown** |
| ![](screenshots/14.png)<br>**Progress** | | |

| Widget | File | What it does | Needs |
|---|---|---|---|
| Photo frame | `10-photo.qml` | Cycles through `~/Pictures/desk-widgets`, click to skip | `shuf` |
| Calendar | `20-calendar.qml` | Week strip and agenda from iCal feeds (Google Calendar works) | `python`, `python-dateutil` |
| Weather | `30-weather.qml` | Current weather and 3 day forecast from wttr.in, no API key | `curl` |
| Pomodoro | `40-pomodoro.qml` | Work / break timer with desktop notifications | `libnotify` |
| Clock | `clock.qml` | Big clock with seconds and date | |
| Audio visualiser | `audio-vis.qml` | Bars that react to whatever is playing | `cava` |
| Now playing | `now-playing.qml` | Track, progress and controls for any MPRIS player | |
| System stats | `system-stats.qml` | CPU, RAM, disk and temperature | |
| Battery | `battery.qml` | Charge ring, plugged-in state, time left | `upower` |
| Network speed | `net-speed.qml` | Live down / up graph | |
| To-do | `todo.qml` | Click to tick, hover for × to delete, saved between restarts | |
| Countdown | `countdown.qml` | Days left until dates you list | |
| Progress | `progress.qml` | How far through the day, week, month and year | |

## Install

On Arch:

```sh
sudo pacman -S quickshell git
sudo pacman -S cava python-dateutil upower libnotify curl   # only what the widgets you use need
git clone https://github.com/YOUR_USER/desk-widgets ~/.config/quickshell/desk-widgets
qs -c desk-widgets
```

If `quickshell` isn't in your repos, use `quickshell-git` from the AUR.

Start it with your session, for example in Hyprland: `exec-once = qs -c desk-widgets`.

Fonts are Rubik and CaskaydiaCove NF. Change them in `core/Theme.qml`.

## Turning widgets on and off

Everything in `active/` is shown, everything in `inactive/` is not. Move a `.qml` file from one folder to the other and the desktop updates live. Delete the ones you'll never use.

Widgets stack in file name order, so prefix with numbers to control the order. Files without a prefix go to the bottom.

Each widget keeps its settings as plain properties at the top of its file (city for weather, work length for pomodoro, bar count for the visualiser, and so on).

## Placing widgets

By default everything in `active/` stacks in the top right. To put a widget somewhere else, put it in a subfolder of `active/` named after the spot. Make the folder if it isn't there.

```
active/
  10-photo.qml              top-right, the default
  top-left/clock.qml
  bottom-center/audio-vis.qml
  center-left/todo.qml
```

Zones: `top-left` `top-center` `top-right` `center-left` `center` `center-right` `bottom-left` `bottom-center` `bottom-right`.

Widgets in one zone stack top to bottom. When a stack reaches the bottom of the screen it wraps into a new column beside it. If your bar covers part of the screen, raise `margin` in `shell.qml`.

`defaultZone`, `cardWidth`, `gap` and `margin` are at the top of `shell.qml`.

## Setup notes

**Calendar.** Put your iCal links in `~/.config/desk-widgets/calendars.txt`, one per line. For Google Calendar use *Settings → your calendar → Secret address in iCal format*. Treat the link like a password. It is read only from that file and never printed, logged or stored in this repo.

**To-do.** The input box needs keyboard focus. Click it and type. If your compositor doesn't give focus to bottom layer surfaces, typing won't work.

**Audio visualiser.** It starts its own `cava` and reads your default audio output, so there is nothing to configure.

## Writing your own widget

Add a file to `active/` and import the shared bits:

```qml
import QtQuick
import "../core"

Card {
    height: 80
    Txt { anchors.centerIn: parent; text: "hello" }
}
```

`core/` has `Card`, `Txt`, `Pill`, `Toggle`, `Bar`, `IconButton`, `RoundImage`, plus the `Theme` and `Time` singletons. Colours come from `Theme`, so a new widget matches the rest.

## Layout of the repo

```
shell.qml       starts one stack per screen position
core/           theme, zones and shared components
active/         widgets that are shown
inactive/       widgets that are available
scripts/        helpers the widgets call (gcal.py, stats.sh, net.sh)
screenshots/    images used in this readme
```

## License

MIT
