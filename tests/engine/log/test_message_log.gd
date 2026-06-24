extends GutTest

func test_push_appends_and_emits_changed():
	var log := MessageLog.new()
	watch_signals(log)
	log.push("hello")
	assert_signal_emitted(log, "changed")
	assert_eq(log.size(), 1)
	assert_eq(log.recent(1), ["hello"])

func test_recent_returns_last_n_in_order():
	var log := MessageLog.new()
	log.push("a")
	log.push("b")
	log.push("c")
	assert_eq(log.recent(2), ["b", "c"])
	assert_eq(log.recent(10), ["a", "b", "c"])  # 不足則全部
	assert_eq(log.recent(0), [])

func test_caps_at_max_lines_dropping_oldest():
	var log := MessageLog.new()
	for i in MessageLog.MAX_LINES + 5:
		log.push("line %d" % i)
	assert_eq(log.size(), MessageLog.MAX_LINES)
	# 最舊的 5 行被丟掉 → 第一行應是 "line 5"
	assert_eq(log.recent(MessageLog.MAX_LINES)[0], "line 5")
	assert_eq(log.recent(1), ["line %d" % (MessageLog.MAX_LINES + 4)])
