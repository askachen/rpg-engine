# 霧港來信 / Letters from Fog Harbor

S3 的獨立重用示範：港口因濃霧停航，諾亞協助訊號員伊莉絲修復訊號台，並陪郵務員瑪拉整理未寄出的信。三張地圖、兩條 4／2 事件路線與一個共同結局；玩法、地圖、角色 ID 和故事重新撰寫，使用共用引擎與現有美術副本。

```powershell
python tools/dev.py play --game fog_harbor
python tools/dev.py test --game fog_harbor --json
python tools/dev.py test --game fog_harbor --scenario games/fog_harbor/tests/courier_first.json --json
python tools/dev.py build --game fog_harbor --json
```

## 滑鼠通關

1. 碼頭拾取維修津貼及郵袋，與瑪拉核對名冊。
2. 前往工坊，櫃台買修理包（15），開備援電源，取出舊訊號圖。
3. 返回碼頭並前往訊號台，和伊莉絲談話；按等待切到晚上。
4. 與伊莉絲修理電路，再談一次解讀訊號圖。解讀完成推進到深夜。
5. 點校準訊號鏡，再與伊莉絲交談，完成她的四個事件。
6. 返回碼頭，深夜與瑪拉完成最後一班郵船的準備。兩條線完成後出現共同結局提示。

若取消選項可再次交談。錯過時段可按等待繞回；修理包、名冊及圖只在對應事件完成時消耗。最終餘額 25，伊莉絲 stage 4／好感 40，瑪拉 stage 2／好感 20。結局目前是 HUD 文字，並非片尾演出。

另一條 courier_first 路線先拜訪伊莉絲，當晚先完成瑪拉，再於隔天晚上處理訊號台；驗證完成次序不固定，也不需要注入狀態或重置遊戲。

## 配置與驗證

- quay／workshop／signal：碼頭、工坊、訊號台，皆為 26×15 格；不同出口與家具配置，地毯不阻擋行走。
- iris 路線：inspect_signal → repair_relay → decode_chart → light_beacon。
- mara 路線：sort_letters → last_dispatch。
- 條件使用 stage、好感、已完成事件、道具、時段及旗標；玩家看到的條件與正式規則共用。
- 語系為 zh_TW／en；保留範本中的共通 UI 文字以及部分未引用翻譯，但所有故事演出均使用本包新文字。
- tests/ 內是已展開的逐格正常操作；每步由共用 Godot test_runner 驗證。tests/harbor_mouse.gd（repo 根目錄）另用 Viewport 滑鼠跑完整流程。
- 原始圖集與提示詞放在本包 assets/，沒有執行時 demo 路徑相依。人物圖片為共用佔位美術，不宣稱是新繪製的角色設定；正式授權與 SDK 整理仍屬 S7。

跨遊戲 profile／設定／存檔／已讀／畫廊交替測試已於 S3-03 通過，詳細方法見 docs/acceptance/010-isolation.md（repo 根目錄）。

主角諾亞已使用獨立四方向行走圖集，依滑鼠／鍵盤移動轉向，停止保留方向。NPC 保留舊素材；完整动画配置見 repo 的 docs/actor-animation.md。

## S4-02 互動示範

碼頭新增港口告示、鑰匙、舊置物櫃及條件式便條。瑪拉晚上會換位：未調查置物櫃時在碼頭，調查後在工坊；白天和深夜在郵務桌。此為可選探索，兩條原有結局路線不要求完成。詳細試玩與資料格式見 [物件契約](../../docs/world-objects.md)。

## S4-03 分支閒聊

調查置物櫃後可找瑪拉選擇工作／天氣話題，可取消或完成後再次交談。已符合主線條件時主線優先。這段閒聊不增加金錢或好感，只記錄選過的話題。

自動驗證：`python tools/dev.py test --game fog_harbor --scenario games/fog_harbor/tests/conversation.json --json`。規則與限制見 [劇情契約](../../docs/story-contract.md)。

## S4-04 圖片演出

瑪拉閒聊已加入新港口背景／風景 CG、四格表情素材、眨眼循環、左右位置與大小，以及收尾停格／隱藏。完整素材與操作契約見 [圖片演出](../../docs/story-visuals.md)。核心劇情條件和獎勵不受演出影響，原有 conversation JSON 路線可繼續驗證。
