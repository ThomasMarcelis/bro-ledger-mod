"""Build deterministic archives from owned sources and distribution docs."""
from hashlib import sha256
from pathlib import Path
import re
import sys
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parent.parent


def package(destination, sources):
    destination.parent.mkdir(exist_ok=True)
    with ZipFile(destination, 'w', ZIP_DEFLATED) as archive:
        for name, path in sorted(sources.items()):
            info = ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, path.read_bytes())
    with ZipFile(destination) as archive:
        assert archive.testzip() is None
    print(f'{destination.relative_to(ROOT)}: {len(sources)} files; ZIP integrity passed\n'
          f'SHA256 {sha256(destination.read_bytes()).hexdigest()}')


version = re.search(r'Version = "([0-9.]+)"', (ROOT / 'scripts/mods/bro_ledger/core.nut').read_text())[1]
paths = [*ROOT.glob('scripts/mods/bro_ledger/*.nut'),
         *(ROOT / name for name in ('scripts/!mods_preload/mod_bro_ledger.nut',
            'ui/mods/bro_ledger/ledger.js', 'ui/mods/bro_ledger/ledger.css',
            'LICENSE', 'README.md', 'THIRD_PARTY.md', 'docs/DEVELOPMENT.md', 'docs/STRATEGY.md'))]
package(ROOT / 'dist' / f'mod_bro_ledger-{version}.zip',
        {path.relative_to(ROOT).as_posix(): path for path in paths})

if '--audit' in sys.argv:
    package(ROOT / 'dist/mod_bro_ledger-audit-0.1.1.zip',
            {'scripts/!mods_preload/mod_bro_ledger_audit.nut': ROOT / 'tests/runtime_audit.nut'})
