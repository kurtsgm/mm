extends Node
# Autoload 單例 "GameState"：全域玩家狀態的家。M3 持有隊伍與訊息列。
# 故意不給 class_name，避免與 autoload 名稱衝突。序列化（存讀檔）屬 M5。

var party: Party
var message_log: MessageLog
var gold: int = 0

func _ready() -> void:
	if party == null:
		party = Party.create_default()
	if message_log == null:
		message_log = MessageLog.new()
