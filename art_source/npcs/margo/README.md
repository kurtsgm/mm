# 瑪歌全身立繪來源

`full-body-source.webp` 是內建 image_gen 依 `content/scenes/margo_portrait.webp` 生成的全身構圖，已依專案規範壓縮。

此檔的棋盤格是 RGB 像素，**不是透明背景，不可直接掛到遊戲**。正式透明素材放在 `content/npcs/margo/idle.webp`。

使用者已同意本機去背。以 [rembg](https://github.com/danielgatis/rembg) 2.0.84 的 `isnet-general-use` 模型提取 alpha，再清除 alpha ≤ 8 的淡色殘留，輸出 q85、保 alpha 的 WebP。人物內容由內建 image_gen 生成，本機步驟只處理背景。

可重建正式素材：

```sh
uv run art_source/npcs/margo/prepare.py
godot --headless --path . --import
```

腳本已固定 Python 依賴版本。首次執行會下載本機推論模型到 rembg 的使用者快取；模型與依賴不入庫。腳本會輸出尺寸、alpha 邊界、建議腳底比例與容量。

生成 prompt 與去背修正 prompt：[margo-prompts.json](../../../docs/npcs/margo-prompts.json)。完整規格與預覽方式：[margo-sample.md](../../../docs/npcs/margo-sample.md)。
