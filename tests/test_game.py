import copy
import json
import os
from pathlib import Path
import subprocess
import sys
from collections import deque
import pytest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.validate import validate, load_unique
CONTENT=load_unique(ROOT/'games/demo/game.json')

@pytest.fixture(scope='session')
def godot():
    value=os.environ.get('GODOT_BIN')
    matches=list((ROOT/'.tools/godot').glob('*console.exe'))
    if not value and not matches:
        pytest.fail('Set GODOT_BIN to a Godot 4.7.2 executable. Tests must not silently skip.')
    return value or str(matches[0])

def run(godot,tmp_path,steps):
    scenario=tmp_path/'scenario.json'; output=tmp_path/'result.json'
    scenario.write_text(json.dumps({'steps':steps}),encoding='utf-8')
    env = os.environ.copy()
    env['APPDATA'] = str(tmp_path)
    process=subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://engine/test_runner.gd','--',str(scenario),str(output)],capture_output=True,text=True,encoding='utf-8',timeout=30,env=env)
    assert process.returncode==0,process.stdout+process.stderr
    assert 'SCRIPT ERROR' not in process.stderr,process.stderr
    assert output.exists(),process.stdout+process.stderr
    return json.loads(output.read_text(encoding='utf-8'))

class Route:
    """Planning helper only: every generated movement is validated by real Godot rules."""
    def __init__(self):self.steps=[];self.map=CONTENT['initial']['map'];self.pos=tuple(CONTENT['initial']['position'])
    def go(self,target):
        area=CONTENT['maps'][self.map]
        obj=next(o for o in area['objects'] if o['id']==target)
        blocked={tuple(p) for p in area['walls']}|{tuple(o['position']) for o in area['objects']}
        for furniture in area.get('furniture',[]):
            blocked.update((x,y) for x in range(furniture['position'][0],furniture['position'][0]+furniture['size'][0]) for y in range(furniture['position'][1],furniture['position'][1]+furniture['size'][1]))
        queue=deque([(self.pos,[]) ]);seen={self.pos}
        while queue:
            pos,path=queue.popleft()
            if abs(pos[0]-obj['position'][0])+abs(pos[1]-obj['position'][1])<=1:
                self.steps.extend(path);self.pos=pos;return self
            for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
                p=(pos[0]+dx,pos[1]+dy)
                if p not in seen and p not in blocked and 0<=p[0]<area['width'] and 0<=p[1]<area['height']:
                    seen.add(p);queue.append((p,path+[dict(op='move',dx=dx,dy=dy)]))
        raise AssertionError(f'No path to {target}')
    def interact(self,target):
        self.go(target);self.steps.append(dict(op='interact',target=target))
        obj=next(o for o in CONTENT['maps'][self.map]['objects'] if o['id']==target)
        if obj['kind']=='exit':self.map=obj['destination'];self.pos=tuple(CONTENT['maps'][self.map]['spawns'][obj['spawn']])
        return self
    def add(self,op,**kwargs):self.steps.append(dict(op=op,**kwargs));return self
    def event(self,npc):return self.interact(npc).add('choose',choice='accept')

def full_route():
    r=Route().interact('money_pickup').interact('home_exit')
    r.event('b_npc').interact('lamp').event('b_npc')
    r.interact('street_shop').event('a_npc').interact('counter')
    r.add('buy',shop='general',item='coffee').add('buy',shop='general',item='letter')
    r.add('wait').event('a_npc').add('snapshot',id='mid').add('save').add('wait').add('load').add('snapshot',id='restored')
    r.event('a_npc').interact('shop_exit').add('wait').event('b_npc')
    return r

def test_content_is_valid():assert validate(CONTENT)==[]

