"""Offline delimiter/XML/manifest checks; this is NOT a replacement for dart analyze."""
from pathlib import Path
import json
import xml.etree.ElementTree as ET
import zipfile

ROOT=Path(__file__).resolve().parents[1]

def check_dart(path):
    source=path.read_text();n=len(source)
    def fail(position,message):
        raise ValueError(f'{path.relative_to(ROOT)}:{source.count(chr(10),0,position)+1}: {message}')
    def quoted(i,raw=False):
        quote=source[i]
        marker=quote*3 if source.startswith(quote*3,i) else quote
        i+=len(marker)
        while i<n:
            if source.startswith(marker,i):return i+len(marker)
            if not raw and source[i]=='\\':i+=2;continue
            if not raw and source.startswith('${',i):i=code(i+2,True);continue
            i+=1
        fail(i,'unclosed string')
    def code(i=0,interpolation=False):
        stack=[]
        while i<n:
            c=source[i]
            if c=='r' and i+1<n and source[i+1] in "'\"":i=quoted(i+1,True);continue
            if c in "'\"":i=quoted(i);continue
            if source.startswith('//',i):
                newline=source.find('\n',i);i=n if newline<0 else newline+1;continue
            if source.startswith('/*',i):
                depth=1;i+=2
                while i<n and depth:
                    if source.startswith('/*',i):depth+=1;i+=2
                    elif source.startswith('*/',i):depth-=1;i+=2
                    else:i+=1
                if depth:fail(i,'unclosed comment')
                continue
            if interpolation and c=='}' and not stack:return i+1
            if c in '([{':stack.append((c,i))
            elif c in ')]}':
                if not stack or '([{'.index(stack[-1][0])!=')]}'.index(c):fail(i,f'unexpected {c}')
                stack.pop()
            i+=1
        if stack:fail(stack[-1][1],'unclosed delimiter')
        if interpolation:fail(i,'unclosed interpolation')
        return i
    code()

def main():
    dart=list((ROOT/'app').rglob('*.dart'))
    for path in dart:check_dart(path)
    xml=list((ROOT/'app/android').rglob('*.xml'))
    for path in xml:ET.parse(path)
    json.loads((ROOT/'app/assets/database.json').read_text())
    with zipfile.ZipFile(ROOT/'app/android/gradle/wrapper/gradle-wrapper.jar') as wrapper:
        assert 'org/gradle/wrapper/GradleWrapperMain.class' in wrapper.namelist()
    print(f'Offline structure checks: {len(dart)} Dart files, {len(xml)} XML files, JSON bundle and Gradle wrapper OK. Dart compiler not run.')

if __name__=='__main__':main()
