"""Run behavioral checks; print full Squirrel output only on failure."""
from hashlib import sha256
from pathlib import Path
import re
import shutil
import subprocess
import sys
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parent.parent
sq = ROOT / '.tools/sq'
if shutil.which(str(sq)) is None:
    sys.exit('Build the Squirrel runner at .tools/sq; see docs/DEVELOPMENT.md.')
if shutil.which('node') is None:
    sys.exit('Install Node.js to run UI checks; see docs/DEVELOPMENT.md.')
msu_zip = ROOT / '.tools/mod_msu-1.9.0.zip'
if not msu_zip.is_file() or sha256(msu_zip.read_bytes()).hexdigest() != '617af64bd4b354408b91f8b8618f94f664491edcd2cf4649b8ad52673c81b37b':
    sys.exit('Place the pinned mod_msu-1.9.0.zip in .tools/; see docs/DEVELOPMENT.md.')

with ZipFile(msu_zip) as archive:
    for name in ['classes/ordered_map', 'systems/system', 'systems/system_mod_addon', 'systems/mod',
                 *('systems/mod_settings/' + name for name in ['settings_element', 'abstract_setting',
                    'elements/boolean_setting', 'settings_page', 'settings_panel',
                    'mod_settings_mod_addon', 'mod_settings_system']),
                 *('systems/tooltips/' + name for name in ['abstract_tooltip', 'tooltips/basic_tooltip',
                    'tooltips_mod_addon', 'tooltips_system'])]:
        relative = 'msu/' + name + '.nut'
        destination = ROOT / '.tools/msu-contract' / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(archive.read(relative))

for suite in ['tests/run.nut', 'tests/settings.nut']:
    result = subprocess.run([str(sq), suite], cwd=ROOT, text=True, capture_output=True)
    passed = re.search(r'^BRO_LEDGER_TESTS_PASSED (\d+)$', result.stdout, re.MULTILINE)
    # Squirrel's CLI may return success after an exception.
    if result.returncode or result.stderr or passed is None:
        print(result.stdout, end='')
        print(result.stderr, end='', file=sys.stderr)
        sys.exit(1)
    print(f'{suite}: {passed[1]} passed', flush=True)

js_tests = sorted((ROOT / 'tests').glob('*.test.cjs'))
subprocess.run(['node', '--test', '--test-reporter=spec', *map(str, js_tests)], cwd=ROOT, check=True)
for path in sorted((ROOT / 'ui').rglob('*.js')):
    subprocess.run(['node', '--check', str(path)], check=True)
