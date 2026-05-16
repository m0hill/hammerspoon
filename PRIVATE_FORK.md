# Private Fork Notes

This fork adds an experimental native AppKit `hs.ui` module for personal use. It is intentionally unstable and not an upstream-quality public API yet.

## Building a local app

Use a non-sanitized Release build for daily use. Sanitizer/code-coverage builds work for debugging but use much more memory.

```sh
cd ~/projects/hammerspoon
xcodebuild \
  -workspace Hammerspoon.xcworkspace \
  -scheme Hammerspoon \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO \
  ENABLE_ADDRESS_SANITIZER=NO \
  ENABLE_UNDEFINED_BEHAVIOR_SANITIZER=NO \
  ENABLE_CODE_COVERAGE=NO \
  build
```

Find the built app:

```sh
APP="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -path '*/Build/Products/Release/Hammerspoon.app' \
  -type d -print | sort | tail -1)"

echo "$APP"
```

## Installing over `/Applications/Hammerspoon.app`

Back up the current app, quit Hammerspoon, copy the new build, then sign it:

```sh
APP="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -path '*/Build/Products/Release/Hammerspoon.app' \
  -type d -print | sort | tail -1)"

BACKUP="/Applications/Hammerspoon.app.backup-$(date +%Y%m%d-%H%M%S)"

osascript -e 'tell application "Hammerspoon" to quit' >/dev/null 2>&1 || true
sleep 1

ditto /Applications/Hammerspoon.app "$BACKUP"
rm -rf /Applications/Hammerspoon.app
ditto "$APP" /Applications/Hammerspoon.app

codesign --force --deep --sign - /Applications/Hammerspoon.app
open /Applications/Hammerspoon.app

echo "Backup: $BACKUP"
```

## Signing and Accessibility permissions

macOS Accessibility/TCC permissions are tied to the app identity and code signature. A locally built Hammerspoon can appear in Accessibility but still report disabled if the signature changed.

After installing a local build, always ad-hoc sign it:

```sh
codesign --force --deep --sign - /Applications/Hammerspoon.app
```

Verify the installed app:

```sh
codesign -dv --verbose=4 /Applications/Hammerspoon.app 2>&1 | sed -n '1,45p'
```

Expected useful lines:

```txt
Identifier=org.hammerspoon.Hammerspoon
Signature=adhoc
Sealed Resources version=2
```

If Hammerspoon says Accessibility is disabled even though it is listed in System Settings, reset and re-add it:

```sh
tccutil reset Accessibility org.hammerspoon.Hammerspoon
```

Then open:

```txt
System Settings → Privacy & Security → Accessibility
```

Remove any stale Hammerspoon entries, add `/Applications/Hammerspoon.app`, and toggle it on.

Verify from Terminal:

```sh
hs -c 'return hs.accessibilityState()'
```

Expected:

```txt
true
```

## IPC CLI

Install the `hs` command-line tool from the Hammerspoon console:

```lua
hs.ipc.cliInstall()
```

The dotfiles config also loads IPC on startup:

```lua
pcall(require, "hs.ipc")
```

Smoke checks:

```sh
hs -c 'return 1+1'
hs -c 'return require("hs.ui") ~= nil'
```

## Memory checks

Check Hammerspoon memory:

```sh
pid="$(pgrep -x Hammerspoon | head -1)"
ps -p "$pid" -o pid,rss,vsz,etime,comm
vmmap -summary "$pid" 2>/dev/null | egrep 'Physical footprint|Physical footprint \\(peak\\)|TOTAL' | head -20
```

A normal non-sanitized local Release build is around the same range as stock Hammerspoon on this machine:

```txt
RSS: roughly ~100 MB after startup
Physical footprint: tens of MB before lots of UI/app state accumulates
```

If RSS jumps to hundreds of MB, check for sanitizer linkage:

```sh
otool -L /Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon | egrep 'asan|ubsan|clang_rt|profile'
```

No output is expected for a daily-use build. If `libclang_rt.asan_osx_dynamic.dylib` appears, rebuild with:

```sh
ENABLE_ADDRESS_SANITIZER=NO \
ENABLE_UNDEFINED_BEHAVIOR_SANITIZER=NO \
ENABLE_CODE_COVERAGE=NO
```

Sanitizer/code-coverage builds can also create `default.profraw`; it is safe to delete.

## hs.ui launcher notes

The dotfiles launcher now uses `hs.ui` directly inside Hammerspoon:

- no Swift helper process
- no localhost HTTP bridge
- no `hs.chooser` fallback path

If `require("hs.ui")` fails, the installed Hammerspoon app is not this private fork build or `libui.dylib` was not copied into the app bundle.
