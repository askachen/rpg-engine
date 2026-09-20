# Windows 發行建置（S7-01／02）

支援 Windows x86_64、Godot 4.7.2 標準版。玩家解壓 ZIP 後執行 EXE，不需要 Godot 或 Python。EXE 與 PCK 必須放在同一個資料夾。

## 建置

在 repo 根目錄執行：

```powershell
python -m pip install -r requirements-dev.txt
python tools/setup_windows.py
python tools/dev.py release --game numeric_lab --version 0.7.0 --timeout 600 --json
```

第一次 setup 會從 Godot 官方下載站取得鎖定的編輯器與匯出模板（模板完整壓縮檔約 1.28 GB），只安裝 Windows 所需檔案到 `.tools/`。已安裝且雜湊一致時不會重新下載。也可用 `--templates-archive PATH` 提供已下載的官方 TPZ；仍會驗證整包與解壓執行檔的 SHA256。

`tools/windows-toolchain.json` 鎖定 console 啟動器、實際編輯器、release 模板及官方壓縮檔雜湊。`GODOT_BIN` 可以指定鎖定的 console exe；相鄰主執行檔也必須匹配。更新 Godot 時必須一起更新鎖檔並重做產物驗收。Python 依賴鎖在 `requirements-dev.txt`。

release 依序執行內容驗證、素材原生 probe、隔離專案匯入、正式版匯出、產物清單與 ZIP 打包。每次使用新的 staging/cache；不依賴 Godot 編輯器 UI 或使用者模板目錄。版本必填，格式為 `MAJOR.MINOR.PATCH[-suffix]`。失敗使用既有 CLI JSON／退出碼契約。

成功結果的 `artifacts.windows_bundle` 是 `builds/<game>-<version>-<digest>-windows.zip`。ZIP 內有 EXE、PCK、README 與 `release-manifest.json`：內容 ID、版本、工具鏈、所有來源檔案雜湊、EXE／PCK 雜湊。`config/version` 同步寫入遊戲專案；目前不修改 Windows PE 詳細資料、不簽署 EXE。

相同來源檔案位元組／版本／鎖定工具，乾淨重建應產生相同檔案位元組與 ZIP 路徑。主場景節點固定 `unique_id`，避免 Godot 匯出時隨機產生節點 ID。已有同名 ZIP 時比對內容，拒絕覆蓋不同資料。既有 `build` 指令仍產生**原始碼 ZIP**。

## 正式版界線

- 只打包所選遊戲的合併內容與宣告素材；不帶其他遊戲包、測試 runner、探索 runner、素材 probe 或 UI 測試腳本。
- `--game` 內容切換只在 editor 執行檔有效。正式 EXE 綁定包內內容。
- release 模板沒有開發功能；`--dev` 不會開放開發選單或指令。
- 存檔／設定寫到 `%APPDATA%/Godot/app_userdata/<game_id>/`，不寫安裝資料夾；保留遊戲 ID 前綴及既有存檔契約。
- ZIP 是未簽署的開發發行包。Steam 整合、商業授權／交付檢查不屬於本批。

## 產物驗收

```powershell
python tools/verify_windows.py builds/<release-file>-windows.zip
```

此黑箱工具僅支援既有 `numeric_lab`／`fog_harbor` 驗收包，需要可互動 Windows 桌面及一般使用者 token；管理員提升狀態會拒絕執行。它只操作自己啟動的遊戲視窗，透過 Windows 滑鼠訊息操作正常 UI，不載入編輯器、不注入玩法狀態。

流程：驗證清單雜湊 → 解壓到中文／空白路徑 → 新遊戲 → 多槽存檔 → 等待時段 → 讀檔還原 → 關閉 → 重啟繼續／重新存檔。比較真正存檔內容，檢查安裝目錄完全未被修改。霧港額外撿取名冊、完成瑪拉兩個事件、解鎖畫廊並播放原有 Theora 校準影片。

`test-results/windows-*/result.json` 保存結果；`new.log`／`restart.log` 與正式執行檔內建 Movie Maker 產生的 AVI 保存操作證據。影片檢查辨識至少兩個不同的實際彩條影格，不把「按過播放」當作成功。Movie Maker 使用固定時間步長，**錄影耗時與 FPS 不能用作效能測試**。校準素材不是正式劇情美術。

GitHub Actions 的 **Windows release reproduction** 為手動工作流程：乾淨 Windows runner 安裝鎖定工具，兩個包各建置兩次，比對 ZIP 路徑／內容，保存 ZIP 與建置日誌。遠端工作流程驗證建置；互動桌面的黑箱驗收由本機執行，兩者不互相取代。

## 後續驗收

本批另修正長對話／長選項可捲動，並加入 4K、16:10、21:9 設定選項。只完成雙語最大字體長文的相關測試，**不是完成 S7-03**。完整解析度／DPI／語系矩陣與 S7-04 大內容、資源生命週期、效能基準仍待下一批。