@pytest.mark.parametrize('defect',['missing_file','translation','reference','cycle','duplicate','spawn'])
def test_validator_catches_broken_content(defect):
    data=copy.deepcopy(CONTENT)
    if defect=='missing_file':data['assets']=['res://missing.ogv']
    if defect=='translation':del data['locales']['en']['a1_line']
    if defect=='reference':data['events']['a1']['character']='ghost'
    if defect=='cycle':data['events']['a1']['conditions'].append(dict(kind='completed',id='a3',value=True))
    if defect=='duplicate':data['maps']['home']['objects'].append(data['maps']['home']['objects'][0])
    if defect=='spawn':data['maps']['home']['spawns']['entry']=[-1,0]
    assert validate(data)

def test_both_routes_complete_with_save_restore(godot,tmp_path):
    result=run(godot,tmp_path,full_route().steps)
    assert all(r['ok'] for r in result['responses']),result['history']
    assert set(result['state']['completed'])==set(CONTENT['events'])
    assert result['state']['money']==50
    assert result['state']['inventory']=={'coffee':0,'letter':0}
    assert result['snapshots']['mid']==result['snapshots']['restored']
    assert all(c['stage']==3 for c in result['state']['characters'].values())

def test_pickup_once_and_atomic_failed_purchase(godot,tmp_path):
    r=Route().interact('money_pickup').add('snapshot',id='once').interact('money_pickup').add('snapshot',id='twice')
    result=run(godot,tmp_path,r.steps)
    assert result['snapshots']['once']==result['snapshots']['twice']
    assert result['responses'][-2]['message']=='already_used'
    r=Route().interact('home_exit').interact('street_shop').interact('counter').add('snapshot',id='before').add('buy',shop='general',item='coffee').add('snapshot',id='after')
    result=run(godot,tmp_path,r.steps)
    assert result['responses'][-2]['message']=='insufficient_money'
    assert result['snapshots']['before']==result['snapshots']['after']

def test_time_collision_and_unreachable_shop(godot,tmp_path):
    steps=[dict(op='move',dx=1,dy=0),dict(op='buy',shop='general',item='coffee')]+[dict(op='wait')]*3
    result=run(godot,tmp_path,steps)
    assert result['responses'][0]['message']=='blocked'
    assert result['responses'][1]['message']=='shop_unreachable'
    assert result['state']['day']==2 and result['state']['period']=='day'

def test_cancel_busy_and_missing_and_conditions(godot,tmp_path):
    r=Route().interact('home_exit').interact('street_shop').interact('a_npc').add('wait').add('save').add('choose',choice='later').add('checks',event='a2')
    result=run(godot,tmp_path,r.steps)
    assert result['responses'][-4]['message']=='event_busy'
    assert not result['responses'][-3]['ok']
    assert result['state']['completed']==[]
    assert not all(c['passed'] for c in result['responses'][-1]['checks'])

def test_completed_events_do_not_repeat(godot,tmp_path):
    r=full_route().add('snapshot',id='before').interact('b_npc').add('snapshot',id='after')
    result=run(godot,tmp_path,r.steps)
    assert result['responses'][-2]['message']=='smalltalk'
    assert result['snapshots']['before']==result['snapshots']['after']

def test_mouse_only_ui_route(godot,tmp_path):
    env=os.environ.copy()
    env['APPDATA']=str(tmp_path)
    result=subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://engine/mouse_test.gd'],capture_output=True,text=True,encoding='utf-8',timeout=45,env=env)
    assert result.returncode==0,result.stdout+result.stderr
    assert 'SCRIPT ERROR' not in result.stderr,result.stderr
    assert '"mouse_test_failures":[]' in result.stdout,result.stdout

