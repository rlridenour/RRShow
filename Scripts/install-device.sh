#!/bin/bash
#
# install-device.sh — build RRShow for the iPad so the audience display works.
#
# WHY THIS EXISTS
#
# iPadOS decides whether an app may have its own scene on an attached display by
# looking at the SDK the binary was linked against. Since the stable iPadOS release
# that followed the public beta, a binary linked against the iOS 27 SDK is not
# offered one: SpringBoard nominates the app to own the display and then has
# nothing to host —
#
#     [DisplayControlling] Updating current non interactive presentation
#                          from nothing to app<com.rlridenour.RRShow>
#     [DisplayControlling] [(null)] Stop hosting non interactive scene
#
# — and the projector stays a clone of the presenter's screen. Apps built against
# older SDKs are unaffected, which is why other presentation apps still work on the
# same iPad and the same cable.
#
# Proven by rewriting one load command on an already-compiled binary: identical
# code, `sdk 27.0` mirrors, `sdk 26.0` gets the audience scene. So that is what
# this does — build, rewrite LC_BUILD_VERSION, re-sign, install.
#
# This cannot be a build phase. Xcode signs as the last step of a build, and the
# rewrite has to happen after compilation and before signing, so pressing Run in
# Xcode will always produce a 27.0 binary that mirrors. Use this instead for any
# build you intend to present from.
#
# Revisit when Apple fixes it, or documents the opt-in they replaced it with.
#
# Usage:
#   Scripts/install-device.sh                  # build, patch, install to the only device
#   Scripts/install-device.sh --sdk 18.0       # claim a different SDK
#   Scripts/install-device.sh --device <UDID>  # when more than one is connected
#   Scripts/install-device.sh --no-install     # build and patch only
#
set -euo pipefail

SDK_VERSION="26.0"
DEVICE=""
INSTALL=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sdk) SDK_VERSION="$2"; shift 2 ;;
        --device) DEVICE="$2"; shift 2 ;;
        --no-install) INSTALL=0; shift ;;
        -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

cd "$(dirname "$0")/.."
BUILD_DIR="$(mktemp -d -t rrshow-device)"
trap 'rm -rf "$BUILD_DIR"' EXIT

echo "Building Release for iOS…"
xcodebuild -project RRShow.xcodeproj -scheme RRShow -configuration Release \
    -destination 'generic/platform=iOS' -allowProvisioningUpdates build \
    > "$BUILD_DIR/build.log" 2>&1 || { tail -40 "$BUILD_DIR/build.log"; exit 1; }

# Ask the build system where it put things rather than scraping the log, which
# changes shape between Xcode releases.
# `|| true` on every capture below: these pipelines end in a command that stops
# reading early, which sends SIGPIPE upstream, which `pipefail` would otherwise
# turn into a silent exit under `set -e`.
BUILT=$(xcodebuild -project RRShow.xcodeproj -scheme RRShow -configuration Release \
    -destination 'generic/platform=iOS' -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ BUILT_PRODUCTS_DIR = / {print $2; exit}' || true)
[[ -n "$BUILT" && -d "$BUILT/RRShow.app" ]] || {
    echo "Could not find the built app (BUILT_PRODUCTS_DIR=${BUILT:-unset})" >&2; exit 1
}

APP="$BUILD_DIR/RRShow.app"
cp -R "$BUILT/RRShow.app" "$APP"

# The signature about to be replaced is the source of both the identity and the
# entitlements: re-signing with anything else would change more than the SDK.
IDENTITY=$(codesign -dvv "$APP" 2>&1 | awk -F'=' '/^Authority=Apple Development/ {print $2; exit}' || true)
[[ -n "$IDENTITY" ]] || { echo "No Apple Development identity on the built app" >&2; exit 1; }
codesign -d --entitlements :- "$APP" > "$BUILD_DIR/entitlements.plist" 2>/dev/null

echo "Rewriting the linked SDK to $SDK_VERSION (was $(vtool -show-build "$APP/RRShow" | awk '/sdk/ {print $2}'))…"
MINOS=$(vtool -show-build "$APP/RRShow" | awk '/minos/ {print $2}' || true)
vtool -set-build-version ios "$MINOS" "$SDK_VERSION" -replace \
    -output "$APP/RRShow" "$APP/RRShow" 2>/dev/null

echo "Re-signing as ${IDENTITY}…"
codesign -f -s "$IDENTITY" --entitlements "$BUILD_DIR/entitlements.plist" \
    --generate-entitlement-der "$APP" 2>/dev/null
codesign -v "$APP" || { echo "Signature did not verify" >&2; exit 1; }

echo "  linked SDK now: $(vtool -show-build "$APP/RRShow" | awk '/sdk/ {print $2}')"

if [[ "$INSTALL" -eq 0 ]]; then
    KEEP="$HOME/Desktop/RRShow-device.app"
    rm -rf "$KEEP"; cp -R "$APP" "$KEEP"
    echo "Built and patched: $KEEP"
    exit 0
fi

if [[ -z "$DEVICE" ]]; then
    # Match the UDID by shape rather than by column: device names contain spaces,
    # so positional parsing picks words out of the name.
    UDID_RE='[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{40}'
    LISTING=$(xcrun devicectl list devices 2>/dev/null || true)
    CANDIDATES=$(printf '%s\n' "$LISTING" | grep physical | grep -oE "$UDID_RE" || true)
    COUNT=$(printf '%s\n' "$CANDIDATES" | grep -c . || true)
    if [[ "$COUNT" -ne 1 ]]; then
        echo "Need exactly one paired device, found $COUNT. Pass --device <UDID>:" >&2
        printf '%s\n' "$LISTING" | grep physical >&2 || true
        exit 1
    fi
    DEVICE="$CANDIDATES"
fi

echo "Installing to ${DEVICE}…"
xcrun devicectl device install app --device "$DEVICE" "$APP" | grep -E 'App installed|bundleID'

cat <<'DONE'

Done. Connect the display and open a deck; the presenter toolbar should show the
"On Air" chip. If it mirrors instead, the gate has moved: try a lower --sdk, and
check the log with

  sudo log collect --device-name "<iPad>" --last 10m --output /tmp/ipad.logarchive
  log show /tmp/ipad.logarchive --predicate 'category == "AudienceDisplay"'
DONE
