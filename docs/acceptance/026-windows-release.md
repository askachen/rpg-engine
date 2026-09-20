# 第二十六批：S7-01／02

日期：2026-09-20。本批合併 Windows 可重現建置與正式產物測試；S7-03／04 尚未完成。沿用 numeric_lab／fog_harbor，沒有新增驗證遊戲。

## 交付

- `setup_windows.py`、工具鏈雜湊鎖、`dev.py release --version`、隔離匯入與 EXE／PCK／清單 ZIP。
- 正式版固定內容入口，排除測試工具，release 模板禁用開發入口；玩家不需要安裝編輯器。
- Windows 黑箱滑鼠驗收：中文路徑、一般使用者權限、兩個存檔槽、時間變更後還原、跨程序續玩；霧港正常劇情解鎖後播放 Theora，辨識不同解碼影格。
- 額外修正長文／選項捲動與新增解析度設定值；完整矩陣留 S7-03。
- 手動 GitHub Actions 重建驗證與 ZIP artifacts。

操作／限制見 [Windows 建置契約](../windows-release.md)。

## 測試

開發中相關測試 30 項通過。整批只跑一次完整回歸：

```powershell
python tools/dev.py check --game numeric_lab --timeout 600 --json
```

**221 passed in 229.58s**；CLI `ok: true`、236.795 秒。日誌：`test-results/run-d30e5e8ffd934609bb95ffa451c967a7/`。

其後重建比對發現主場景缺少穩定節點 ID，已固定 `unique_id=1`；補強真實編輯器（非僅 console 啟動器）SHA256，以及長文捲動測試。只追加執行 `python -m pytest tests/test_release.py -q`，**8 passed**，另重做兩包的匯出／產物驗證。完整回歸數量不冒稱包含後加的第 222 項。

最終兩包各以乾淨 staging 建置兩次，ZIP 完全一致（`test-results/s7-rebuild.json`）：

- numeric_lab：`builds/numeric_lab-0.7.0-a2cebb45da632a1a-windows.zip`。正式版黑箱：`test-results/windows-b05467c268b647a6972bc74d813c62b0/result.json`，`ok: true`。
- fog_harbor：`builds/fog_harbor-0.7.0-7b1f90b2200f7af6-windows.zip`。正式版黑箱：`test-results/windows-0cb00f8155014ec1b68df1bebd4ae9ad/result.json`，`ok: true`，14 個不同的 Theora 校準影格。

兩包以一般使用者 token 執行，安裝目錄內容前後雜湊一致；AVI 包含實際 UI／立繪／地圖／媒體。驗收機 GPU：NVIDIA GeForce RTX 5070、OpenGL 3.3 Compatibility。這不是效能基準，也未宣稱其他 DPI／低階硬體已驗證。

S7-01／02 已驗證、待使用者確認；S6 由繼續 S7 確認。S5-10／11 與 Live2D 暫緩狀態不變。

## 遠端乾淨環境

程式 commit `912b610d3b379f8ba042a2aa940cdc8d40a496f4`：

- [Engine verification](https://github.com/askachen/rpg-engine/actions/runs/35496882325)：static／rules／ui／media 全部成功，含後加的長文測試。
- [Windows release reproduction](https://github.com/askachen/rpg-engine/actions/runs/35496905927)：成功。從乾淨 runner 下載並驗證 console／實際編輯器／模板，兩包各匯出兩次且 ZIP 一致；可下載 `windows-release` artifact。

初次遠端下載被官方轉址服務以 403 拒絕；已加入官方鏡像及 Godot GitHub 發行檔備援，每個來源仍驗證相同 SHA256。以上成功結果來自修正後的重新執行，不沿用失敗結果。本段只記錄證據，文件更新 commit 使用 `[skip ci]` 避免重跑相同程式。