def test_independent_slots_and_latest_valid_save(godot,tmp_path):
    steps=[dict(op='save_slot',slot=1),dict(op='wait'),dict(op='save_slot',slot=2),
           dict(op='wait'),dict(op='save_slot',slot=0),dict(op='latest_slot'),
           dict(op='load_slot',slot=1),dict(op='snapshot',id='one'),
           dict(op='load_slot',slot=2),dict(op='snapshot',id='two'),
           dict(op='load_slot',slot=0),dict(op='snapshot',id='auto'),
           dict(op='save_slot',slot=7)]
    result=run(godot,tmp_path,steps)
    assert result['responses'][5]['slot']==0
    assert result['snapshots']['one']['period']=='day'
    assert result['snapshots']['two']['period']=='evening'
    assert result['snapshots']['auto']['period']=='late'
    assert not result['responses'][-1]['ok']
    # Continue must ignore a newer damaged file and find the newest valid slot.
    (tmp_path/'story_garden_demo_auto.json').write_text('{bad json',encoding='utf-8')
    result=run(godot,tmp_path,[dict(op='slot_info',slot=0),dict(op='latest_slot'),dict(op='load_slot',slot=0)])
    assert result['responses'][0]['info']['exists'] and not result['responses'][0]['info']['valid']
    assert result['responses'][1]['slot']==2
    assert not result['responses'][2]['ok']

def test_legacy_slot_and_invalid_state_are_handled(godot,tmp_path):
    run(godot,tmp_path,[dict(op='save_slot',slot=1)])
    path=tmp_path/'story_garden_demo_slot1.json'
    data=json.loads(path.read_text(encoding='utf-8'))
    assert 'saved_at' in data and data['content_version']==CONTENT['version']
    del data['saved_at'];del data['content_version']
    path.write_text(json.dumps(data),encoding='utf-8')
    result=run(godot,tmp_path,[dict(op='load_slot',slot=1),dict(op='slot_info',slot=1)])
    assert result['responses'][0]['ok'] and result['responses'][1]['info']['valid']
    data['state']['position']=[999,999]
    path.write_text(json.dumps(data),encoding='utf-8')
    result=run(godot,tmp_path,[dict(op='load_slot',slot=1),dict(op='latest_slot')])
    assert not result['responses'][0]['ok'] and result['responses'][1]['slot']==-1

def test_home_rooms_accessible_and_furniture_solid(godot,tmp_path):
    home=CONTENT['maps']['home']
    destinations=[r['door'] for r in home['rooms']]+[[5,3],[14,3],[24,3],[26,11],[25,15],[8,14],[18,14]]
    steps=[dict(op='path',x=p[0],y=p[1]) for p in destinations]
    steps += [dict(op='path',x=2,y=1),dict(op='path',x=6,y=4),dict(op='path',x=9,y=3)]
    result=run(godot,tmp_path,steps)
    assert all(r['ok'] for r in result['responses'][:-3]),result['responses']
    assert not any(r['ok'] for r in result['responses'][-3:])
    broken=copy.deepcopy(CONTENT)
    broken['maps']['home']['furniture'][0]['position']=[0,0]
    assert any('footprint' in e for e in validate(broken))

def test_old_home_save_keeps_progress_after_floorplan_change(godot,tmp_path):
    state=copy.deepcopy(CONTENT['initial'])
    state['position']=[8,3]
    state['money']=42
    (tmp_path/'story_garden_demo_slot1.json').write_text(json.dumps(dict(game_id=CONTENT['id'],version=1,content_version=2,state=state)),encoding='utf-8')
    result=run(godot,tmp_path,[dict(op='load_slot',slot=1)])
    assert result['responses'][0]['ok']
    assert result['state']['position']==CONTENT['maps']['home']['spawns']['entry']
    assert result['state']['money']==42

def test_visual_references_catch_missing_avatars_and_wrong_regions():
    broken=copy.deepcopy(CONTENT)
    broken['avatars']['a']['portrait']=99
    assert any('sprite index' in error for error in validate(broken))
    broken=copy.deepcopy(CONTENT)
    broken['maps']['home']['decorations'][0]['sheet']='missing_rug_sheet'
    assert any('unknown visual sheet' in error for error in validate(broken))


