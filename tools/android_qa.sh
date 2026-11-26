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
dismiss_immersive
capture 01_lobby
tap_fraction 01_lobby 0.847 0.761
wait_log "ANDROID FRONTIER READY" 1
wait_log "ANDROID FRONTIER TICKS 120" 1
dismiss_immersive
capture 02_frontier
adb shell dumpsys meminfo "$PKG" > "$OUT/frontier_meminfo.txt"
adb shell pidof "$PKG" | grep -E '[0-9]+'
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
