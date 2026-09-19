# Runtime 模組與擴充契約

此為開發版 API，尚未承諾穩定 ABI 或任意版本相容。S1-04 建立責任邊界；S2 補正式內容契約，S7 補版本／升級政策。

| 模組 | 責任／依賴 |
| --- | --- |
| game_bootstrap | 入口選擇與 game_id／profile 命名，不匯入 UI |
| content_loader | 合併 Manifest 明列的 JSON 片段，提供載入錯誤，不實作遊戲規則 |
| core | 載入內容、規則、狀態、路線及單局存檔；依賴 bootstrap 與 content_loader，不依賴渲染與輸入 |
| save_slots | 包裝 core 的槽位查詢／存讀檔；由建構式取得 core |
| profile_store | profile 讀寫、欄位清理及暫存檔替換；不讀單局規則 |
| art_library | 圖像資源快取、圖集與等比例繪圖，不修改遊戲狀態 |
| presentation_theme | 主題、字型、標題構圖及 UI 元件工廠；注入內容與 art_library |
| world_renderer | 地圖／角色繪圖，僅讀取主畫面提供的資料，不執行 act |
| story_visual | 對話圖片分層與逐格動畫；使用 art_library，時鐘由 dialogue_player 控制，不改 core |
| dialogue_player | 演出與播放控制，透過宿主提交一次 choose，不自行發獎 |
| main | 組裝上述模組，輸入、選單與事件生命週期協調；保留實例供測試 |
| test_runner | JSON 操作橋接，呼叫正式 core，不重寫玩法 |

目前 renderer 與 dialogue 透過動態宿主介面工作，不載入 main.gd；這不等於完全無耦合。renderer 使用宿主的 core、art、appearance、ORIGIN、WORLD_SIZE、camera、motion、walking、avatar_time、hovered_target()、tile_size()、card_style()、t()。由獨立 world_surface 的 `_draw()` 呼叫 `world.draw(host, surface)`，繪圖命令送到 surface，父視窗裁切世界；HUD 留在 main。它不能寫入 core.state。

dialogue 的宿主契約為 core、profile、dialogue_log、language、appearance，以及 t／portrait／label／button／card_style／modal／close_modal／save_profile／execute。完成回呼 `execute(choose)` 會清理當前演出；完成後不要再操作已退出的節點。模組不匯入宿主腳本，避免載入依賴循環。

## 正式規則操作

一律呼叫 `core.act(command)`，回應是 `{ok: bool, message: String, ...}`；message 為穩定機器識別字，UI 另行翻譯。擴充時增加正反測試，不能讓 Python 實作另一份規則。

| op | 參數 | 成功回應 |
| --- | --- | --- |
| move | dx、dy，四方向一步 | moved |
| wait | 無 | time_advanced |
| interact | target 物件 ID、可選 item | map_changed／collected／activated／shop／event／smalltalk／inspected |
| buy | shop、item | purchased |
| choose | 目前節點 choice ID | cancelled／event_branch／event_completed |
| cancel_event | 無 | cancelled |

`event` 帶 event ID；`shop` 帶 shop ID。操作紀錄 `history` 保留命令、回應與前後狀態。存檔、載入及讀取資料不是 act 指令；由對應持久化介面負責。

| 失敗碼 | 含義 |
| --- | --- |
| event_busy | 演出中不能執行其他世界操作 |
| invalid_move／blocked | 非單步移動／碰撞 |
| too_far／unavailable／already_used | 不相鄰／條件未滿足／物件已使用 |
| unknown_target／unknown_offer／unknown_choice／unknown_operation | 未知 ID 或命令 |
| shop_unreachable／out_of_stock／insufficient_money | 商店不可達／缺貨／錢不足 |
| no_event／choice_locked | 沒有活動事件／選項條件未滿足 |
| effect_failed | 效果或再次條件檢查失敗，不能完成事件 |

查詢接口：checks(conditions)、satisfied(conditions)、route_progress(character)、current_ending()、path_to(Vector2i, interaction)。path_to 只規劃路徑，實際移動仍逐步 act。不得用直接寫 state 代替正常遊玩；具名 fixture 可以在專門的隔離測試中使用。

持久化：core.save_game(path)／load_game(path) 回傳 bool；read_save(path) 回傳有效資料或空字典且不改動當局。SaveSlots 的 save／load_slot／details／latest 管理 0 自動槽、1–6 手動槽。Profiles.read(path, language) 回傳整理後的 profile，write 回傳 bool；完整備份／版本復原仍屬 S5。

## 擴充位置

- 新角色、路線、主題、圖像：改內容資料，不改 renderer。
- 新條件／效果／互動規則：core、validator 及測試一起修改；Python 僅驗證與調度。
- 新媒體命令：dialogue_player／媒體模組及內容驗證；仍走同一完成流程。
- 新 UI 畫面：main 組裝與 theme 元件；禁止在元件繪圖時發獎。
- 字型、圖集與素材引用：art／theme，不向 core 引入圖形相依。

目前測試會檢查靜態 load／preload 腳本依賴無循環，並回歸正常滑鼠通關。動態宿主介面另由實際 UI 整合測試覆蓋，不把靜態依賴檢查當成完整架構證明。

actor_motion 僅保存呈現朝向及步態時間，從 main 的正式移動結果更新；world_renderer 依 image_spec 選取配置影格，不寫入 core.state。

動態地圖物件由 `core.map_objects()` 解析；不要直接以原始 maps.objects 當作當前位置。`item_required` 與 `world_blocked` 的失敗／還原規則見 [物件契約](world-objects.md)。

`core.event_view()` 提供目前對話節點，`event_candidates(character)` 提供唯讀觸發診斷。`clear_event()` 清理 active_event、active_node 及 pending_effects；宿主不得只把 active_event 設空而遺留分支交易。詳細見 [劇情契約](story-contract.md)。

`story_video.gd` 管理單句影片、比例、暫停及完成訊號；`dialogue_player` 清理播放器並推進句游標，不在媒體回呼提交玩法效果。`tools/video_tools.py` 負責離線轉檔及損壞診斷；Godot 執行時無 FFmpeg 相依。見 [影片契約](video.md)。

`player_settings.gd` 正規化 profile 設定並套用音訊 bus／視窗；profile_store 負責讀寫，main 組裝設定 UI。dialogue_player 讀取文字／自動偏好並將音訊送到 Music／SFX／Voice。詳見 [設定契約](settings.md)。

`gallery_view.gd` 僅顯示 profile 解鎖與媒體，不執行 core 命令。main 在沒有進行中事件、回到地圖時同步新增解鎖；詳見 [畫廊契約](gallery.md)。