def test_dialogue_playback_modes_and_single_commit(godot,tmp_path):
    env=os.environ.copy();env['APPDATA']=str(tmp_path)
    result=subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://engine/dialogue_test.gd'],capture_output=True,text=True,encoding='utf-8',timeout=30,env=env)
    assert result.returncode==0,result.stdout+result.stderr
    assert 'SCRIPT ERROR' not in result.stderr,result.stderr
    assert '"dialogue_test_failures":[]' in result.stdout,result.stdout


def test_dialogue_content_validation():
    broken=copy.deepcopy(CONTENT)
    broken['events']['a2']['sequence'][0]['background']='res://missing.png'
    assert any('undeclared background' in e for e in validate(broken))
    broken=copy.deepcopy(CONTENT)
    broken['events']['a2']['sequence'][1]['id']=broken['events']['a2']['sequence'][0]['id']
    assert any('duplicate line ID' in e for e in validate(broken))
    broken=copy.deepcopy(CONTENT)
    broken['events']['a2']['sequence'][0]['text']='missing_line'
    assert any('missing translation' in e for e in validate(broken))


def test_bootstrap_content_override_and_isolated_data(godot,tmp_path):
    alternate=copy.deepcopy(CONTENT);alternate['id']='alternate_game'
    content=tmp_path/'alternate.json';content.write_text(json.dumps(alternate),encoding='utf-8')
    env=os.environ.copy();env['APPDATA']=str(tmp_path)
    result=subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://engine/bootstrap_test.gd','--',f'--game={content}'],capture_output=True,text=True,encoding='utf-8',timeout=30,env=env)
    assert result.returncode==0,result.stdout+result.stderr
    assert 'SCRIPT ERROR' not in result.stderr,result.stderr
    assert '"bootstrap_failures":[]' in result.stdout,result.stdout


def test_game_id_is_safe_for_persistent_paths():
    for bad in ['../escape','', 'game/name', 'x'*65]:
        broken=copy.deepcopy(CONTENT);broken['id']=bad
        assert any('game/id' in e for e in validate(broken))


def test_default_bootstrap_preserves_existing_demo_profile(godot,tmp_path):
    env=os.environ.copy();env['APPDATA']=str(tmp_path)
    result=subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://engine/bootstrap_test.gd','--','--legacy'],capture_output=True,text=True,encoding='utf-8',timeout=30,env=env)
    assert result.returncode==0,result.stdout+result.stderr
    assert 'SCRIPT ERROR' not in result.stderr,result.stderr
    assert '"bootstrap_failures":[]' in result.stdout,result.stdout


def route_fixture():
    data=copy.deepcopy(CONTENT)
    data['id']='route_fixture'
    data['presentation']['title']['layers']=[]
    sequences={'ivy':['arrival'],'mira':['lost_ribbon','promise'],'noa':['letter','rain','sunrise','reunion']}
    data['characters']={who:{'color':'#e0bd91'} for who in sequences}
    data['avatars']={'player':copy.deepcopy(CONTENT['avatars']['player']),**{who:copy.deepcopy(CONTENT['avatars']['a']) for who in sequences}}
    data['initial']['characters']={who:{'stage':0,'affection':0} for who in sequences}
    data['events']={};data['routes']={};data['gallery']={}
    area=data['maps']['home'];area['objects']=[]
    for i,(who,ids) in enumerate(sequences.items()):
        area['objects'].append(dict(id=who+'_npc',kind='npc',character=who,label=who,position=[[3,8],[2,9],[1,8]][i],solid=True))
        data['routes'][who]={'events':ids}
        for stage,eid in enumerate(ids):
            # Future events deliberately satisfy conditions and have higher priority.
            # Route order itself must stop them from preempting the first event.
            data['events'][eid]=dict(character=who,title=eid,text=eid,conditions=[],priority=stage,
                choices=[dict(id='accept',text='accept')],effects=[dict(kind='stage',id=who,value=stage+1)])
        data['gallery']['keepsake_'+who]=dict(character=who,title=who,text=ids[-1],conditions=[dict(kind='completed',id=ids[-1],value=True)])
    data['endings']={'reunion':dict(text='fixture_end',conditions=[dict(kind='completed',id=ids[-1],value=True) for ids in sequences.values()])}
    # Retain only this authored map; there are no portal dependencies in the fixture.
    data['maps']={'home':area}
    for locale in data['locales'].values():
        locale.update({key:key for key in [*sequences,*data['events'],'fixture_end']})
    return data


