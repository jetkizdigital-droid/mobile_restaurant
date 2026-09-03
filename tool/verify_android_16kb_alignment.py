from pathlib import Path
import subprocess
import sys
import zipfile
import tempfile

AAB = Path('build/app/outputs/bundle/release/app-release.aab')

if not AAB.is_file():
    raise SystemExit(f'Release AAB not found: {AAB}')

with tempfile.TemporaryDirectory() as tmp_dir:
    root = Path(tmp_dir)
    with zipfile.ZipFile(AAB) as archive:
        native_entries = [
            name for name in archive.namelist()
            if name.startswith('base/lib/') and name.endswith('.so')
        ]
        if not native_entries:
            raise SystemExit('No native libraries found in release AAB')
        for name in native_entries:
            archive.extract(name, root)

    libraries = sorted(root.glob('base/lib/*/*.so'))
    bad = []
    for library in libraries:
        output = subprocess.check_output(
            ['readelf', '-lW', str(library)],
            text=True,
        )
        alignments = []
        for line in output.splitlines():
            fields = line.split()
            if fields and fields[0] == 'LOAD':
                alignments.append(int(fields[-1], 0))
        if not alignments or min(alignments) < 16384:
            bad.append((library, alignments))

    if bad:
        for library, alignments in bad:
            print(f'16KB alignment failure: {library}: {alignments}')
        raise SystemExit(1)

    print(f'16KB alignment verified for {len(libraries)} native libraries')
