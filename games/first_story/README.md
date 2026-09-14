# first_story

Run from the engine project directory:

```powershell
python tools/dev.py validate --game first_story
python tools/dev.py test --game first_story
python tools/dev.py play --game first_story
```

Mouse walkthrough: pick up the coins, talk to Haru, accept the first event, click the counter and buy tea, then talk to Haru again and accept. The first event advances time to evening. Cancelling a choice is safe.

Edit events/ and locales/ to write dialogue. Register new files in game.json sources. tests/walkthrough.json uses normal moves and interactions; update it as your map/story changes. No money, items or completion flags are injected by this route.

Assets are copied into this package, not linked to demo. The shared engine remains a dependency. This is a starter template, not a production-ready game or the S3 independent sample.