def test_configured_routes_and_ending_in_real_ui(godot,tmp_path):
    data=route_fixture()
    assert validate(data)==[]
    content=tmp_path/'routes.json';content.write_text(json.dumps(data),encoding='utf-8')
    env=os.environ.copy();env['APPDATA']=str(tmp_path)
    result=subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://engine/routes_test.gd','--',f'--game={content}'],capture_output=True,text=True,encoding='utf-8',timeout=30,env=env)
    assert result.returncode==0,result.stdout+result.stderr
    assert 'SCRIPT ERROR' not in result.stderr,result.stderr
    assert '"route_failures":[]' in result.stdout,result.stdout


def test_route_reference_validation():
    data=route_fixture();data['routes']['ivy']['events'].append('arrival')
    assert any('duplicate routed' in e for e in validate(data))
    data=route_fixture();data['routes']['ivy']['events']=['lost_ribbon']
    assert any('character mismatch' in e for e in validate(data))
    data=route_fixture();data['routes']['ivy']['events']=['unknown']
    assert any('unknown reference' in e for e in validate(data))
    data=route_fixture();data['endings']['reunion']['conditions']=[]
    assert any('nonempty conditions' in e for e in validate(data))


def test_route_order_participates_in_dependency_cycles():
    data=route_fixture()
    data['events']['lost_ribbon']['conditions']=[dict(kind='completed',id='promise',value=True)]
    assert any('circular mandatory event dependency' in e for e in validate(data))


def presentation_fixture():
    data=route_fixture();data['id']='presentation_fixture';data['protagonist']='traveler'
    data['avatars']['traveler']=data['avatars'].pop('player')
    data['visuals']['cast']=data['visuals'].pop('characters')
    for avatar in data['avatars'].values():
        for key in ('portrait','sprite'):avatar[key]={'sheet':'cast','index':avatar[key]}
    data['avatars']['traveler']['portrait']['index']=2
    data['presentation']={'font':'res://tests/fixtures/ui_font.tres','palette':{'panel':'473449','button':'664b68','hover':'855f87','background':'241f2a','title_outer':'3f314d','title_inner':'51395b'},'world':copy.deepcopy(CONTENT['presentation']['world']),'title':{'title':'fixture_title','eyebrow':'fixture_brand','layers':[{'image':{'sheet':'cast','index':2},'rect':[1040,170,500,720]}]}}
    data['assets'].append('res://tests/fixtures/ui_font.tres')
    for locale in data['locales'].values():locale.update(traveler='Traveler',fixture_title='Amber Letters',fixture_brand='A DIFFERENT STORY')
    return data


def test_custom_theme_protagonist_assets_and_font(godot,tmp_path):
    data=presentation_fixture();assert validate(data)==[]
    content=tmp_path/'theme.json';content.write_text(json.dumps(data),encoding='utf-8')
    env=os.environ.copy();env['APPDATA']=str(tmp_path)
    result=subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://engine/presentation_test.gd','--',f'--game={content}'],capture_output=True,text=True,encoding='utf-8',timeout=30,env=env)
    assert result.returncode==0,result.stdout+result.stderr
    assert 'SCRIPT ERROR' not in result.stderr,result.stderr
    assert '"presentation_failures":[]' in result.stdout,result.stdout


