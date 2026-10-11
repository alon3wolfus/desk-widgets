#!/usr/bin/env python3
"""Reads iCal feeds (e.g. Google Calendar "Secret address in iCal format") and prints the
upcoming events as JSON for the desk-widgets calendar card.

Feed links live in ~/.config/desk-widgets/calendars.txt, one per line ('#' starts a comment).
The links are secrets, so they are never printed and never stored anywhere else. The last
downloaded copy of each feed is cached so the widget still works offline.

Needs: python3 (3.9+) and python-dateutil (for recurring events).
"""
import hashlib
import json
import os
import re
import sys
import urllib.request
from datetime import date, datetime, time as dtime, timedelta, timezone

try:
    from zoneinfo import ZoneInfo
except ImportError:  # very old python
    ZoneInfo = None

try:
    from dateutil.rrule import rrulestr
except ImportError:
    rrulestr = None

HOME = os.path.expanduser("~")
CONFIG = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config"),
                      "desk-widgets", "calendars.txt")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.join(HOME, ".cache"),
                     "desk-widgets")

DAYS_BEFORE = 7
DAYS_AFTER = 45

class NotICal(Exception):
    """The link worked but returned a web page, not a calendar feed."""

def out(obj):
    sys.stdout.write(json.dumps(obj))
    sys.stdout.flush()

def read_urls():
    try:
        with open(CONFIG, encoding="utf-8") as f:
            lines = [l.strip() for l in f]
    except FileNotFoundError:
        return []
    urls = [l for l in lines if l and not l.startswith("#")]
    return [("https://" + u[len("webcal://"):]) if u.startswith("webcal://") else u for u in urls]

def fetch(url):
    """Returns ICS text. Falls back to the cached copy if the download fails."""
    os.makedirs(CACHE, mode=0o700, exist_ok=True)
    path = os.path.join(CACHE, hashlib.sha1(url.encode()).hexdigest()[:12] + ".ics")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "desk-widgets"})
        with urllib.request.urlopen(req, timeout=15) as r:
            data = r.read().decode("utf-8", "replace")
        if "BEGIN:VCALENDAR" not in data:
            raise NotICal()
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(data)
        return data
    except Exception:
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                return f.read()
        raise

def unfold(text):
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = []
    for line in text.split("\n"):
        if line[:1] in (" ", "\t") and lines:
            lines[-1] += line[1:]
        else:
            lines.append(line)
    return lines

def split_prop(line):
    inq = False
    for i, ch in enumerate(line):
        if ch == '"':
            inq = not inq
        elif ch == ":" and not inq:
            head, value = line[:i], line[i + 1:]
            break
    else:
        return None
    parts = head.split(";")
    params = {}
    for p in parts[1:]:
        k, _, v = p.partition("=")
        params[k.upper()] = v.strip('"')
    return parts[0].upper(), params, value

def parse_events(text):
    """Returns a list of events; each is {PROP: [(params, value), ...]}."""
    events, cur, nested = [], None, 0
    for line in unfold(text):
        if line == "BEGIN:VEVENT":
            cur, nested = {}, 0
        elif line == "END:VEVENT":
            if cur is not None:
                events.append(cur)
            cur = None
        elif cur is None:
            continue
        elif line.startswith("BEGIN:"):      # VALARM etc. - ignore their properties
            nested += 1
        elif line.startswith("END:"):
            nested = max(0, nested - 1)
        elif nested == 0:
            p = split_prop(line)
            if p:
                cur.setdefault(p[0], []).append((p[1], p[2]))
    return events

def unescape(s):
    return re.sub(r"\\([nN,;\\])", lambda m: " " if m.group(1) in "nN" else m.group(1), s)

def get_tz(name):
    if not name or ZoneInfo is None:
        return None
    try:
        return ZoneInfo(name)
    except Exception:
        return None

def parse_dt(params, value):
    """(datetime, is_date). Aware when the zone is known or UTC, naive ("floating" = local) otherwise."""
    value = value.strip()
    if params.get("VALUE") == "DATE" or len(value) == 8:
        return datetime.strptime(value[:8], "%Y%m%d"), True
    utc = value.endswith("Z")
    dt = datetime.strptime(value.rstrip("Z")[:15], "%Y%m%dT%H%M%S")
    if utc:
        return dt.replace(tzinfo=timezone.utc), False
    tz = get_tz(params.get("TZID"))
    return (dt.replace(tzinfo=tz) if tz else dt), False

def parse_duration(v):
    m = re.fullmatch(r"([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?", v.strip())
    if not m:
        return None
    sign = -1 if m.group(1) == "-" else 1
    w, d, h, mi, s = (int(x) if x else 0 for x in m.groups()[1:])
    return sign * timedelta(weeks=w, days=d, hours=h, minutes=mi, seconds=s)

def key_of(uid, dt):
    """Stable key to match EXDATE / RECURRENCE-ID against generated occurrences."""
    if dt.tzinfo:
        return (uid, dt.astimezone(timezone.utc).replace(tzinfo=None).isoformat(), "u")
    return (uid, dt.isoformat(), "n")

def first(ev, name):
    return ev[name][0] if name in ev else None

