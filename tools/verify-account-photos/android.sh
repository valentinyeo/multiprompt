#!/usr/bin/env bash
set -euo pipefail
: "${PHOTO_PROOF_CREDENTIAL:?Missing proof credential}"
: "${FIXTURE:?Missing fixture directory}"
: "${EVIDENCE:?Missing evidence directory}"
: "${COMPANION:?Missing companion checkout}"

mapfile -t credentials < <(python3 -c 'import json, os; c=json.loads(os.environ["PHOTO_PROOF_CREDENTIAL"]); print("\n".join(c[k] for k in ("account_id", "android_refresh_token", "android_device_id", "desktop_refresh_token", "desktop_device_id")))')
[[ ${#credentials[@]} == 5 ]]
for value in "${credentials[@]}"; do
    [[ -n "$value" && "$value" != *$'\n'* && "$value" != *$'\r'* ]]
    printf '::add-mask::%s\n' "$value"
done
private_key=$(base64 -w0 "$FIXTURE/user-key")
host_key=$(awk '{print $2}' "$FIXTURE/host-key.pub")
printf '::add-mask::%s\n' "$private_key"
printf '::add-mask::%s\n' "$host_key"
package=dev.multiprompt.companion.debug
unset PHOTO_PROOF_CREDENTIAL
adb install -r -g "$COMPANION/app/build/outputs/apk/debug/app-debug.apk"
adb install -r "$COMPANION/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
output=$(mktemp)
mkdir -p "$EVIDENCE"
cleanup() {
    adb pull "/sdcard/Android/data/$package/files/photo-proof/." "$EVIDENCE/" >/dev/null 2>&1 || true
    rm -f "$output"
}
trap cleanup EXIT
if ! adb shell am instrument -w -e class dev.multiprompt.companion.account.SeedAccountDeviceTest \
    -e refresh_token "${credentials[1]}" -e account_id "${credentials[0]}" -e device_id "${credentials[2]}" \
    -e ssh_private_key "$private_key" -e ssh_host_key "$host_key" -e ssh_port 2222 \
    "$package.test/androidx.test.runner.AndroidJUnitRunner" > "$output" 2>&1 || ! grep -q 'OK (1 test)' "$output"; then
    echo 'Device credential seed failed' >&2
    exit 1
fi
if ! adb shell am instrument -w -e class dev.multiprompt.companion.ui.AccountPhotoProof \
    "$package.test/androidx.test.runner.AndroidJUnitRunner" > "$output" 2>&1 || ! grep -q 'OK (1 test)' "$output"; then
    echo 'Android photo proof failed' >&2
    exit 1
fi
mkdir -p "$EVIDENCE"
adb pull "/sdcard/Android/data/$package/files/photo-proof/." "$EVIDENCE/" >/dev/null
test -s "$EVIDENCE/avatar.png"
test -s "$EVIDENCE/root.png"
test -s "$EVIDENCE/phone.json"