def test_presentation_validation():
    for mutate,expected in [
        (lambda d:d.update(protagonist='missing'),'protagonist'),
        (lambda d:d['presentation']['palette'].update(panel='not-a-color'),'hex color'),
        (lambda d:d['presentation'].update(font='res://missing.ttf'),'undeclared font'),
        (lambda d:d['avatars']['traveler'].update(portrait={'sheet':'missing','index':0}),'unknown visual sheet'),
        (lambda d:d['presentation']['title']['layers'][0].update(rect=[0,0,0,10]),'invalid rect')]:
        data=presentation_fixture();mutate(data)
        assert any(expected in e for e in validate(data))


def test_runtime_module_dependencies_are_acyclic():
    import re
    paths={p.name:p for p in (ROOT/'engine').glob('*.gd') if not p.name.endswith('_test.gd')}
    edges={name:[Path(ref).name for ref in re.findall(r'(?:preload|load)\("(res://engine/[^" ]+\.gd)"\)',p.read_text(encoding='utf-8'))] for name,p in paths.items()}
    active=set();done=set()
    def visit(name):
        assert name not in active,f'Circular module dependency: {name}'
        if name in done:return
        active.add(name)
        for child in edges.get(name,[]):visit(child)
        active.remove(name);done.add(name)
    for name in edges:visit(name)
    for name in ('presentation_theme.gd','world_renderer.gd','art_library.gd'):
        assert 'core.act(' not in paths[name].read_text(encoding='utf-8')


def compose_in_godot(godot,tmp_path,manifest):
    output=tmp_path/'composed.json'
    env=os.environ.copy();env['APPDATA']=str(tmp_path)
    result=subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://engine/content_test.gd','--',str(manifest),str(output)],capture_output=True,text=True,encoding='utf-8',timeout=30,env=env)
    assert result.returncode==0 and 'SCRIPT ERROR' not in result.stderr,result.stdout+result.stderr
    return json.loads(output.read_text(encoding='utf-8'))


def test_split_demo_matches_runtime_composition(godot,tmp_path):
    manifest=ROOT/'games/demo/game.json'
    raw=json.loads(manifest.read_text(encoding='utf-8'))
    assert 'events' not in raw and len(raw['sources']['events'])==6
    actual=compose_in_godot(godot,tmp_path,manifest)
    assert actual['error']==''
    assert actual['data']==CONTENT
    assert validate(CONTENT)==[]


@pytest.mark.parametrize('defect',['duplicate','missing','escape','version','bad_json'])
def test_manifest_errors_have_source_context(godot,tmp_path,defect):
    from tools.content_loader import load_content
    manifest=tmp_path/'game.json';fragment=tmp_path/'event.json'
    fragment.write_text(json.dumps({'meeting':{'text':'hello'}}),encoding='utf-8')
    data={'id':'manifest_fixture','version':1,'format_version':1,'sources':{'events':['event.json']}}
    if defect=='duplicate':data['sources']['events'].append('event.json')
    if defect=='missing':data['sources']['events']=['missing.json']
    if defect=='escape':data['sources']['events']=['../escape.json']
    if defect=='version':data['format_version']=9
    if defect=='bad_json':fragment.write_text('{ broken',encoding='utf-8')
    manifest.write_text(json.dumps(data),encoding='utf-8')
    with pytest.raises(ValueError) as error:load_content(manifest)
    assert str(tmp_path) in str(error.value)
    actual=compose_in_godot(godot,tmp_path,manifest)
    assert actual['error'] and str(tmp_path).replace('\\','/') in actual['error'].replace('\\','/')


