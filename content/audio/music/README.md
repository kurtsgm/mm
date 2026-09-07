# 野外配樂：橡境行旅 / The Oakmarch Wayfarer

`oak_wild_bard.ogg` 是橡境野外探索用的原創程序化器樂曲，由
`tools/compose_oak_wild.py` 合成；沒有使用第三方錄音或取樣素材。

- D Dorian 調式、6/8 拍、附點四分音符 = 78 BPM，64 小節，約 98.46 秒。
- 魯特琴感雙弦撥奏、木笛主旋律、豎琴點綴、柔和弓弦與低音手鼓。
- 8 小節撥弦引子 → 16 小節主題 → 16 小節明亮副段 → 8 小節器樂間奏 → 16 小節裝飾變奏。
- 尾音與殘響回捲至曲首，OGG 匯入設定開啟原生循環，避免依靠 finished 訊號重播造成間隙。
- 44.1 kHz stereo / Vorbis；播放沿用 `oak_wild`，所有使用此 ID 的野外地圖自動套用。

重新編曲與輸出（需要 Python 3）：

```sh
python3 -m venv /tmp/mm-music-venv
/tmp/mm-music-venv/bin/pip install -r tools/requirements-music.txt
/tmp/mm-music-venv/bin/python tools/compose_oak_wild.py
godot --headless --path . --editor --import
```

修改 `MELODY_A` / `MELODY_B` 可改主旋律；`VERSE` / `BRIDGE` 控制和聲。
合成音色以聲部形象為設計目標，並非真人樂器錄音。
