extends GutTest

func _caster(spells: Array) -> Character:
	var c := Character.new()
	c.name = "梅"
	c.char_class = "Cleric"
	c.known_spells.assign(spells)
	return c

func test_rows_resolve_known_spells_and_field_flag():
	var rows := CharacterSpellsTab.rows(_caster(["heal", "spark"]))
	assert_eq(rows.size(), 2)
	assert_eq(String(rows[0]["spell"].id), "heal")
	assert_true(rows[0]["field"], "heal 為野外可用")
	assert_false(rows[1]["field"], "spark 為戰鬥限定")

func test_rows_skip_unknown_ids():
	var rows := CharacterSpellsTab.rows(_caster(["heal", "not_a_spell"]))
	assert_eq(rows.size(), 1, "未知 id 略過")

func test_lines_show_sp_and_combat_only_tag():
	var rows := CharacterSpellsTab.rows(_caster(["heal", "spark"]))
	var text := "\n".join(CharacterSpellsTab.lines(rows, 0))
	assert_true(text.contains("SP"), "顯示 SP 消耗")
	assert_true(text.contains("戰鬥中可用"), "spark 標戰鬥限定")
	assert_true(text.contains("> "), "有游標標記")

func test_lines_empty_when_no_spells():
	var text := "\n".join(CharacterSpellsTab.lines(CharacterSpellsTab.rows(_caster([])), 0))
	assert_true(text.contains("未習得"), "無法術時提示")
