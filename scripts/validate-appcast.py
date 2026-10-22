"""Validate release metadata before exposing an update to installed apps."""
import pathlib
import plistlib
import sys
import xml.etree.ElementTree as ET

feed, plist_path, archive = map(pathlib.Path, sys.argv[1:])
with plist_path.open('rb') as file:
    info = plistlib.load(file)
namespace = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
items = ET.parse(feed).findall('./channel/item')
assert items, 'The update feed has no releases'
latest = items[0]
assert latest.findtext(namespace + 'version') == info['CFBundleVersion'], 'Wrong build in update feed'
assert latest.findtext(namespace + 'shortVersionString') == info['CFBundleShortVersionString'], 'Wrong release version'
assert latest.findtext(namespace + 'minimumSystemVersion') == info['LSMinimumSystemVersion'], 'Wrong macOS requirement'
enclosure = latest.find('enclosure')
assert enclosure is not None, 'Missing download'
version = info['CFBundleShortVersionString']
assert enclosure.get('url') == f'https://github.com/torbensko/brainstorm/releases/download/v{version}/{archive.name}', 'Wrong download URL'
assert enclosure.get('length') == str(archive.stat().st_size), 'Wrong archive length'
assert enclosure.get(namespace + 'edSignature'), 'Missing update signature'
print(f'Validated update feed for Brainstorm {version} (build {info["CFBundleVersion"]}).')
