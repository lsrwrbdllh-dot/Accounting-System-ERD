#!/usr/bin/env bash
set -euo pipefail

accounting_repo_root="${GITHUB_WORKSPACE:-$(pwd)}"
runtime_report_dir="$accounting_repo_root/reports/android-runtime"
runtime_package="${ACCOUNTING_ANDROID_PACKAGE:-com.accounting.system.preview}"
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
flutter build apk --release --target lib/main.dart --dart-define=APP_ENV=demo 2>&1 | tee "$runtime_report_dir/build.log"
runtime_apk="$accounting_repo_root/app/build/app/outputs/flutter-apk/app-release.apk"
runtime_apksigner="$(rg --files "$ANDROID_HOME/build-tools" -g apksigner | sort -V | tail -n 1)"
runtime_aapt="$(rg --files "$ANDROID_HOME/build-tools" -g aapt | sort -V | tail -n 1)"
"$runtime_apksigner" verify --verbose --print-certs "$runtime_apk" > "$runtime_report_dir/signature.txt"
"$runtime_aapt" dump badging "$runtime_apk" > "$runtime_report_dir/apk-info.txt"
rg -F "package: name='$runtime_package'" "$runtime_report_dir/apk-info.txt"
rg -F "'arm64-v8a'" "$runtime_report_dir/apk-info.txt"
if rg -q 'application-debuggable|application-testOnly' "$runtime_report_dir/apk-info.txt"; then
  echo 'The distributable must not be a debugger-only or test-only APK.' >&2
  exit 1
fi
mkdir -p "$accounting_repo_root/dist"
cp "$runtime_apk" "$accounting_repo_root/dist/Accounting-System-Android.apk"
cd "$accounting_repo_root/dist"
sha256sum Accounting-System-Android.apk > SHA256SUMS
cp SHA256SUMS "$runtime_report_dir/Accounting-System-Android.apk.sha256"
adb install -r "$runtime_apk" | tee "$runtime_report_dir/install.txt"
adb logcat -c
adb shell am start -W -n "$runtime_package/com.accounting.system.MainActivity" | tee "$runtime_report_dir/launch.txt"
sleep 8
adb shell am force-stop "$runtime_package"
adb shell am start -W -n "$runtime_package/com.accounting.system.MainActivity" | tee "$runtime_report_dir/relaunch.txt"
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
