#!/usr/bin/env bash
set -euo pipefail
PKG=com.lastimpact.prototype
OUT=/tmp/lastimpact_android_qa
mkdir -p "$OUT"
trap 'adb logcat -d -v threadtime > "$OUT/logcat.txt" || true; adb shell dumpsys meminfo "$PKG" > "$OUT/meminfo.txt" || true; adb exec-out screencap -p > "$OUT/99_final_screen.png" || true' EXIT

wait_log() {
  local marker="$1" required="$2"
  for ((i=0;i<90;i++)); do
    local count
    count="$(adb logcat -d -v brief -s godot:I | grep -F -c "$marker" || true)"
    if (( count >= required )); then return 0; fi
    sleep 2
  done
  echo "ANDROID QA FAILED: missing $marker" >&2
  return 1
}
capture() {
  adb exec-out screencap -p > "$OUT/$1.png"
  test -s "$OUT/$1.png"
}
tap_fraction() {
  local x y
  read -r x y < <(python3 - "$OUT/$1.png" "$2" "$3" <<'PY'
import struct,sys
with open(sys.argv[1],"rb") as f:
    header=f.read(24)
assert header[:8]==b"\x89PNG\r\n\x1a\n"
w,h=struct.unpack(">II",header[16:24])
assert w>h, (w,h)
print(round(w*float(sys.argv[2])),round(h*float(sys.argv[3])))
PY
)
  adb shell input tap "$x" "$y"
}
swipe_fraction() {
  local x1 y1 x2 y2
  read -r x1 y1 x2 y2 < <(python3 - "$OUT/$1.png" "$2" "$3" "$4" "$5" <<'PY'
import struct,sys
with open(sys.argv[1],"rb") as f:
    header=f.read(24)
w,h=struct.unpack(">II",header[16:24])
assert w>h
print(*(round(float(v)*(w if i%2==0 else h)) for i,v in enumerate(sys.argv[2:])))
PY
)
  adb shell input swipe "$x1" "$y1" "$x2" "$y2" "$6"
}
dismiss_launcher_anr() {
  adb shell uiautomator dump /sdcard/lastimpact_window.xml >/dev/null 2>&1 || return 0
  adb pull /sdcard/lastimpact_window.xml "$OUT/launcher_window.xml" >/dev/null 2>&1 || return 0
  if grep -Fq "Pixel Launcher isn't responding" "$OUT/launcher_window.xml"; then
    echo "ANDROID QA: detected unrelated Pixel Launcher ANR; closing launcher only"
    adb shell am force-stop com.google.android.apps.nexuslauncher
    sleep 3
    adb shell am start -n "$PKG/com.godot.game.GodotAppLauncher"
    sleep 4
  fi
}
dismiss_immersive() {
  adb shell uiautomator dump /sdcard/lastimpact_window.xml >/dev/null 2>&1 || return 0
  adb pull /sdcard/lastimpact_window.xml "$OUT/window.xml" >/dev/null 2>&1 || return 0
  local xy
  xy="$(python3 - "$OUT/window.xml" <<'PY'
import sys, re, xml.etree.ElementTree as ET
try:
    for n in ET.parse(sys.argv[1]).iter("node"):
        if n.get("package")=="com.android.systemui" and (n.get("text")=="Got it" or "immersive_mode_cling" in n.get("resource-id","")):
            a=list(map(int,re.findall(r"\d+",n.get("bounds",""))))
            if len(a)==4:
                print((a[0]+a[2])//2,(a[1]+a[3])//2)
                break
except ET.ParseError:
    pass
PY
)"
  if [[ -n "$xy" ]]; then
    read -r x y <<< "$xy"
    adb shell input tap "$x" "$y"
    sleep 2
  fi
}
adb shell input keyevent 82
# Confirm immersive tutorial on this disposable test device only.
adb shell settings put secure immersive_mode_confirmations confirmed
adb install --no-incremental -r /tmp/lastimpact_android_qa.apk
adb shell am force-stop "$PKG"
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
wait_log "LAST IMPACT R073 LOBBY READY" 1
sleep 5
dismiss_launcher_anr
dismiss_immersive
capture 01_lobby
tap_fraction 01_lobby 0.847 0.761
wait_log "ANDROID FRONTIER READY" 1
wait_log "ANDROID RAZE CLIPS READY true" 1
wait_log "ANDROID FRONTIER TICKS 120" 1
wait_log "ANDROID FRONTIER PERF" 1
wait_log "LAST IMPACT TELEMETRY " 1
adb logcat -d -v brief -s godot:I | grep -F "LAST IMPACT TELEMETRY " | tee "$OUT/telemetry.txt"
python3 - "$OUT/telemetry.txt" <<'PY'
import json,sys
line=open(sys.argv[1]).read().splitlines()[-1]
d=json.loads(line.split("LAST IMPACT TELEMETRY ",1)[1])
assert d["frames"]>0 and d["duration_ms"]>=10000 and d["mean_fps"]>0
assert 0<d["median_ms"]<=d["p95_ms"]<=d["p99_ms"]
assert d["one_percent_low_fps"]>0 and d["build"]=="0.7.6.5"
assert isinstance(d["gait_calibrated"],bool)
assert d["locomotion_clips"] is True
assert d["static_blocks"]==49 and d["static_groups"]==19
print("QA-03 TELEMETRY VALIDATED")
PY
adb logcat -d -v brief -s godot:I | grep -F "ANDROID FRONTIER PERF" | tee "$OUT/performance.txt"
dismiss_immersive
capture 02_frontier
adb shell dumpsys meminfo "$PKG" > "$OUT/frontier_meminfo.txt"
adb shell pidof "$PKG" | grep -E '[0-9]+'
# OS-injected single-finger events; separate engine fixtures cover simultaneous contacts.
tap_fraction 02_frontier 0.77 0.10
sleep 2
swipe_fraction 02_frontier 0.91 0.59 0.91 0.59 1600
wait_log "LAST IMPACT CONTROL SHOT" 1
tap_fraction 02_frontier 0.68 0.82
wait_log "LAST IMPACT CONTROL RELOAD_COMPLETE" 1
tap_fraction 02_frontier 0.79 0.48
wait_log "LAST IMPACT CONTROL AIM_ON" 1
tap_fraction 02_frontier 0.79 0.48
wait_log "LAST IMPACT CONTROL AIM_OFF" 1
tap_fraction 02_frontier 0.92 0.80
wait_log "LAST IMPACT CONTROL JUMP" 1
tap_fraction 02_frontier 0.77 0.10
sleep 2
swipe_fraction 02_frontier 0.14 0.80 0.14 0.66 2000
wait_log "LAST IMPACT CONTROL MOVE_RELEASE" 1
wait_log "LAST IMPACT CONTROL CLIP_ACTIVE" 1
swipe_fraction 02_frontier 0.52 0.45 0.62 0.45 1000
wait_log "LAST IMPACT CONTROL LOOK_RELEASE" 1
tap_fraction 02_frontier 0.66 0.49
wait_log "LAST IMPACT CONTROL SHOULDER" 1
capture 04_controls
adb logcat -d -v brief -s godot:I | grep -F "LAST IMPACT CONTROL " | tee "$OUT/controls.txt"
echo "QA-04 ADB SINGLE TOUCH VALIDATED"
tap_fraction 02_frontier 0.65 0.10
wait_log "LAST IMPACT R073 LOBBY READY" 2
sleep 2
capture 03_return_lobby
adb logcat -d -v threadtime > "$OUT/logcat.txt"
if grep -E 'SCRIPT ERROR|Parse Error|FATAL EXCEPTION|Fatal signal|GL_MAX_FRAGMENT_UNIFORM_VECTORS|Program linking failed|shader failed to compile' "$OUT/logcat.txt"; then
  echo "ANDROID QA FAILED: runtime error in emulator log" >&2
  exit 1
fi
echo "LAST IMPACT ANDROID EMULATOR PASS"
