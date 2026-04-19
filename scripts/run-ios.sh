#!/bin/zsh

set -euo pipefail

regen=false
for arg in "$@"; do
  case "$arg" in
    --regen|-r)
      regen=true
      shift
      ;;
  esac
done

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
project_file="$repo_root/GreenCatalyst.xcodeproj"
spec_file="$repo_root/project.yml"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild is unavailable. Install full Xcode and run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

developer_dir="$(xcode-select -p 2>/dev/null || true)"
if [[ "$developer_dir" == "/Library/Developer/CommandLineTools" || -z "$developer_dir" ]]; then
  echo "error: full Xcode is not selected."
  echo "Install Xcode, then run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

# Verify Xcode version supports iOS 17 SDK
xcode_ver_str=$(xcodebuild -version | head -n1 | awk '{print $2}')
# Compare major.minor version numbers (requires 15.0+ for iOS 17 SDK typically)
required_major=15
xcode_major=${xcode_ver_str%%.*}
if [ "${xcode_major}" -lt ${required_major} ]; then
  echo "warning: Xcode ${xcode_ver_str} may be too old. Install Xcode 15+ to build for iOS 17/watchOS 10/macOS 14."
fi

should_generate=false
if [ ! -d "$project_file" ]; then
  should_generate=true
fi
if [ "$regen" = true ]; then
  should_generate=true
fi

if [ "$should_generate" = true ]; then
  if [ -f "$spec_file" ]; then
    if ! command -v xcodegen >/dev/null 2>&1; then
      echo "error: project.yml is present but xcodegen is not installed."
      echo "Install it with: brew install xcodegen"
      exit 1
    fi

    echo "Generating Xcode project from project.yml"
    (
      cd "$repo_root"
      xcodegen generate
    )
  else
    echo "note: No project.yml found. Skipping XcodeGen generation."
  fi
fi

echo "note: This project targets iOS 17+, watchOS 10+, macOS 14+. Ensure your deployment targets match these to avoid availability errors."
echo "Opening $project_file"
open "$project_file"
