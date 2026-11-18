#!/usr/bin/env bash
set -euo pipefail

if command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null; then
    ffmpeg -version
    ffprobe -version
    exit 0
fi

[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]]
: "${RUNNER_TEMP:?}" "${GITHUB_PATH:?}"

dist=ffmpeg-n8.1.3-35-gf1acb0a266-linux64-gpl-8.1
sha=4f88dca1e0e3079b0e8ba59a74a5bbdb8c89086a1508630616df76a56b0e0e55
tools="$RUNNER_TEMP/video-tools-8.1.3"
archive="$tools/ffmpeg.tar.xz"
mkdir -p "$tools"
curl --fail --location --retry 2 --output "$archive" "https://github.com/FFmpeg-Builds/FFmpeg-Builds/releases/download/autobuild-2026-11-17-12-40/$dist.tar.xz"
printf '%s  %s\n' "$sha" "$archive" | sha256sum --check -
tar -xJf "$archive" --strip-components=2 -C "$tools" "$dist/bin/ffmpeg" "$dist/bin/ffprobe"
"$tools/ffmpeg" -version
"$tools/ffprobe" -version
printf '%s\n' "$tools" >> "$GITHUB_PATH"
