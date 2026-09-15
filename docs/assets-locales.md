# 素材與語系檢查契約

## 兩層驗證

`python tools/dev.py validate --game demo`：無需 Godot，使用 Pillow 驗證 PNG／JPEG／WebP 檔頭、完整像素讀取及副檔名一致性；使用 wave 驗證 PCM WAV 樣本資料是否完整、非空。檔案檢查以路徑、修改時間及長度快取，避免同一測試程序重複解碼原素材。

`check`／`play`：匯入 Godot 後再執行 asset_probe，確認 PNG／JPEG／WebP／SVG 可由 Image 讀取，WAV／OGG／MP3 為有正時長的 AudioStream，TTF／OTF／Font `.tres` 為 Font 資源。結果存於 JSON 報告 artifacts.asset_probe 所指向的 test-results/run-*/asset-probe.json；失敗不進入遊戲。

OGG／MP3 原生資源載入与時長檢查並不代表全片逐幀解碼或聽感驗收。字型型別檢查不等於字形覆蓋或授權驗證；這些仍需發行階段檢查。SVG 與字型原生支援由 Godot probe 確認，純 Python validate 不作完整解碼保證。

## 圖集

- opaque 索引及 regions 鍵必須在 columns × rows 範圍內。
- regions 使用每格相對座標 `[x, y, width, height]`；寬高為正，矩形不能超出 0–1。
- 每格至少 16 像素，以符合目前 alpha 邊界取樣方式。
- 不要求整張圖片尺寸整除格數：現有圖集可能有非整除尺寸，runtime 使用浮點格位。
- 背景／立繪只接受圖像格式，bgm／sfx 只接受目前音訊格式，避免把圖片路徑誤填到聲音欄位。

## 語系

default_language 是基準 catalog，所有語言需具有相同鍵集合。缺譯與只出現在非基準語言的鍵都視為驗證失敗，包括 UI 文字，而不僅是事件台詞。

runtime 遇到未知語言或缺少鍵時仍退回 default_language；這是執行時備援，不代表可交付缺譯。若基準也缺鍵則顯示鍵本身便於發現問題。

比較 printf 形式參數的順序與型別，例如 `%s`／`%d` 不能互换，`%02d` 與 `%d` 可接受。`%%` 不算參數。具名 `{name}` 參數比較名稱與出現次數，可調整語序。此檢查只比對 token，並不新增台詞變數替換功能，也不等於完整格式字串 parser。

## 未完成能力

影片及 Live2D 尚未納入可用資源類型。原生 probe 對未支援格式明確報錯；加入新的媒體支援時需一起更新播放器、Schema、驗證器與 probe。完整影音播放、字型覆蓋、語系長文布局、跨電腦一致性仍依 S4／S6 驗收。
