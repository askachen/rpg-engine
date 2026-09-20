# 事件分支、重複與提交契約

S4-03 延伸原有事件格式；舊事件不必改寫。正式規則由 StoryCore 執行，GUI 與 headless 使用同一組操作。

## 局部分支

事件原有的 sequence／choices 是入口。選項可用 `next` 指向同事件的 `nodes`：

```json
{
  "character":"mara", "title":"harbor_chat", "text":"harbor_chat_intro",
  "conditions":[], "repeatable":true, "priority":-10,
  "choices":[
    {"id":"work", "text":"harbor_chat_work", "next":"work",
     "effects":[{"kind":"flag", "id":"chat_work", "value":true}]},
    {"id":"later", "text":"later", "cancel":true}
  ],
  "nodes":{
    "work":{
      "sequence":[{"id":"reply", "speaker":"mara", "text":"harbor_chat_work_reply"}],
      "choices":[{"id":"accept", "text":"harbor_chat_thanks"}]
    }
  }
}
```

根節點沒有 sequence 時仍以事件 text 播放一行。分支節點省略 sequence 時直接顯示選項。每個節點需有非空 choices；選項可以繼續跳到另一節點，也可以省略 next 作為結尾。選項自己的 sequence 會先播放，再跳轉或完成。

分支限制在單一事件，圖必須無環且節點可從入口到達；Schema／語意驗證拒絕漏節點、循環、不可達節點、空節點 ID、同節點重複選項 ID、翻譯／媒體及條件引用錯誤。同一選項 ID 可以出現在不同節點；choose 只在目前節點尋找。

目前不提供腳本指令、跨事件 goto、迴圈或對話內任意存檔。各節點開始時建立新的演出；音訊在節點邊界停止，需要延續時請在新節點首句明列 bgm。逐格／影片等完整演出仍屬 S4-04 以後。

## 提交與取消

- `choose` 有 next 時回傳 `event_branch`，更新暫態 active_node，選項 effects 加入 pending_effects；單局 state 不變。
- 結尾選項完成演出後，按照「經過的分支選項 → 結尾選項 → 事件 effects」順序執行一次交易，成功才記錄完成、推進 time_cost、返回 `event_completed` 並自動存檔。
- 所有條件讀取已提交 state；中途暫存的旗標不會提前讓下一節點選項解鎖。不同路徑請使用 next，勿依賴尚未提交的旗標。
- 效果失敗時完整還原 state，保留目前節點與既有暫存效果，GUI 重新呈現目前節點，允許選擇另一選項或離開。重試不會再暫存上一條分支效果。
- 作者的 cancel 選項或通用 `{"op":"cancel_event"}` 都會捨棄暫存效果並返回 `cancelled`。cancel 選項不能同時帶 next、非空 effects 或 sequence。
- 玩家可隨時用「離開對話」取消，包括選項收尾尚未播完時。對話紀錄視窗先按返回即可操作；沒有可用選項時也能離開。
- 返回標題、新遊戲與正常讀檔會清理事件暫態。演出退出時立即停止音訊，忽略舊演出的後續提交。事件外的重複 choose 回傳 no_event，不會再次發獎。
- S4-02 的 world_blocked 保護仍有效：若結尾會讓玩家腳下出現阻擋，還原交易並直接退出事件，玩家可移開後重新開始。

已讀紀錄屬於 profile，取消不會把已讀文字改回未讀。分支事件的已讀 ID 另包含節點與選項範圍，避免不同分支的同名句子互相誤判。沒有 nodes 的舊事件保持原有已讀 ID。

## 重複與優先序

`repeatable` 預設 false。設 true 可在完成後再次觸發，但每次仍檢查事件 conditions。每一輪成功結尾都會執行 effects／time_cost；state.completed 保留唯一 ID，代表「至少完成一次」。目前沒有內建每日次數、冷卻或完成次數計數器。

重複事件必須是獨立支線，不能列入角色的線性 routes，驗證器會拒絕此組合。要限制重複條件，可使用既有旗標或其他 AND 條件；不要把每次獎勵與一次性獎勵混在同一事件。

同角色事件依 priority 由大到小排列；同分依事件 ID 升冪。排除一次性已完成、尚未輪到的路線事件、條件不足後，取第一個。沒有可用事件才顯示 smalltalk。高優先級的重複事件可能持續遮住其他事件，作者需自行安排條件及優先序。

`core.event_candidates(character, context={})` 回傳完整排序及每項的 id、priority、eligible、selected、reason、checks；NPC interact 回應也包含 candidates。有 target 条件時須提供實際互動上下文；日期／地點及非 NPC 入口見 [入口契約](event-entry.md)。reason 為：

| reason | 意義 |
| --- | --- |
| selected | 目前應觸發的事件 |
| lower_rank | 已符合條件，但順位低於另一可用事件；同分也以 ID 決定 |
| completed | 一次性事件已完成 |
| route_order | 尚未輪到此線性路線事件 |
| conditions | AND 條件不足，詳見 checks |

遊戲選單中的開發者狀態畫面會顯示每位角色的候選診斷。這是本階段提供的唯讀資訊；完整可控修改與 release 排除仍屬 S6-03。

## 霧港範例與測試

開新遊戲，拾取鑰匙、調查置物櫃，再找瑪拉，選工作或天氣話題。完成後可以再次交談並走另一分支。這段閒聊 priority=-10，既有主線為 0；若已取得收件名冊，會先觸發主線。

```powershell
python tools/dev.py play --game fog_harbor
python tools/dev.py test --game fog_harbor --scenario games/fog_harbor/tests/conversation.json --json
python -m pytest tests/test_story_contract.py -q
```

公開 conversation 路線以正常移動、拾取、使用物品、選項與取消操作，驗證兩條分支、重複完成及存讀檔。原生與滑鼠測試另驗證失敗還原、取消／中斷、優先序及重入。這些案例不等於對任意內容做完整狀態空間的可達性證明。
