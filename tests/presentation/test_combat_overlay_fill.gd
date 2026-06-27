extends GutTest

# 回歸：combat UI 的全螢幕 overlay 元件（Control 掛在 CanvasLayer 下）必須撐滿 viewport。
# 曾因在 _ready（add_child 後）才 set_anchors_preset(FULL_RECT) → CanvasLayer 不重算子 Control
# 尺寸 → 元件停在 (0,0) 全塌左上、子元素全擠成一角。_fit_to_viewport 顯式撐滿修正之。

func _assert_fills(node, name: String) -> void:
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	layer.add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(node.size, get_viewport().get_visible_rect().size,
		"%s 應撐滿 viewport（防版面塌左上回歸）" % name)

func test_overlays_fill_viewport():
	await _assert_fills(CombatLog.new(), "CombatLog")
	await _assert_fills(CombatActionBar.new(), "CombatActionBar")
	await _assert_fills(EnemyPanel.new(), "EnemyPanel")
	await _assert_fills(CombatChoiceList.new(), "CombatChoiceList")