def test_content_cli_list_and_validate():
    result=subprocess.run([sys.executable,'tools/dev.py','list'],cwd=ROOT,capture_output=True,text=True)
    assert result.returncode==0 and 'demo' in result.stdout and 'theme_preview' in result.stdout
    result=subprocess.run([sys.executable,'tools/dev.py','validate','--game','theme_preview'],cwd=ROOT,capture_output=True,text=True)
    assert result.returncode==0,result.stdout+result.stderr
    result=subprocess.run([sys.executable,'tools/dev.py','validate','--game','does_not_exist'],cwd=ROOT,capture_output=True,text=True)
    assert result.returncode==2 and 'Content not found' in result.stderr


@pytest.mark.parametrize('section,key,field,value',[('events','a2','time_cost',-1),('events','a2','choices',{}),('maps','home','width',True),('maps','home','height','17'),('characters','a','unexpected',1)])
def test_schema_rejects_wrong_types_and_unknown_fields(section,key,field,value):
    data=copy.deepcopy(CONTENT);data[section][key][field]=value
    errors=validate(data)
    assert errors and 'schema:' in errors[0]
    assert f'{section}/{key}' in errors[0].replace('\\','/')


def test_schema_diagnostic_resolves_source_file(tmp_path):
    from tools.content_loader import load_content
    import shutil
    package=tmp_path/'package'
    shutil.copytree(ROOT/'games/demo',package)
    path=package/'events/a2.json';data=json.loads(path.read_text(encoding='utf-8'))
    data['a2']['time_cost']='tomorrow';path.write_text(json.dumps(data),encoding='utf-8')
    errors=validate(load_content(package/'game.json'))
    assert any(str(path) in e and '#/a2/time_cost' in e for e in errors)


def test_schema_boolean_is_not_money_or_count():
    data=copy.deepcopy(CONTENT);data['initial']['money']=True
    assert any('initial/money' in e and 'schema:' in e for e in validate(data))


def test_manifest_schema_rejects_unknown_keys(tmp_path):
    from tools.content_loader import load_content
    path=tmp_path/'game.json';path.write_text(json.dumps({'id':'bad','version':1,'format_version':1,'sources':{},'sorces':{}}),encoding='utf-8')
    with pytest.raises(ValueError,match='sorces'):load_content(path)


@pytest.mark.parametrize('defect',['region','region_index','opaque','media','parameter','missing_ui','extra_key'])
def test_asset_and_locale_quality_errors(defect):
    data=copy.deepcopy(CONTENT)
    if defect=='region':data['visuals']['decor']['regions']['4']=[0.9,0,0.5,1]
    if defect=='region_index':data['visuals']['decor']['regions']['99']=[0,0,1,1]
    if defect=='opaque':data['visuals']['decor']['opaque']=[99]
    if defect=='media':data['events']['a2']['sequence'][0]['bgm']=data['visuals']['decor']['path']
    if defect=='parameter':data['locales']['en']['stage_requirement']='Required %s; current %d'
    if defect=='missing_ui':del data['locales']['en']['wait']
    if defect=='extra_key':data['locales']['en']['orphan_key']='Orphan'
    assert validate(data)


def test_format_width_and_named_parameter_order_are_valid():
    data=copy.deepcopy(CONTENT)
    data['locales']['zh_TW']['quality_example']='{name}: %02d / {count} %%'
    data['locales']['en']['quality_example']='{count}, {name}: %d %%'
    assert validate(data)==[]


def test_corrupt_image_and_truncated_pcm_are_detected(tmp_path):
    from tools.content_quality import quality_errors
    import wave
    data=copy.deepcopy(CONTENT)
    image=tmp_path/'broken.png';image.write_bytes(b'not png')
    audio=tmp_path/'broken.wav'
    with wave.open(str(audio),'wb') as stream:
        stream.setparams((1,2,22050,0,'NONE','not compressed'));stream.writeframes(b'\0'*100)
    audio.write_bytes(audio.read_bytes()[:-20])
    data['assets']=['res://broken.png','res://broken.wav']
    errors=quality_errors(data,tmp_path)
    assert sum('asset decode failed' in error for error in errors)==2


