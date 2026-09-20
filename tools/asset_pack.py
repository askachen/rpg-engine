"""Built-in cozy_home catalog: list, install, and emit normal map JSON props."""
import argparse
import json
from pathlib import Path
import re
import shutil

try:
    from .content_loader import load_content
except ImportError:
    from content_loader import load_content

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'asset_packs/cozy_home'


def catalog():
    return json.loads((PACK / 'catalog.json').read_text(encoding='utf-8'))


def prop(asset_id, instance_id, position):
    entry = catalog()['entries'][asset_id]
    return dict(id=instance_id, sheet='cozy_' + asset_id, sprite=0,
                position=list(position), size=entry['size'].copy(),
                solid=entry['solid'], layer=entry['layer'])


def install(game_id, root=ROOT):
    if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}', game_id):
        raise ValueError('Expected a games/ directory ID')
    root = Path(root).resolve()
    target = (root / 'games' / game_id).resolve()
    if not target.is_relative_to(root / 'games'):
        raise ValueError('Game directory escapes games/')
    manifest = target / 'game.json'
    data = load_content(manifest)
    raw = json.loads(manifest.read_text(encoding='utf-8'))
    pack = catalog()
    destination = target / 'assets/cozy_home'
    if not destination.resolve().is_relative_to(target):
        raise ValueError('Asset directory escapes game directory')
    prefix = f'res://games/{game_id}/assets/cozy_home/'
    visuals = {}
    for key, entry in pack['entries'].items():
        spec = dict(path=prefix+entry['file'], columns=1, rows=1, opaque=[0],
                    regions={'0': entry['region']})
        name = 'cozy_' + key
        if name in data.get('visuals', {}) and data['visuals'][name] != spec:
            raise ValueError(f'Existing visual conflicts: {name}')
        if name not in data.get('visuals', {}):
            visuals[name] = spec
    files = sorted(PACK.glob('*.png')) + sorted(PACK.glob('*.prompt.txt')) + [PACK/'catalog.json', PACK/'README.md']
    # Preflight every file and visual before changing the game; never overwrite edited art.
    for source in files:
        output = destination / source.name
        if output.exists() and output.read_bytes() != source.read_bytes():
            raise ValueError(f'Existing asset conflicts: {output}')
    destination.mkdir(parents=True, exist_ok=True)
    for source in files:
        output = destination / source.name
        if not output.exists():
            shutil.copyfile(source, output)
    raw.setdefault('visuals', {}).update(visuals)
    for filename in pack['files']:
        path = prefix + filename
        if path not in raw.setdefault('assets', []):
            raw['assets'].append(path)
    encoded = json.dumps(raw, ensure_ascii=False, indent=2)+'\n'
    if manifest.read_text(encoding='utf-8') != encoded:
        temporary = manifest.with_suffix('.json.tmp')
        temporary.write_text(encoded, encoding='utf-8')
        temporary.replace(manifest)
    return dict(game=game_id, assets=len(pack['entries']), directory=str(destination))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('list')
    sub.add_parser('install').add_argument('--game', required=True)
    place = sub.add_parser('place')
    place.add_argument('asset')
    place.add_argument('--id', required=True, help='Unique map instance ID')
    place.add_argument('--at', nargs=2, type=int, required=True, metavar=('X','Y'))
    args = parser.parse_args()
    try:
        if args.command == 'list': result = catalog()
        elif args.command == 'install': result = install(args.game)
        else:
            if min(args.at) < 0 or not args.id.strip(): raise ValueError('Expected nonnegative position and nonempty ID')
            item = prop(args.asset, args.id, args.at)
            result = {'collection': 'decorations' if item['layer'] == 'wall' else 'furniture', 'value': item}
        print(json.dumps(result, ensure_ascii=False, indent=2))
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, f'{error}\n')


if __name__ == '__main__':
    main()
