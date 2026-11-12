import subprocess
import urllib.request
import json
import os
import sys

# Get GitHub token from git credentials
p = subprocess.Popen(['git', 'credential', 'fill'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
out, _ = p.communicate('protocol=https\nhost=github.com\n\n')
token = ''
for line in out.splitlines():
    if line.startswith('password='):
        token = line.split('=', 1)[1]

if not token:
    print('Error: Could not retrieve GitHub token.')
    sys.exit(1)

apk_path = r'C:\Users\hp g7\ZEGA-ALERT\mobile\build\app\outputs\flutter-apk\app-release.apk'
if not os.path.exists(apk_path):
    print(f'Error: APK not found at {apk_path}')
    sys.exit(1)

apk_size = os.path.getsize(apk_path)
print(f'Found APK at {apk_path} ({apk_size / (1024*1024):.1f} MB)')

# 1. Create or get release
release_payload = json.dumps({
    'tag_name': 'v1.0.0',
    'name': 'ZEGA-ALERT v1.0.0 (Android APK Release)',
    'body': 'Official release of the ZEGA-ALERT mobile application for Ethiopian Federal and Regional public safety.\n\n### How to Install on Android:\n1. Download `zega-alert.apk` below directly on your Android phone.\n2. Tap the downloaded file to install (allow "Install from unknown sources" if prompted).\n3. Open the app to test citizen reporting and emergency SOS.',
    'draft': False,
    'prerelease': False
}).encode('utf-8')

req = urllib.request.Request(
    'https://api.github.com/repos/ermi2023/zega-alert/releases',
    data=release_payload,
    headers={
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'zega-uploader',
        'Content-Type': 'application/json'
    }
)

try:
    with urllib.request.urlopen(req) as resp:
        release = json.loads(resp.read().decode())
except urllib.error.HTTPError as e:
    # If already created, fetch existing
    print(f'Release creation notice: {e}. Fetching release for tag v1.0.0...')
    fetch_req = urllib.request.Request(
        'https://api.github.com/repos/ermi2023/zega-alert/releases/tags/v1.0.0',
        headers={
            'Authorization': f'token {token}',
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'zega-uploader'
        }
    )
    with urllib.request.urlopen(fetch_req) as resp:
        release = json.loads(resp.read().decode())

release_id = release['id']
html_url = release['html_url']
print(f'Release is ready: ID {release_id} -> {html_url}')

# 2. Upload APK asset
upload_url = release['upload_url'].replace('{?name,label}', '?name=zega-alert.apk')
print(f'Uploading APK ({apk_size / (1024*1024):.1f} MB) to {upload_url} ...')

with open(apk_path, 'rb') as f:
    apk_data = f.read()

upload_req = urllib.request.Request(
    upload_url,
    data=apk_data,
    headers={
        'Authorization': f'token {token}',
        'Content-Type': 'application/vnd.android.package-archive',
        'Content-Length': str(apk_size),
        'User-Agent': 'zega-uploader'
    }
)

with urllib.request.urlopen(upload_req) as resp:
    asset = json.loads(resp.read().decode())
    download_url = asset['browser_download_url']
    print(f'SUCCESS! Asset uploaded.')
    print(f'Direct Mobile Download URL: {download_url}')
    print(f'Release Page: {html_url}')