def test_native_asset_probe(godot,tmp_path):
    env=os.environ.copy();env['APPDATA']=str(tmp_path)
    output=tmp_path/'probe.json'
    result=subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://engine/asset_probe.gd','--',str(ROOT/'games/demo/game.json'),str(output)],capture_output=True,text=True,encoding='utf-8',timeout=30,env=env)
    assert result.returncode==0 and 'SCRIPT ERROR' not in result.stderr,result.stdout+result.stderr
    assert json.loads(output.read_text(encoding='utf-8'))['errors']==[]


def test_native_asset_probe_rejects_corruption(godot,tmp_path):
    env=os.environ.copy();env['APPDATA']=str(tmp_path)
    image=tmp_path/'bad.png';image.write_bytes(b'not an image')
    manifest=tmp_path/'probe-input.json';manifest.write_text(json.dumps({'assets':[str(image)]}),encoding='utf-8')
    output=tmp_path/'probe.json'
    result=subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://engine/asset_probe.gd','--',str(manifest),str(output)],capture_output=True,text=True,encoding='utf-8',timeout=30,env=env)
    assert result.returncode==1
    assert any('Godot image decode failed' in e for e in json.loads(output.read_text(encoding='utf-8'))['errors'])


def test_new_game_scaffold_is_independent_and_completable(godot,tmp_path):
    from tools.new_game import create_game
    manifest=create_game('starter_test',tmp_path)
    data=load_unique(manifest)
    assert validate(data,tmp_path)==[]
    assert not any('games/demo/' in asset for asset in data['assets'])
    assert (manifest.parent/'README.md').exists()
    assert list((manifest.parent/'assets').glob('*.prompt.txt'))
    scenario=json.loads((manifest.parent/'tests/walkthrough.json').read_text(encoding='utf-8'))
    expected=scenario['expect']
    scenario['content']=str(manifest)
    scenario['steps'] += [dict(op='save_slot',slot=1),dict(op='snapshot',id='saved'),dict(op='move',dx=1,dy=0),dict(op='load_slot',slot=1),dict(op='snapshot',id='loaded')]
    source=tmp_path/'scenario.json';output=tmp_path/'result.json';source.write_text(json.dumps(scenario),encoding='utf-8')
    env=os.environ.copy();env['APPDATA']=str(tmp_path)
    result=subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://engine/test_runner.gd','--',str(source),str(output)],capture_output=True,text=True,encoding='utf-8',timeout=30,env=env)
    assert result.returncode==0 and 'SCRIPT ERROR' not in result.stderr,result.stdout+result.stderr
    report=json.loads(output.read_text(encoding='utf-8'))
    assert all(item['ok'] for item in report['responses']),report['responses']
    assert all(report['state'][key]==value for key,value in expected.items())
    assert report['snapshots']['saved']==report['snapshots']['loaded']
    assert report['state']['position']!=data['initial']['position']


def test_new_game_refuses_overwrite_and_unsafe_names(tmp_path):
    from tools.new_game import create_game
    directory=tmp_path/'games/existing';directory.mkdir(parents=True)
    marker=directory/'keep.txt';marker.write_text('preserve')
    with pytest.raises(ValueError,match='overwrite'):create_game('existing',tmp_path)
    assert marker.read_text()=='preserve'
    for name in ['../outside','bad/name','', 'x'*65]:
        with pytest.raises(ValueError):create_game(name,tmp_path)


def test_starter_template_mouse_walkthrough(godot,tmp_path):
    env=os.environ.copy();env['APPDATA']=str(tmp_path)
    result=subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://engine/starter_mouse_test.gd','--','--game=res://games/first_story/game.json'],capture_output=True,text=True,encoding='utf-8',timeout=45,env=env)
    assert result.returncode==0 and 'SCRIPT ERROR' not in result.stderr,result.stdout+result.stderr
    assert '"starter_mouse_failures":[]' in result.stdout,result.stdout
