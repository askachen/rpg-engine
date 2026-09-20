# 內容包 Manifest v1

`game.json` 可保留單檔格式，也可使用 sources 指定其他檔案。不是自動掃描目錄，增加檔案後必須登記，刪除檔案也需移除其來源項目。

```json
{
  "id": "my_game",
  "version": 1,
  "format_version": 1,
  "sources": {
    "events": ["events/meeting.json", "events/promise.json"],
    "maps": ["maps/home.json"],
    "locales": ["locales/zh_TW.json", "locales/en.json"]
  }
}
```

上面只是片段，其他必要欄位如 initial、角色、素材等仍需提供。`format_version` 是 Manifest 格式版本，目前僅接受 1；`version` 是遊戲內容版本，與存檔格式版本不同。拆檔不需要改動事件 ID 或現有存檔。

events/meeting.json 內容為該 collection 的鍵值片段：

```json
{
  "meeting": {
    "character": "ivy",
    "title": "meeting_title",
    "text": "meeting_line",
    "conditions": [],
    "choices": [{"id": "accept", "text": "accept"}]
  }
}
```

翻譯檔採 `{"zh_TW":{"meeting_title":"初次見面"}}`，每種語言一份 catalog。現階段沒有巢狀字典自動合併；兩個檔案同時定義 zh_TW 會視為重複 ID。

可拆分集合：maps、characters、events、items、shops、routes、endings、gallery、locales、avatars、visuals。Manifest 自己也可保留同一 collection 的其他項目，但不能重複同一鍵。initial／presentation 等非集合欄位目前保留在 Manifest。

來源按清單順序讀取，同一集合遇到重複 ID 直接失敗，列出第二來源與原來源；不允許默默覆寫。片段只是一層鍵值物件，不是另一份遞迴 Manifest。原始 sources／format_version 在合併後移除，Python 工具與 Godot runtime 得到同一份玩法資料。

來源路徑相對於 game.json 所在目錄，使用 `/`；不接受絕對路徑、`..`、反斜線或磁碟代號。素材 `res://...` 路徑仍相對 Godot 專案，不隨片段目錄改變。不要以符號連結作為來源檔案。

## 操作

```powershell
python tools/dev.py list
python tools/dev.py play --game demo
python tools/dev.py play --game theme_preview
python tools/dev.py validate --game games/demo/game.json
python tools/dev.py check --game demo
```

`--game` 接受 games/ 下的資料夾名稱或 JSON 檔案路徑；省略時為 demo。play 在啟動前驗證與匯入資源。list／validate 不需要 Godot。未知內容路徑退出 2，內容驗證失敗退出 1，成功退出 0。

check 的範圍是「選定內容靜態驗證＋Godot 載入＋共用引擎／demo 回歸」，不會替任意遊戲自動建立通關路線。new、test 的 --scenario、統一 --json 診斷與 Godot 原始專案 build 已加入；協定見 [CLI 說明](cli.md)。Windows exe 匯出驗收仍在 S7。editor 可以接收入口參數，但不會永久改寫 project.godot 預設；要確保測試選定遊戲請使用 play。

## 目前限制

- Draft 2020-12 Schema 已加入，結構錯誤可定位到來源檔案及欄位；既有語意 validator 的引用／玩法錯誤主要輸出 ID，素材與語系診斷仍持續擴充。
- Python 驗證會拒絕同檔重複 JSON 鍵。Godot 原生 JSON parser 不提供此診斷，所以正式內容應經 CLI 驗證後使用；跨檔重複 ID 由兩邊都檢查。
- theme_preview 為配置預覽，共用 demo 美術及測試字型，非獨立可發行內容包。
- Windows 匯出時所有來源 JSON 都要打包；該發行驗收在 S7，不能以本機 FileAccess 載入成功代替。
