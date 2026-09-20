"""Deterministic manifest composition. Gameplay rules remain in Godot."""
import json
from pathlib import Path

COLLECTIONS = {'maps', 'characters', 'events', 'items', 'shops', 'routes', 'endings',
               'gallery', 'locales', 'avatars', 'visuals', 'stats', 'variables'}

class ContentDocument(dict):
    """Source metadata lives outside JSON keys and is never passed to game rules."""
    def __init__(self, data, source_file):
        super().__init__(data)
        self.source_file = source_file
        self.origins = {}

def read_json(path):
    path = Path(path)
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError(f'{path}: duplicate JSON key: {key}')
            result[key] = value
        return result
    try:
        value = json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=pairs)
    except (OSError, ValueError) as error:
        raise ValueError(f'{path}: {error}') from error
    if not isinstance(value, dict):
        raise ValueError(f'{path}: expected JSON object')
    return value

def load_content(path):
    path = Path(path).resolve()
    data = ContentDocument(read_json(path), path)
    if 'sources' not in data:
        return data
    if __package__:
        from .schema_check import check_schema
    else:
        from schema_check import check_schema
    structural = check_schema(data, 'manifest.schema.json')
    if structural:
        raise ValueError('\n'.join(structural))
    if data.get('format_version') != 1:
        raise ValueError(f'{path}/format_version: expected 1')
    sources = data.pop('sources')
    data.pop('format_version', None)
    if not isinstance(sources, dict):
        raise ValueError(f'{path}/sources: expected object')
    for section, files in sources.items():
        if section not in COLLECTIONS or not isinstance(files, list):
            raise ValueError(f'{path}/sources/{section}: unknown collection or invalid file list')
        merged = data.setdefault(section, {})
        if not isinstance(merged, dict):
            raise ValueError(f'{path}/{section}: expected object')
        owners = {key: str(path) for key in merged}
        for relative in files:
            if not isinstance(relative, str) or not relative or ':' in relative or '\\' in relative or relative.startswith('/') or '..' in relative.split('/'):
                raise ValueError(f'{path}/sources/{section}: expected relative path inside content directory')
            target = (path.parent / relative).resolve()
            if not target.is_relative_to(path.parent):
                raise ValueError(f'{target}: source escapes content directory')
            fragment = read_json(target)
            for key, value in fragment.items():
                if key in merged:
                    raise ValueError(f'{target}/{section}/{key}: duplicate ID; first defined in {owners[key]}')
                merged[key] = value
                owners[key] = str(target)
                data.origins[(section, key)] = target
    return data
