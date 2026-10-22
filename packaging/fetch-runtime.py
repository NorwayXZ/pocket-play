"""Fetch official command-line tools and Temurin JRE, verifying published checksums."""
import argparse, hashlib, json, pathlib, shutil, tarfile, tempfile, urllib.request, xml.etree.ElementTree as ET, zipfile
p=argparse.ArgumentParser(); p.add_argument('os',choices=['mac','windows']); p.add_argument('arch',choices=['aarch64','x64']); p.add_argument('output'); a=p.parse_args()
out=pathlib.Path(a.output); out.mkdir(parents=True,exist_ok=True)
def get(url):
    with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'PocketPlay-release'}),timeout=120) as r: return r.read()
def download(url,checksum,algorithm,target):
    data=get(url)
    if hashlib.new(algorithm,data).hexdigest().lower()!=checksum.strip().lower(): raise RuntimeError('Checksum mismatch: '+url)
    target.write_bytes(data)
repo=ET.fromstring(get('https://dl.google.com/android/repository/repository2-1.xml'))
package=next(n for n in repo.iter('remotePackage') if n.attrib['path']=='cmdline-tools;latest')
archive=next(n for n in package.findall('./archives/archive') if n.findtext('host-os')==('macosx' if a.os=='mac' else 'windows'))
complete=archive.find('complete'); checksum=complete.find('checksum')
java=json.loads(get(f'https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture={a.arch}&image_type=jre&os={a.os}'))[0]['binary']['package']
with tempfile.TemporaryDirectory() as d:
    temp=pathlib.Path(d)
    tools=temp/'tools.zip'; download('https://dl.google.com/android/repository/'+complete.findtext('url'),checksum.text,checksum.attrib.get('type','sha1'),tools)
    with zipfile.ZipFile(tools) as z: z.extractall(temp/'tools')
    shutil.copytree(temp/'tools'/'cmdline-tools',out/'cmdline-tools',dirs_exist_ok=True)
    j=temp/('java.zip' if a.os=='windows' else 'java.tar.gz'); download(java['link'],java['checksum'],'sha256',j)
    jdir=temp/'jre'; jdir.mkdir()
    if a.os=='windows':
        with zipfile.ZipFile(j) as z: z.extractall(jdir)
    else:
        with tarfile.open(j) as t: t.extractall(jdir,filter='data')
    shutil.copytree(next(jdir.iterdir()),out/'java',dirs_exist_ok=True,symlinks=True)
if a.os=='mac':
    for f in (out/'cmdline-tools'/'bin').iterdir(): f.chmod(0o755)
print('Verified runtime:',out)
