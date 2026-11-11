"""Run actual local checks and persist machine-readable results. No SDK claims."""
import datetime
import json
from pathlib import Path
import platform
import shutil
import sqlite3
import subprocess
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))

class Tee:
    def __init__(self,*streams):self.streams=streams
    def write(self,text):
        for stream in self.streams:stream.write(text)
    def flush(self):
        for stream in self.streams:stream.flush()

def main():
    reports=ROOT/'reports';reports.mkdir(exist_ok=True)
    with (reports/'sqlite-tests.log').open('w') as log:
        suite=unittest.defaultTestLoader.discover(str(ROOT/'tests'))
        result=unittest.TextTestRunner(stream=Tee(sys.stdout,log),verbosity=2).run(suite)
    structure=subprocess.run([sys.executable,str(ROOT/'tools/check_structure.py')],capture_output=True,text=True,cwd=ROOT)
    print(structure.stdout,end='')
    (reports/'structure.log').write_text(structure.stdout+structure.stderr)
    status={'executed_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
      'python':platform.python_version(),'sqlite':sqlite3.sqlite_version,
      'sqlite_tests':{'run':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'skipped':len(result.skipped),'passed':result.wasSuccessful()},
      'structure_check':{'exit_code':structure.returncode,'description':'Dart delimiters, Android XML, JSON and Gradle wrapper; not Dart compilation'},
      'tools':{name:shutil.which(name) for name in ['flutter','dart','adb','emulator','java']},
      'kvm_present':Path('/dev/kvm').exists(),
      'flutter_analyze':'NOT RUN: Flutter SDK unavailable',
      'flutter_tests':'NOT RUN: Flutter SDK unavailable',
      'android_build':'NOT RUN: Flutter/Android SDK unavailable',
      'android_emulator':'NOT RUN: emulator/adb/SDK unavailable',
      'android_process_restart':'NOT RUN',
      'github_ci':'NOT RUN in this session'}
    (reports/'results.json').write_text(json.dumps(status,ensure_ascii=False,indent=2)+'\n')
    if structure.returncode:print(structure.stderr,file=sys.stderr)
    return 0 if result.wasSuccessful() and structure.returncode==0 else 1

if __name__=='__main__':raise SystemExit(main())
