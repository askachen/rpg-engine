"""Validate content before importing Godot. No gameplay rule implementation."""
from __future__ import annotations
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def validate(data: dict, root: Path = ROOT) -> list[str]:
    if __package__:
        from .schema_check import check_schema
    else:
        from schema_check import check_schema
    structural = check_schema(data)
    if structural:
        return structural
    if __package__:
        from .content_quality import quality_errors
    else:
        from content_quality import quality_errors
    errors = quality_errors(data, root)
    required = {'id', 'version', 'characters', 'items', 'shops', 'maps', 'events', 'locales', 'assets', 'initial'}
    for key in sorted(required - data.keys()):
        errors.append(f'game: missing {key}')
    if errors:
        return errors
    if not isinstance(data['id'],str) or not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}',data['id']):
        errors.append('game/id: expected 1-64 letters, digits, underscores or hyphens')
    def ref(where, key, collection):
        if key not in collection:
            errors.append(f'{where}: unknown reference {key}')
    def text(where, key):
        for locale, strings in data['locales'].items():
            if key not in strings:
                errors.append(f'{where}: missing translation {locale}/{key}')
    def conditions(where, values):
        collections = {'item':'items', 'affection':'characters', 'stage':'characters', 'completed':'events'}
        for condition in values:
            kind = condition.get('kind')
            if kind not in (*collections, 'flag', 'period', 'money'):
                errors.append(f'{where}: unknown condition {kind}')
            elif kind in collections:
                ref(where, condition.get('id'), data[collections[kind]])
            elif kind == 'period' and condition.get('value') not in ('day','evening','late'):
                errors.append(f'{where}: invalid period')
    def effects(where, values):
        for effect in values:
            kind=effect.get('kind')
            if kind not in ('money','item','affection','stage','flag'):
                errors.append(f'{where}: unknown effect {kind}')
            if kind in ('item','affection','stage'):
                ref(where,effect.get('id'),data['items' if kind=='item' else 'characters'])
    for asset in data['assets']:
        target = root / asset.removeprefix('res://')
        if not target.is_file(): errors.append(f'assets: missing file {asset}')
    if data.get('interior_atlas') and data['interior_atlas'] not in data['assets']:
        errors.append('interior_atlas: must be declared in assets')
    def visual(where,sheet,index):
        spec=data.get('visuals',{}).get(sheet)
        if not spec:
            errors.append(f'{where}: unknown visual sheet {sheet}')
        elif not isinstance(index,int) or not 0<=index<spec['columns']*spec['rows']:
            errors.append(f'{where}: invalid sprite index {index}')
    for sheet,spec in data.get('visuals',{}).items():
        if spec['path'] not in data['assets']:errors.append(f'{sheet}: visual path missing from assets')
    def image_ref(where,spec):
        if isinstance(spec,int):visual(where,'characters',spec)
        elif isinstance(spec,dict) and 'path' in spec:
            if spec['path'] not in data['assets']:errors.append(f'{where}: undeclared image asset')
            elif Path(spec['path']).suffix.lower() not in ('.png','.jpg','.jpeg','.webp','.svg'):errors.append(f'{where}: expected image asset')
        elif isinstance(spec,dict):visual(where,spec.get('sheet'),spec.get('index'))
        else:errors.append(f'{where}: invalid image reference')
    for who,avatar in data.get('avatars',{}).items():
        image_ref(who,avatar.get('portrait'))
        image_ref(who,avatar.get('sprite'))
    ref('protagonist',data.get('protagonist','player'),data.get('avatars',{}))
    ref('default_language',data.get('default_language','zh_TW'),data['locales'])
    presentation=data.get('presentation',{})
    for key,value in presentation.get('palette',{}).items():
        if not isinstance(value,str) or not re.fullmatch(r'#?(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})',value):errors.append(f'presentation/palette/{key}: expected hex color')
    if presentation.get('font'):
        if presentation['font'] not in data['assets']:errors.append('presentation/font: undeclared font')
        elif Path(presentation['font']).suffix.lower() not in ('.ttf','.otf','.tres'):errors.append('presentation/font: expected font resource')
    for key in ('eyebrow','title','subtitle','chapter'):
        if key in presentation.get('title',{}):text('presentation/title',presentation['title'][key])
    for layer in presentation.get('title',{}).get('layers',[]):
        image_ref('presentation/title/layer',layer.get('image'))
        rect=layer.get('rect',[])
        if not isinstance(rect,list) or len(rect)!=4 or any(not isinstance(v,(int,float)) for v in rect) or rect[2]<=0 or rect[3]<=0:errors.append('presentation/title/layer: invalid rect')
    world=presentation.get('world',{})
    wall=world.get('wall',{})
    if wall:
        visual('presentation/world/wall',wall.get('sheet'),wall.get('horizontal'))
        visual('presentation/world/wall',wall.get('sheet'),wall.get('vertical'))
    for key,spec in world.get('icons',{}).items():image_ref(f'presentation/world/icons/{key}',spec)
    ids = set()
    for map_id, area in data['maps'].items():
        text(map_id,area['name'])
        for key,material in area.get('materials',{}).items():
            if not isinstance(material.get('repeat',3),int) or material.get('repeat',3)<1:errors.append(f'{map_id}/materials/{key}: invalid repeat')

        def valid_position(pos):
            return len(pos)==2 and all(isinstance(v,int) for v in pos) and 0<=pos[0]<area['width'] and 0<=pos[1]<area['height'] and pos not in area['walls']
        furniture_cells=set()
        for furniture in area.get('furniture',[]):
            where=f'{map_id}/{furniture.get("id")}'
            visual(where,furniture.get('sheet','interior'),furniture.get('sprite'))
            if len(furniture.get('size',[]))!=2 or any(not isinstance(v,int) or v<=0 for v in furniture['size']):
                errors.append(f'{where}: invalid furniture size');continue
            for x in range(furniture['position'][0],furniture['position'][0]+furniture['size'][0]):
                for y in range(furniture['position'][1],furniture['position'][1]+furniture['size'][1]):
                    if not valid_position([x,y]) or (furniture.get('solid', True) and (x,y) in furniture_cells):
                        errors.append(f'{where}: overlapping or invalid footprint at {x},{y}')
                    if furniture.get('solid', True): furniture_cells.add((x,y))
        for decoration in area.get('decorations',[]):
            visual(decoration['id'],decoration.get('sheet','decor'),decoration.get('sprite'))
        for room in area.get('rooms',[]):
            text(map_id,room['id'])
            if not valid_position(room['door']) or tuple(room['door']) in furniture_cells:
                errors.append(f'{map_id}/{room["id"]}: blocked doorway')
        for spawn, pos in area['spawns'].items():
            if not valid_position(pos) or tuple(pos) in furniture_cells: errors.append(f'{map_id}/{spawn}: invalid spawn')
        for obj in area['objects']:
            oid = obj['id']
            if oid in ids: errors.append(f'{map_id}: duplicate object ID {oid}')
            ids.add(oid)
            text(oid,obj['label'])
            if not valid_position(obj['position']): errors.append(f'{oid}: invalid position')
            conditions(oid,obj.get('conditions',[]))
            effects(oid,obj.get('effects',[]))
            if obj['kind']=='exit':
                ref(oid,obj['destination'],data['maps'])
                if obj['destination'] in data['maps']:
                    ref(oid,obj['spawn'],data['maps'][obj['destination']]['spawns'])
            if obj['kind']=='npc': ref(oid,obj['character'],data['characters'])
            if obj['kind']=='shop': ref(oid,obj['shop'],data['shops'])
    def sequence(where, lines):
        seen=set()
        if not isinstance(lines,list):
            errors.append(f'{where}: sequence must be an array');return
        for line in lines:
            if not isinstance(line,dict):
                errors.append(f'{where}: invalid dialogue line');continue
            lid=line.get('id')
            if not isinstance(lid,str) or not lid or lid in seen:errors.append(f'{where}: invalid or duplicate line ID')
            if isinstance(lid,str): seen.add(lid)
            text(where,line.get('text'))
            ref(where,line.get('speaker'),data.get('avatars',{}))
            for field in ('background','portrait','bgm','sfx'):
                if field in line and not (field == 'bgm' and line[field] == '') and line[field] not in data['assets']:errors.append(f'{where}: undeclared {field} asset')
    for event_id,event in data['events'].items():
        sequence(event_id,event.get('sequence',[]))
        ref(event_id,event['character'],data['characters'])
        text(event_id,event['title']); text(event_id,event['text'])
        conditions(event_id,event['conditions']);effects(event_id,event.get('effects',[]))
        choice_ids=set()
        for choice in event['choices']:
            if choice['id'] in choice_ids: errors.append(f'{event_id}: duplicate choice {choice["id"]}')
            choice_ids.add(choice['id'])
            sequence(event_id,choice.get('sequence',[]))
            text(event_id,choice['text']);conditions(event_id,choice.get('conditions',[]));effects(event_id,choice.get('effects',[]))
    routed=set()
    route_previous={}
    for who,route in data.get('routes',{}).items():
        where=f'routes/{who}'
        ref(where,who,data['characters'])
        ids=route.get('events') if isinstance(route,dict) else None
        if not isinstance(ids,list) or not ids:
            errors.append(f'{where}: events must be a nonempty array');continue
        for index,eid in enumerate(ids):
            if not isinstance(eid,str):
                errors.append(f'{where}: event ID must be a string');continue
            ref(where,eid,data['events'])
            if eid in routed:errors.append(f'{where}: duplicate routed event {eid}')
            routed.add(eid)
            if index and isinstance(ids[index-1],str): route_previous[eid]=ids[index-1]
            if eid in data['events'] and data['events'][eid]['character']!=who:
                errors.append(f'{where}: event character mismatch {eid}')
    for eid,ending in data.get('endings',{}).items():
        where=f'endings/{eid}'
        text(where,ending['text'])
        if not ending.get('conditions'):errors.append(f'{where}: ending requires nonempty conditions')
        conditions(where,ending.get('conditions',[]))
    for gid,card in data.get('gallery',{}).items():
        where=f'gallery/{gid}'
        ref(where,card['character'],data['characters'])
        text(where,card['title']);text(where,card['text'])
        conditions(where,card.get('conditions',[]))
    for shop,offers in data['shops'].items():
        for item,offer in offers.items():
            ref(shop,item,data['items'])
            if not isinstance(offer['price'],int) or offer['price']<0: errors.append(f'{shop}/{item}: invalid price')
    visiting, done = set(),set()
    def visit(eid):
        if eid in visiting:
            errors.append(f'{eid}: circular mandatory event dependency');return
        if eid in done or eid not in data['events']:return
        visiting.add(eid)
        if eid in route_previous: visit(route_previous[eid])
        for c in data['events'][eid]['conditions']:
            if c['kind']=='completed' and c.get('value',True):visit(c['id'])
        visiting.remove(eid);done.add(eid)
    for eid in data['events']:visit(eid)
    return errors

def load_unique(path):
    if __package__:
        from .content_loader import load_content
    else:
        from content_loader import load_content
    return load_content(path)

if __name__=='__main__':
    import sys
    try:
        errors=validate(load_unique(sys.argv[1] if len(sys.argv)>1 else ROOT/'games/demo/game.json'))
    except (ValueError,KeyError,TypeError,OSError) as exc:
        errors=[str(exc)]
    for error in errors:print(error)
    print(f'Content validation: {len(errors)} error(s)')
    raise SystemExit(bool(errors))
