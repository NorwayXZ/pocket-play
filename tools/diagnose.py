#!/usr/bin/env python3
"""Local-only diagnostics. Never uploads logs, account data, screenshots, or tokens."""
import argparse, os, pathlib, subprocess, datetime
p=argparse.ArgumentParser();p.add_argument('--serial',required=True);p.add_argument('--output',required=True)
p.add_argument('--logcat',action='store_true',help='Opt in: raw logs may contain personal data; do not publish')
a=p.parse_args();out=pathlib.Path(a.output);out.mkdir(parents=True,exist_ok=True);out.chmod(0o700)
sdk=pathlib.Path(os.environ.get('ANDROID_SDK_ROOT',pathlib.Path.home()/'Library/Android/sdk'))
adb=str(sdk/'platform-tools'/('adb.exe' if os.name=='nt' else 'adb'))
commands={'avd':['emu','avd','name'], 'exit-info':['shell','dumpsys','activity','exit-info','com.taobao.idlefish'],
 'graphics':['shell','dumpsys','gfxinfo','com.taobao.idlefish'], 'storage':['shell','df','-h','/data'],
 'memory':['shell','dumpsys','meminfo','com.taobao.idlefish'], 'clock':['shell','date','-u']}
if a.logcat:commands['PRIVATE-logcat']=['logcat','-d','-t','6000']
for name,args in commands.items():
 try:
  r=subprocess.run([adb,'-s',a.serial]+args,capture_output=True,timeout=15)
  data=r.stdout+b'\n'+r.stderr
 except subprocess.TimeoutExpired:data=b'TIMEOUT after 15s\n'
 target=out/(name+'.txt');target.write_bytes(data);target.chmod(0o600)
 print(name, len(data),'bytes')
print('Local only:',out.resolve(), '\nReview/redact before sharing; never commit these files.')
