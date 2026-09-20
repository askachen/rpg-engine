# 第二十四批：S5-05～09／S5-12B

日期：2026-09-20。狀態：已驗證，待使用者確認。

## 交付

- S5-05：巢狀 all／any、完整診斷樹、八層深度驗證；事件 action_tags、持久行動紀錄、累計與明確日／時段窗口，聯集去重。
- S5-06：NPC／完整事件物件可用 `!`；獨立 tracking、揭露策略及條件樹顯示。原 routes 順序仍生效，長標題自動換行。
- S5-07：unlimited、capacity、跨日補到上限，以及原子 stock add／set；讀檔不額外補貨，存檔庫存上限驗證。
- S5-08：畫廊卡片連結完整事件；使用獨立 core／profile／對話紀錄，跳過玩法門檻及效果。正式世界操作／存檔入口在回想期間停用，結束／取消／影片故障回到畫廊。
- S5-09：共用可配置日期 formatter；HUD、存檔摘要、條件提示顯示 Extra Day，內部仍為絕對日。
- S5-12B：沿用 numeric_lab，沒有再建一套驗證遊戲。普通操作驗證計數／日期兩條 OR 路線；完整滑鼠流程交錯存讀檔、商店、回想與 Extra Day。

正式 JSON/API 見 [P1 玩法契約](../p1-gameplay.md)。README、TASKS、階段計畫及架構文件已更新。

## 驗證證據

開發中只執行相關測試，整批執行一次完整回歸：

```powershell
python tools/dev.py check --game numeric_lab --json
```

結果 `ok: true`，**203 passed in 198.62s**，CLI 合計 205.991 秒。報告：`test-results/run-dd0a340910414146921de6640606824e/`，包含 import、asset probe、walkthrough、pytest 與 JUnit；這些產物由本機產生，不提交 Git。涵蓋既有內容與共用引擎回歸。

新增 `tests/test_p1.py`／`tests/p1_contract.gd`：空／過深群組、非法窗口、未知引用、庫存政策衝突、日期翻譯；普通工作與等待路線、條件樹、取消／去重／存讀檔、窗口邊界、90／91／92 日格式、無限購買、有限售罄、跨日補貨、效果回滾、回想隔離及毀損行動紀錄拒絕。

延伸現有 `tests/numeric_mouse.gd`，headless 納入 pytest，另外以 NVIDIA OpenGL 1920×1080 實跑，結果 `numeric_mouse_failures: []`：

- 滑鼠完成開場、能力訓練、工作、探索、物品課程，再完成非線性里程碑。
- 畫面顯示無限庫存與 Extra Day，存檔槽位採相同日期格式並能讀回。
- 畫廊完整回想可選正式遊戲中因金錢不足鎖住的分支；正常結束與取消皆返回畫廊。
- 比對回想前後 live state、profile、profile 檔與自動存檔原文，完全一致。
- 在隔離回想副本注入既有影片及故意不存在的影片，驗證跳過／取消／故障清理，不修改遊戲內容或正式狀態。
- 檢視 `test-results/p1-world.png`、`p1-replay.png`；長追蹤標題已修正換行，無橫向溢出。

GPU 測試使用全新 APPDATA，避免開發者的真實存檔／profile 介入。Godot 的憑證存放區提示為既有環境訊息；Missing video 警告是故意注入的負例，無 SCRIPT ERROR。

## 範圍邊界

Recent 由內容明確配置；兩天窗口／三天 Extra Day 是驗證內容，不替 Homestay 決定規則。行動紀錄完整保存，尚未加入壓縮；舊存檔未記錄的歷史不推算。補貨以持久絕對日作為日界游標，不另存重複的 last-restock 欄位。

本批完成引擎 P1 能力及合成內容驗證，沒有宣稱真實 Homestay 已匯入或首月可通關。S5-10／11 仍待決策，Live2D 仍暫緩；S6～S8 的可靠性、Windows 發行及正式團隊交付仍未完成。
