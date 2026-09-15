"""Validate public walkthroughs before sending them to the native rule bridge."""
from pathlib import Path
from schema_check import check_schema
from content_loader import read_json


def load_scenario(path, content):
    scenario = read_json(Path(path))
    errors = check_schema(scenario, 'walkthrough.schema.json')
    if errors: raise ValueError(f'{path}: ' + '; '.join(errors))
    for key in scenario['expect']:
        if key not in content['initial']: raise ValueError(f'{path}#/expect/{key}: unknown state field')
    for index, step in enumerate(scenario['steps']):
        if step['op'] == 'checks' and step['event'] not in content['events']:
            raise ValueError(f'{path}#/steps/{index}/event: unknown event')
    return scenario
