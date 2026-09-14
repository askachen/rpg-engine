"""Create a self-contained starter content pack; never overwrite a directory."""
import copy
import json
import re
import shutil
from pathlib import Path
try:
    from .content_loader import load_content
    from .validate import validate
except ImportError:
    from content_loader import load_content
    from validate import validate

ROOT = Path(__file__).resolve().parents[1]

def create_game(game_id, root=ROOT):
    if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}', game_id):
        raise ValueError('Game ID must be 1-64 letters, digits, underscores or hyphens')
    root = Path(root).resolve()
    target = root / 'games' / game_id
    if target.exists():
        raise ValueError(f'Refusing to overwrite existing directory: {target}')
    template = load_content(ROOT / 'games/demo/game.json')
    data = {key: copy.deepcopy(template[key]) for key in ['visuals','locales','presentation','locale_names']}
    data.update(id=game_id, version=1, protagonist='hero', default_language='zh_TW', assets=[])
    data['visuals'] = {key: data['visuals'][key] for key in ['interior','characters','town']}
    copies = []
    for spec in data['visuals'].values():
        source = ROOT / spec['path'].removeprefix('res://')
        spec['path'] = f'res://games/{game_id}/assets/{source.name}'
        data['assets'].append(spec['path'])
        copies.append(source)
    data['presentation']['title'] = dict(eyebrow='brand', title='title', subtitle='subtitle', chapter='chapter', layers=[
        dict(image=dict(sheet='characters',index=0),rect=[960,260,320,620]),
        dict(image=dict(sheet='characters',index=1),rect=[1320,220,350,660])])
    data['avatars'] = {'hero':dict(portrait=dict(sheet='characters',index=0),sprite=dict(sheet='characters',index=3)),
                       'guide':dict(portrait=dict(sheet='characters',index=1),sprite=dict(sheet='characters',index=4))}
    data['characters'] = {'guide':dict(name='guide',color='e0ad72')}
    data['items'] = {'tea':dict(name='tea')}
    data['shops'] = {'kiosk':{'tea':dict(price=10)}}
    data['initial'] = dict(map='room',position=[2,3],day=1,period='day',money=0,inventory={},
        characters={'guide':dict(stage=0,affection=0)},completed=[],flags={},objects={},stock={'kiosk:tea':1})
    data['maps'] = {'room':dict(name='room',width=16,height=12,cell_size=55,floor_sheet='interior',floor_index=0,
        walls=[[x,y] for y in range(12) for x in range(16) if x in (0,15) or y in (0,11)],spawns={'entry':[2,3]},
        objects=[dict(id='coins',kind='pickup',position=[3,3],label='coins',effects=[dict(kind='money',value=20)]),
                 dict(id='guide_npc',kind='npc',position=[5,3],label='guide',character='guide'),
                 dict(id='kiosk_counter',kind='shop',position=[7,3],label='counter',shop='kiosk')],
        furniture=[dict(id='table',sheet='interior',sprite=6,position=[5,7],size=[3,2],solid=True)])}
    def event(stage, text, extra, effects):
        return dict(character='guide',title=text,text=text,conditions=[dict(kind='stage',id='guide',value=stage),*extra],
            choices=[dict(id='accept',text='accept'),dict(id='later',text='later',cancel=True)],
            effects=[dict(kind='stage',id='guide',value=stage+1),dict(kind='affection',id='guide',value=10),*effects],
            time_cost=1 if stage==0 else 0,sequence=[dict(id=text,speaker='guide',text=text)])
    data['events'] = {'welcome':event(0,'welcome_line',[],[]),
        'tea_time':event(1,'tea_line',[dict(kind='completed',id='welcome',value=True),dict(kind='item',id='tea',value=1),dict(kind='period',value='evening')],[dict(kind='item',id='tea',value=-1)])}
    data['routes'] = {'guide':dict(events=['welcome','tea_time'])}
    done = [dict(kind='completed',id='tea_time',value=True)]
    data['endings'] = {'friendship':dict(text='end',conditions=done)}
    data['gallery'] = {'first_memory':dict(character='guide',title='memory',text='tea_line',conditions=done)}
    words = {
        'title':(game_id,game_id),'brand':('MY FIRST STORY','MY FIRST STORY'),
        'subtitle':('從一杯茶開始的故事','A story that starts with a cup of tea'),
        'chapter':('新遊戲範本 · 兩個事件','Starter game · two events'),
        'hero':('旅人','Traveler'),'guide':('小晴','Haru'),'room':('會客室','Meeting room'),
        'tea':('熱茶','Warm tea'),'coins':('零用錢','Pocket money'),
        'welcome_line':('歡迎！晚上帶杯茶來，我們再聊聊吧。','Welcome! Bring a cup of tea this evening and we can talk again.'),
        'tea_line':('謝謝你的茶，很高興認識你！','Thank you for the tea. It is lovely to meet you!'),
        'welcome':('初次見面','First meeting'),'tea_time':('茶敘','Tea time'),
        'memory':('第一個回憶','First memory'),'end':('範本故事完成！你可以開始編寫自己的故事。','Starter story complete! You can now write your own story.')}
    for key,(zh,en) in words.items():
        data['locales']['zh_TW'][key]=zh
        data['locales']['en'][key]=en
    # Validate the assembled pack after copying its referenced assets.
    target.mkdir(parents=True, exist_ok=False)
    (target/'assets').mkdir()
    for source in copies:
        shutil.copyfile(source,target/'assets'/source.name)
        prompt = source.with_suffix('.prompt.txt')
        if prompt.exists(): shutil.copyfile(prompt,target/'assets'/prompt.name)
    (target/'assets/README.md').write_text('Starter artwork copied unchanged from the project demo. Original PNGs and available prompts are preserved. Review redistribution/licensing before release; this is not an independent rights clearance.\n',encoding='utf-8')
    errors = validate(data,root)
    if errors: raise ValueError('Created draft has validation errors; retained for inspection: '+ '\n'.join(errors))
    def write(path,value):
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    sources = {}
    for section in ['maps','characters','events','items','shops','routes','endings','gallery','locales']:
        values=data.pop(section);sources[section]=[]
        for key,value in values.items():
            relative=f'{section}/{key}.json';sources[section].append(relative)
            write(target/relative,{key:value})
    data.update(format_version=1,sources=sources)
    write(target/'game.json',data)
    steps=[dict(op='interact',target='coins'),dict(op='move',dx=1,dy=0),dict(op='move',dx=1,dy=0),
           dict(op='interact',target='guide_npc'),dict(op='choose',choice='accept'),
           dict(op='move',dx=0,dy=1),dict(op='move',dx=1,dy=0),dict(op='move',dx=1,dy=0),dict(op='move',dx=0,dy=-1),
           dict(op='interact',target='kiosk_counter'),dict(op='buy',shop='kiosk',item='tea'),
           dict(op='move',dx=0,dy=1),dict(op='move',dx=-1,dy=0),dict(op='interact',target='guide_npc'),dict(op='choose',choice='accept')]
    write(target/'tests/walkthrough.json',dict(steps=steps,expect=dict(completed=['welcome','tea_time'],money=10)))
    (target/'README.md').write_text(f'''# {game_id}

Run from the engine project directory:

```powershell
python tools/dev.py validate --game {game_id}
python tools/dev.py test --game {game_id}
python tools/dev.py play --game {game_id}
```

Mouse walkthrough: pick up the coins, talk to Haru, accept the first event, click the counter and buy tea, then talk to Haru again and accept. The first event advances time to evening. Cancelling a choice is safe.

Edit events/ and locales/ to write dialogue. Register new files in game.json sources. tests/walkthrough.json uses normal moves and interactions; update it as your map/story changes. No money, items or completion flags are injected by this route.

Assets are copied into this package, not linked to demo. The shared engine remains a dependency. This is a starter template, not a production-ready game or the S3 independent sample.
''',encoding='utf-8')
    return target/'game.json'
