#!/usr/bin/env python3
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
pubspec = (root / 'pubspec.yaml').read_text(encoding='utf-8')
match = re.search(r'^version:\s*([^+\s]+)\+(\d+)\s*$', pubspec, re.M)
if not match:
    raise SystemExit('pubspec version must use versionName+buildNumber')
version_name, build_number = match.groups()

build_info = (root / 'lib/core/config/app_build_info.dart').read_text(encoding='utf-8')
if f"versionName = '{version_name}'" not in build_info:
    raise SystemExit('AppBuildInfo.versionName is out of sync with pubspec.yaml')
if f"buildNumber = '{build_number}'" not in build_info:
    raise SystemExit('AppBuildInfo.buildNumber is out of sync with pubspec.yaml')

gradle = (root / 'android/app/build.gradle.kts').read_text(encoding='utf-8')
app_id_match = re.search(r'applicationId\s*=\s*"([^"]+)"', gradle)
if not app_id_match:
    raise SystemExit('Android applicationId not found')
application_id = app_id_match.group(1)

google = json.loads((root / 'android/app/google-services.json').read_text(encoding='utf-8'))
if google.get('project_info', {}).get('project_id') != 'jetkiz-mobile':
    raise SystemExit('google-services.json must use Firebase project jetkiz-mobile')
packages = {
    item.get('client_info', {}).get('android_client_info', {}).get('package_name')
    for item in google.get('client', [])
}
if application_id not in packages:
    raise SystemExit(
        f'Firebase Android package mismatch: applicationId={application_id}, clients={sorted(packages)}'
    )

manifest = (root / 'android/app/src/main/AndroidManifest.xml').read_text(encoding='utf-8')
if 'android.permission.POST_NOTIFICATIONS' not in manifest:
    raise SystemExit('POST_NOTIFICATIONS permission is required')
if 'restaurant_new_orders_v2' not in manifest:
    raise SystemExit('Restaurant new-order default channel is missing')

push = (root / 'lib/core/push/restaurant_push_notification_service.dart').read_text(encoding='utf-8')
for required in (
    "'app': 'restaurant'",
    'jetkiz_default_channel',
    'restaurant_new_orders_v2',
    'ADMIN_CAMPAIGN',
    'AppBuildInfo.fullVersion',
):
    if required not in push:
        raise SystemExit(f'Push release contract missing: {required}')
if "'appVersion': '1.0.0'" in push:
    raise SystemExit('Push appVersion must not be hardcoded')

cms = (root / 'lib/features/cms/data/restaurant_app_cms_api.dart').read_text(encoding='utf-8')
if "'appVersion': '1.0.0'" in cms or 'appVersion=1.0.0' in cms:
    raise SystemExit('CMS appVersion must not be hardcoded')
if 'AppBuildInfo.versionName' not in cms:
    raise SystemExit('CMS must use AppBuildInfo.versionName')

print(f'Restaurant release contract PASS: {application_id} {version_name}+{build_number}')
