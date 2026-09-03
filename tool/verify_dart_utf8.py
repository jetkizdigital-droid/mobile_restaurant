from pathlib import Path

for root in ('lib', 'test'):
    for source in Path(root).rglob('*.dart'):
        source.read_text(encoding='utf-8')

print('All Dart sources are UTF-8')
