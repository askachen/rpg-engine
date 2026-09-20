"""Validate public walkthroughs before sending them to the native rule bridge."""
from pathlib import Path
from schema_check import check_schema
from content_loader import read_json


def load_scenario(path, content):
    scenario = read_json(Path(path))
    errors = check_schema(scenario, 'walkthrough.schema.json')
    if errors: raise ValueError(f'{path}: ' + '; '.join(errors))
    for key in scenario['expect']:
        if key not in content['initial'] and not ((key in ('stats', 'variables') and content.get(key)) or key == 'actions'):
            raise ValueError(f'{path}#/expect/{key}: unknown state field')
    for index, step in enumerate(scenario['steps']):
        if step['op'] == 'checks' and step['event'] not in content['events']:
            raise ValueError(f'{path}#/steps/{index}/event: unknown event')
    return scenario


def assertions(scenario, result):
    errors=[]
    for i,(step,response) in enumerate(zip(scenario['steps'],result['responses'])):
        expected=step.get('expect_result',{'ok':True})
        for key,value in expected.items():
            if response.get(key) != value: errors.append(f'step {i} {step}: expected {key}={value}, got {response}')
    if len(result['responses']) != len(scenario['steps']): errors.append('Incomplete response count')
    errors += [f'expected {key}={value}, got {result["state"].get(key)}' for key,value in scenario['expect'].items() if result['state'].get(key) != value]
    if result['active_event']: errors.append('Walkthrough ended with an active event')
    return errors
