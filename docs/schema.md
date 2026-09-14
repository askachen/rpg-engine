# 內容 Schema v1

使用 JSON Schema Draft 2020-12，Python 驗證器為 jsonschema 4.23.0。所有 `$ref` 指向同檔 `$defs`，驗證不需要下載遠端 Schema。

| 檔案 | 對象 |
| --- | --- |
| schemas/manifest.schema.json | 含 sources 的 game.json：Manifest 格式版本、來源集合與路徑、已提供的 inline 內容 |
| schemas/game.schema.json | 合併後完整內容：角色、事件、條件、效果、選項、演出、地圖、道具、持久初始值、主題及素材引用結構 |

流程：解析 JSON 並拒絕同檔重複鍵 → Manifest 結構驗證 → 片段合併與跨檔重複檢查 → 完整遊戲 Schema → 既有引用／地圖／劇情依賴驗證。

單檔遊戲直接進入完整遊戲 Schema，不需要 format_version／sources。遊戲內容版本 version 必須是正整數；Manifest 格式僅接受 format_version=1。

## 欄位與擴充

物件欄位採明確列舉，拼字錯誤與尚未支援的欄位會被拒絕。例如在事件加入 time_costs 不會默默忽略。新增引擎命令時必須同時更新 Schema、語意驗證與正常／失敗測試。字典集合中的 ID 與翻譯键是動態鍵，不受固定欄位名稱限制。

條件與效果依 kind 區分資料型別；例如 completed 的 value 是布林值，money 數量是整數。布林值不當作整數使用。地圖寬高、圖集行列與材料 repeat 要大於零；事件耗時不得小於零。圖片引用可為舊版整數格位、sheet/index 或 path。

目前保留 floor_colors／wall_color 為 deprecated 相容欄位；新地圖應用圖集與材料配置，不以這些欄位作為新功能入口。

## 診斷

```text
.../events/a2.json#/a2/time_cost (game/events/a2/time_cost): schema: 'tomorrow' is not of type 'integer'
```

`#/...` 指向原始片段內的路徑；括號內是合併後的逻輯位置。來源對照存在 ContentDocument 屬性，不混入遊戲 JSON 或 Godot 狀態。在記憶體建立的普通 dict 沒有來源檔，仍會顯示 game/... 路徑。

結構錯誤會先返回，不繼續存取已知無效欄位；使用者修正後再執行即可看到下一層語意檢查。oneOf 型別分支錯誤可能定位在整個條件／效果物件；不是所有訊息都精確到單一 scalar。

## 驗證界線

Schema 不證明所有任務可達，也不證明圖片、音訊、影片可解碼或字型包含所有字。引用、碰撞及必要依賴循環仍由語意 validator 處理，素材／語系深化屬 S2-03。存檔檔案自身的 Schema 與遷移仍是 S5-01，initial 的結構規格不能代替存檔驗收。

Python CLI 會先驗證再啟動；直接從 Godot 編輯器／執行檔載入內容時，不會內嵌 Python jsonschema。發布前的強制驗證與打包流程屬 S6，不以本機編輯器能開啟表示內容有效。

## 安裝

```powershell
python -m pip install -r requirements-dev.txt
python tools/dev.py validate --game demo
```

本機受限環境也支援 `python -m pip install --target .tools/python_libs jsonschema==4.23.0`；該目錄不提交版本控制。沒有套件時驗證必須失敗，不能略過 Schema。
