"""Draft 2020-12 validation, with composed paths mapped back to source files."""
import json
import sys
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.tools/python_libs'))
try:
    from jsonschema import Draft202012Validator
except ImportError as error:
    raise RuntimeError('Install requirements-dev.txt before validating content (jsonschema missing).') from error

@lru_cache(maxsize=None)
def validator(name):
    schema = json.loads((ROOT / 'schemas' / name).read_text(encoding='utf-8'))
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema)

def check_schema(data, name='game.schema.json'):
    errors = []
    for error in sorted(validator(name).iter_errors(data), key=lambda item: str(list(item.absolute_path))):
        path = list(error.absolute_path)
        logical = '/'.join(str(part) for part in path)
        location = 'game/' + logical
        origins = getattr(data, 'origins', {})
        source = origins.get(tuple(path[:2])) if len(path) >= 2 else None
        if source:
            location = str(source) + '#/' + '/'.join(str(part) for part in path[1:]) + ' (game/' + logical + ')'
        elif getattr(data, 'source_file', None):
            location = str(data.source_file) + '#/' + logical + ' (game/' + logical + ')'
        errors.append(f'{location}: schema: {error.message}')
    return errors
