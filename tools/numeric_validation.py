"""Numeric metadata checks; runtime arithmetic and gameplay remain in Godot."""
import math

LIMIT = 9007199254740991


def typed(value, definition):
    return (type(value) in (int, float) and math.isfinite(value) and abs(value) <= LIMIT
            and (definition['type'] == 'number' or value == math.floor(value)))


def valid(value, definition):
    return typed(value, definition) and definition.get('min', -LIMIT) <= value <= definition.get('max', LIMIT)


def definitions_errors(data):
    errors = []
    for group in ('stats', 'variables'):
        definitions = data.get(group, {})
        for key, definition in definitions.items():
            source = getattr(data, 'origins', {}).get((group, key), getattr(data, 'source_file', 'game'))
            where = f'{source}#/{group}/{key}'
            for field in ('min', 'max'):
                if field in definition and not typed(definition[field], definition):
                    errors.append(f'{where}/{field}: invalid numeric bound')
            if definition.get('min', -LIMIT) > definition.get('max', LIMIT):
                errors.append(f'{where}: min exceeds max')
            if not valid(definition.get('default', 0), definition):
                errors.append(f'{where}/default: invalid default (omitted defaults to 0)')
            for lang, strings in data['locales'].items():
                if definition['name'] not in strings:
                    errors.append(f'{where}/name: missing translation {lang}/{definition["name"]}')
        for key, value in data['initial'].get(group, {}).items():
            if key not in definitions or not valid(value, definitions[key]):
                errors.append(f'game/initial/{group}/{key}: unknown ID or invalid numeric value')
    return errors


def reference_errors(data, where, entry, effect=False):
    group = 'stats' if entry['kind'] == 'stat' else 'variables'
    definition = data.get(group, {}).get(entry['id'])
    # Locate the actual node, not just its value, so duplicate conditions remain unambiguous.
    def find(node, path):
        if node is entry:
            return path
        values = node.items() if isinstance(node, dict) else enumerate(node) if isinstance(node, list) else []
        for key, value in values:
            found = find(value, path + [key])
            if found is not None:
                return found
        return None
    path = find(data, [])
    if path:
        source = getattr(data, 'origins', {}).get(tuple(path[:2]), getattr(data, 'source_file', 'game'))
        where = str(source) + '#/' + '/'.join(map(str, path))
    else:
        where = f'{where}/{group}/{entry["id"]}'
    if definition is None:
        return [f'{where}: unknown numeric ID']
    if not typed(entry['value'], definition):
        return [f'{where}/value: invalid numeric operand']
    if effect and entry['op'] == 'set' and not valid(entry['value'], definition):
        return [f'{where}/value: set value outside bounds']
    return []
