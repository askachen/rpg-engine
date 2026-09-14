# 第五批驗收：正式結構 Schema

日期：2026-09-14。任務 S2-02；狀態：已於 2026-09-14 由使用者回覆「繼續吧」確認。

交付 schemas/manifest.schema.json、schemas/game.schema.json 與 tools/schema_check.py；使用 Draft 2020-12，檢查必要欄位、已實作欄位集合、型別、基本值域、條件／效果／演出結構與 Manifest 版本。

ContentDocument 保留非 JSON 來源對照，讓拆檔的結構錯誤指向原始檔案與 JSON 路徑。舊單檔內容與 theme_preview 仍相容。依賴已列入 requirements-dev.txt；本機安裝在 .tools/python_libs。

`python tools/dev.py check`：44 項測試通過，含原滑鼠通關、播放、存讀檔與內容合併。新增整數／布林區別、負耗時、錯誤型別、未知欄位、Manifest 拼字及拆檔來源診斷案例。Schema 本身也經 Draft202012Validator.check_schema 檢查。

這批沒有改變玩家畫面。Schema 是啟動前工具鏈驗證，不是所有任務都可完成的證明，也不取代素材解碼或存檔 Schema。原生 Godot loader 未內嵌完整 jsonschema，使用與限制見 docs/schema.md。

下一批：S2-03 素材與語系驗證，再完成 S2-04 新遊戲建立工具及 S2-05 CLI。
