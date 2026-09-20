# Live2D 技術驗證（S4-06，依使用者指示暫緩）

2026-09-19 使用者要求先跳過此項，繼續 S4-07；本項保留為暫緩。**引擎尚未支援 Live2D 播放**。本批完成離線準備檢查與驗收門檻；未完成真實模型、透明疊加、動作／表情或 Windows EXE 測試。不可用 audit 通過或合成測試檔宣稱已支援。

## 技術選擇

候選為 [GDCubism v0.9.1](https://github.com/MizunagiKB/gd_cubism/releases/tag/v0.9.1)，這是非官方 Godot GDExtension；[上游 README](https://github.com/MizunagiKB/gd_cubism/blob/v0.9.1/README.en.adoc) 標示適用 Godot 4.3 以上，仍需對本專案 4.7.2／Compatibility renderer 實測。不把「版本範圍符合」當成相容性驗證。

0.9 改為直接繪製；部分 API 網頁仍描述舊版 SubViewport，實作時以固定 tag 的原始碼與範例為準。Live2D 使用模型、貼圖、參數與動作，不是影片播放：影片工具不能代替 `.model3.json`／`.moc3` 執行環境。

## 所需檔案

1. Cubism SDK for Native：自行從 [官方下載頁](https://www.live2d.com/en/sdk/download/native/) 取得並解壓。官方要求閱讀及接受授權，下載流程另有下載者資料欄位。Cubism Editor 安裝程式不是 SDK。
2. GDCubism v0.9.1 原始碼及相符的 godot-cpp 子模組，或可信來源的已編譯 addon。原始碼建置另需 MSVC C++ 工具與 SCons；見 [上游建置說明](https://mizunagikb.github.io/gd_cubism/gd_cubism/0.9/en/build.html)。
3. 可供本機測試的匯出模型：`.model3.json`、`.moc3`、PNG 貼圖，以及至少一組 motion3 與 exp3。保留原資料夾結構；作者用的 cmo3／can3 不是執行時入口。
4. Godot 4.7.2 Windows debug／release 匯出模板。

依賴可放在忽略提交的 `.tools/live2d/`。模型與 SDK 不因技術驗證而自動成為 repo 可再散布素材；正式對外交付與授權整理仍依 S8 處理。

本機已檢查：Godot 可用；Visual Studio 2022 已安裝，但 vswhere 未找到具 `Microsoft.VisualStudio.Component.VC.Tools.x86.x64` 的完整安裝；尚未取得可用 SDK、模型與 addon 路徑；預設 Godot export_templates 目錄未找到可用模板。未修改 Visual Studio 或代替使用者填寫下載資料。

## 可重跑的準備檢查

```powershell
python tools/live2d_audit.py
python tools/live2d_audit.py --model .tools/live2d/model/character.model3.json --addon .tools/live2d/gd_cubism --sdk .tools/live2d/CubismSdkForNative --templates .tools/live2d/templates
```

此為獨立 CLI，輸出一份 JSON。退出碼 0 表示準備檢查通過；1 表示缺件／格式問題；2 是 argparse 用法錯誤。沒有下載、編譯、執行 DLL 或寫入使用者檔案的副作用。SDK 參數可省略，已編譯 addon 不需本機 SDK；模板與包含動作／表情的模型是本階段驗收必要項。

工具檢查：

- 模型入口 Version、MOC3 基本標頭、PNG 解碼與所有已知 FileReferences 引用。
- Physics／Pose／UserData／DisplayInfo JSON；motion／expression 基本結構、表情名稱重複；宣告的 motion Sound 存在。
- 拒絕絕對路徑、向上跨目錄及符號連結逃出模型目錄；產出檔案大小與 SHA-256 清單。
- addon descriptor 的 Windows debug／release 映射、DLL PE x64 標頭；匯出模板版本檔與 EXE PE x64 標頭。

限制：不解析完整 MOC3、曲線語意或音訊內容；不證明 DLL 完整、可信、版本為 0.9.1、可載入，亦不證明模板可匯出。未知新 FileReferences 欄位不列入清單；採用不同模型規格時需擴充檢查。`ok=true` 時 `runtime_verified` **仍為 false**，代表還需要下一道原生測試。

## 下一道原生驗收

| 門檻 | 成功證據 | 目前狀態 |
| --- | --- | --- |
| 原生載入 | 固定 addon／SDK 版本與 hash、實際 Core 載入及模型資訊 | 缺依賴，未執行 |
| 透明疊加 | 地圖／背景後方可見，模型非矩形黑底，實際渲染截圖 | 未執行 |
| 動作／表情 | 讀取模型實際 ID、切換後可觀察變化與正確錯誤診斷 | 未執行 |
| 顯示／隱藏／重入 | 滑鼠操作、取消、重入；釋放及無狀態獎勵副作用 | 未執行 |
| Windows EXE | debug/release 輸出，離開編輯器後再次載入與操作 | 未執行 |

先在隔離技術專案驗證 addon，成功後才接正式對話資料格式與生命週期。Live2D 模型檔需明確納入匯出，不能只依賴 Godot 靜態資源推斷；[上游使用說明](https://mizunagikb.github.io/gd_cubism/gd_cubism/0.9/en/usage.html) 也列出此限制。

若原生驗證失敗，記錄具體版本、重現路徑及日誌，再決定修復或請使用者作範圍決策；不能自行用影片替代 Live2D 並勾選完成。