def make_rule(text, dtstart):
    try:
        return rrulestr(text, dtstart=dtstart)
    except ValueError:
        fixed = re.sub(r"UNTIL=(\d{8})(?!T|\d)", r"UNTIL=\1T235959Z", text)
        fixed = re.sub(r"UNTIL=(\d{8}T\d{6})(?!Z)", r"UNTIL=\1Z", fixed)
        try:
            return rrulestr(fixed, dtstart=dtstart)
        except ValueError:
            return None

def build(events_lists, win_start, win_end):
    """win_start/win_end are local dates (inclusive). Returns list of day-entries."""
    ws_aware = datetime.combine(win_start, dtime.min).astimezone()
    we_aware = datetime.combine(win_end + timedelta(days=1), dtime.min).astimezone()
    ws_naive = datetime.combine(win_start, dtime.min)
    we_naive = datetime.combine(win_end + timedelta(days=1), dtime.min)

    entries = []

    def emit(title, s, e, is_date):
        if is_date:
            d0 = s.date()
            d1 = e.date() if e and e > s else d0 + timedelta(days=1)   # exclusive
            d = d0
            while d < d1:
                if win_start <= d <= win_end:
                    entries.append({"date": d.isoformat(), "start": "", "end": "",
                                    "allDay": True, "title": title})
                d += timedelta(days=1)
            return
        s = s.astimezone() if s.tzinfo else s
        e = (e.astimezone() if e.tzinfo else e) if e else s
        last_day = (e - timedelta(seconds=1)).date() if e > s else s.date()
        d = s.date()
        while d <= last_day:
            if win_start <= d <= win_end:
                if d == s.date():
                    entries.append({"date": d.isoformat(), "start": s.strftime("%H:%M"),
                                    "end": e.strftime("%H:%M") if d == e.date() else "",
                                    "allDay": False, "title": title})
                else:
                    entries.append({"date": d.isoformat(), "start": "", "end": "",
                                    "allDay": True, "title": title})
            d += timedelta(days=1)

    for events in events_lists:
        # overrides: single edited occurrences of a recurring event
        overridden = set()
        for ev in events:
            rid = first(ev, "RECURRENCE-ID")
            uid = first(ev, "UID")
            if rid and uid:
                try:
                    overridden.add(key_of(uid[1], parse_dt(*rid)[0]))
                except ValueError:
                    pass

        for ev in events:
            status = first(ev, "STATUS")
            if status and status[1].strip().upper() == "CANCELLED":
                continue
            ds = first(ev, "DTSTART")
            if not ds:
                continue
            try:
                start, is_date = parse_dt(*ds)
            except ValueError:
                continue
            title = unescape(first(ev, "SUMMARY")[1]).strip() if "SUMMARY" in ev else ""
            title = title or "(No title)"

            # duration
            end = None
            de, dur = first(ev, "DTEND"), first(ev, "DURATION")
            if de:
                try:
                    end = parse_dt(*de)[0]
                except ValueError:
                    end = None
            elif dur and parse_duration(dur[1]) is not None:
                end = start + parse_duration(dur[1])
            length = (end - start) if end else timedelta(0)
            if is_date and not end:
                length = timedelta(days=1)

            rr = first(ev, "RRULE")
            if not rr:
                emit(title, start, end, is_date)
                continue

            if rrulestr is None:
                emit(title, start, end, is_date)     # at least show the first one
                continue

            uid = (first(ev, "UID") or ("", ""))[1]
            rule = make_rule(rr[1], start)
            if rule is None:
                continue

            excluded = set()
            for params, value in ev.get("EXDATE", []):
                for v in value.split(","):
                    try:
                        excluded.add(key_of(uid, parse_dt(params, v)[0]))
                    except ValueError:
                        pass

            lo, hi = (ws_aware, we_aware) if start.tzinfo else (ws_naive, we_naive)
            try:
                occurrences = rule.between(lo - length, hi, inc=True)
            except (TypeError, ValueError):
                continue
            for occ in occurrences:
                k = key_of(uid, occ)
                if k in excluded or k in overridden:
                    continue
                emit(title, occ, occ + length if (end or is_date) else None, is_date)

    entries.sort(key=lambda x: (x["date"], not x["allDay"], x["start"], x["title"].lower()))
    return entries

def main():
    urls = read_urls()
    if not urls:
        return out({"ok": False, "error": "no_config"})
    if rrulestr is None:
        return out({"ok": False, "error": "no_dateutil"})

    today = date.today()
    win_start = today - timedelta(days=DAYS_BEFORE)
    win_end = today + timedelta(days=DAYS_AFTER)

    parsed, failed, not_ical = [], 0, False
    for url in urls:
        try:
            parsed.append(parse_events(fetch(url)))
        except Exception as exc:                      # never print the message: it may hold the URL
            failed += 1
            not_ical = not_ical or isinstance(exc, NotICal)
            sys.stderr.write("desk-widgets: could not read a calendar (%s)\n" % type(exc).__name__)
    if not parsed:
        return out({"ok": False, "error": "not_ical" if not_ical else "fetch_failed"})

    out({"ok": True, "failed": failed, "events": build(parsed, win_start, win_end)})

if __name__ == "__main__":
    main()
