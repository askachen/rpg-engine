# 第二十五批：S6-01～06

日期：2026-09-20。狀態：已實作，本機及遠端 CI 已驗證，待使用者確認。

## 交付

| 任務 | 證據 |
| --- | --- |
| S6-01 | save.schema.json／save_contract；v1→v2、內容數值 ID 改名、缺少遷移／未來版本／巢狀損壞拒絕；不修改現局 |
| S6-02 | atomic_save／槽位備份、明確復原與刪除確認；中斷暫存、寫入開啟失敗、備份寫入失敗保持主檔 |
| S6-03 | 物件上下文候選、內容來源、事件／節點／步驟與 state diff；--dev 白名單指令、持久 [DEV]、release 封鎖 |
| S6-04 | demo／numeric_lab 共四條普通操作情境，含角色順序、取消、錯過時段、道具與金錢競爭、存讀檔；失敗重播 |
| S6-05 | 原生規則 BFS、必要素材 probe、步數／狀態／時間上限；witness／未定明確區分，不保證所有玩法 |
| S6-06 | static／rules／ui／media、fast／full；乾淨 Windows CI 四層 job、失敗日誌／JUnit／素材保存；缺工具報錯 |

API、版本政策與限制見 [可靠性契約](../reliability.md)。沒有新增驗證遊戲，沿用現有兩包與隔離故障 fixture。

## 本機驗證

整批只執行一次完整回歸：

```powershell
python tools/dev.py check --game numeric_lab --timeout 600 --json
```

`ok: true`，**214 passed in 229.50s**，CLI 236.982 秒。產物在 `test-results/run-4beaf30774d24c588d189583e990153e/`，包含匯入／素材 probe、pytest、JUnit。

最後審查補強舊格式 metadata 驗證、復原暫存重讀驗證，以及探索輸出可直接交給公開 test 指令重播；只補跑相關測試：

```powershell
python -m pytest tests/test_reliability.py tests/test_cli.py::test_cli_invalid_scenario_and_failed_expectation -q
```

**12 passed in 38.75s**。沒有再次完整迴歸。

`scenarios --game numeric_lab` 與 `scenarios --game demo` 各兩條情境通過，普通操作包含資源競爭後恢復進度；預期失敗使用 expect_result，沒有注入狀態製造成功。

`tests/reliability_mouse.gd` 另外在 NVIDIA OpenGL 1920×1080 實跑，`reliability_mouse_failures: []`；故意破壞主檔後，由滑鼠完成備份復原／載入、取消刪除、確認刪除及摘要更新。畫面 `test-results/s6-recovery.png` 已檢视。測試使用全新 APPDATA，不碰手動試玩存檔。

Godot 4.7.2 的官方 GitHub release tag 已透過 GitHub API 確認可取得；CI 另驗證下載後的版本。工作流程成功與否以遠端 Actions 為準，本機測試不冒充遠端執行。

## 尚未宣稱完成的事

- 可達性只在工具操作模型與指定上限內探索，witness 只證明一條路線；不保證所有選项、不保證任意外掛、也不代替 Homestay 實際內容驗收。
- 存檔遷移支援明列版本链與有限 ID 改名，沒有任意腳本遷移；profile 尚無新增復原 UI；檔案備份不保證抵抗所有硬體／斷電故障。
- release 封鎖已測試 API／editor 模擬，真正匯出的 Windows release 與解析度／效能矩陣仍屬 S7。
- S5-10／11、Live2D 與 S8 正式交付仍依各自任務狀態處理。

## 遠端 CI 驗收

程式碼 commit `5798eed2f01db44f3eb6c571ee1a483f90ef6571` 的 [GitHub Actions 執行 35494489836](https://github.com/askachen/rpg-engine/actions/runs/35494489836) 為 success；static、rules、ui、media 四個乾淨 Windows job 全部成功。首次執行在 setup-python 的快取檔名檢查失敗，已明確指定 requirements-dev.txt 後重驗通過。後續本次純文件紀錄提交不改程式碼，不重跑同一套測試。
