#!/usr/bin/env bash
set -euo pipefail

accounting_repo_root="${GITHUB_WORKSPACE:-$(pwd)}"
runtime_report_dir="$accounting_repo_root/reports/android-runtime"
runtime_package="${ACCOUNTING_ANDROID_PACKAGE:-com.accounting.system}"
mkdir -p "$runtime_report_dir"

capture_runtime_evidence() {
  runtime_exit_code=$?
  trap - EXIT
  adb logcat -d > "$runtime_report_dir/logcat.txt" 2>&1 || true
  adb logcat -d -b crash > "$runtime_report_dir/crashes.txt" 2>&1 || true
  adb exec-out screencap -p > "$runtime_report_dir/screen.png" 2>/dev/null || true
  exit "$runtime_exit_code"
}
trap capture_runtime_evidence EXIT

adb wait-for-device
adb shell getprop ro.build.version.release > "$runtime_report_dir/android-version.txt"
adb shell getprop ro.build.version.sdk >> "$runtime_report_dir/android-version.txt"
adb logcat -c
cd "$accounting_repo_root/app"
flutter pub get
timeout 480s flutter test integration_test/persistence_test.dart -d emulator-5554 --dart-define=APP_ENV=demo --reporter expanded 2>&1 | tee "$runtime_report_dir/integration.log"
flutter build apk --debug --dart-define=APP_ENV=demo 2>&1 | tee "$runtime_report_dir/build.log"
sha256sum build/app/outputs/flutter-apk/app-debug.apk > "$runtime_report_dir/app-debug.apk.sha256"
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb logcat -c
adb shell am start -W -n "$runtime_package/com.accounting.system.MainActivity" | tee "$runtime_report_dir/launch.txt"
sleep 8
adb shell pidof "$runtime_package" > "$runtime_report_dir/process.txt"
adb logcat -d > "$runtime_report_dir/launch-logcat.txt"
adb logcat -d -b crash > "$runtime_report_dir/launch-crashes.txt"
if rg -q 'ACCOUNTING_STARTUP_FAILURE' "$runtime_report_dir/launch-logcat.txt"; then
  echo 'Application reported a startup failure.' >&2
  exit 1
fi
if rg -Fq "Process: $runtime_package" "$runtime_report_dir/launch-crashes.txt"; then
  echo 'Application crashed after launch.' >&2
  exit 1
fi
