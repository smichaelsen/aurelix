extends Node
##
## Headless coverage for the inventory panel:
##   - InventoryController.toggle opens/closes the panel
##   - Equipment + bag rows render from Inventory autoload state
##   - Use button on a heal item routes through HealService, consumes
##     one stack, and raises Kael's HP
##   - Use button disables when Kael is full
##

const VILLAGE_PATH := "res://scenes/village_square.tscn"

var _failures: Array[String] = []
var _last_heal_signal: Dictionary = {}


func _ready() -> void:
	add_child((load(VILLAGE_PATH) as PackedScene).instantiate())
	await _settle(3)

	EventBus.party_heal_applied.connect(_on_heal_applied)

	await _case_toggle_and_render()
	await _case_use_button_heals()
	await _case_use_button_disabled_when_full()

	_finish()


func _case_toggle_and_render() -> void:
	_assert(not InventoryController.is_open(), "panel starts closed")
	InventoryController.open()
	await _settle(2)
	_assert(InventoryController.is_open(), "toggle/open marks open=true")

	var panel: Node = InventoryController._panel
	_assert(panel != null, "panel scene instantiated")
	if panel == null:
		return

	var equipment: Node = panel.get_node("Panel/Left/Margin/Equipment")
	var bag: Node = panel.get_node("Panel/Right/Margin/Bag")
	_assert(equipment.get_child_count() > 0, "equipment column has rows")
	_assert(bag.get_child_count() > 0, "bag column has rows")

	# Bag should have a row per stack (starting kit: apple, ale).
	var bag_rows := bag.get_child_count()
	_assert(bag_rows >= 2, "bag rows >= 2 (got %d)" % bag_rows)

	InventoryController.close()
	await _settle(1)
	_assert(not InventoryController.is_open(), "close marks open=false")


func _case_use_button_heals() -> void:
	PartyHealth.reset_to_full()
	if not Inventory.has("apple"):
		Inventory.add("apple", 1)
	PartyHealth.set_kael_hp(PartyHealth.kael_max() - 5)
	var apples_before: int = Inventory.count_of("apple")
	var hp_before: int = PartyHealth.get_kael_hp()
	_last_heal_signal = {}

	InventoryController.open()
	await _settle(2)
	var apple_use_btn: Button = _find_use_button("apple")
	_assert(apple_use_btn != null, "apple row has a Use button")
	if apple_use_btn == null:
		InventoryController.close()
		return
	_assert(not apple_use_btn.disabled, "Use button enabled when not full")
	apple_use_btn.emit_signal("pressed")
	await _settle(2)

	_assert(PartyHealth.get_kael_hp() > hp_before,
		"HP rose after Use (was %d, now %d)" % [hp_before, PartyHealth.get_kael_hp()])
	_assert(Inventory.count_of("apple") == apples_before - 1,
		"Apple count -1 (was %d, now %d)" % [apples_before, Inventory.count_of("apple")])
	_assert(_last_heal_signal.get("item_id", "") == "apple",
		"party_heal_applied signal fired for apple (got '%s')" % _last_heal_signal.get("item_id", ""))
	_assert(int(_last_heal_signal.get("amount", 0)) > 0,
		"party_heal_applied amount > 0 (got %s)" % _last_heal_signal.get("amount"))

	InventoryController.close()
	await _settle(1)


func _case_use_button_disabled_when_full() -> void:
	PartyHealth.reset_to_full()
	if not Inventory.has("apple"):
		Inventory.add("apple", 1)
	InventoryController.open()
	await _settle(2)
	var apple_use_btn: Button = _find_use_button("apple")
	_assert(apple_use_btn != null, "apple row still present at full HP")
	if apple_use_btn != null:
		_assert(apple_use_btn.disabled, "Use disabled when Kael at full HP")
	InventoryController.close()
	await _settle(1)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _find_use_button(item_id: String) -> Button:
	var panel: Node = InventoryController._panel
	if panel == null:
		return null
	var bag: Node = panel.get_node("Panel/Right/Margin/Bag")
	for row in bag.get_children():
		# Row label is the first child; it carries the item name. The Use
		# button is the last child of rows that have one. Look up via the
		# pressed callback being bound to use_item(item_id).
		for child in row.get_children():
			if not (child is Button):
				continue
			# The button name is "Use" — match by the item id via the row's
			# first label text. Apple/Ale/etc. all map to ItemRegistry.name_of.
			var name_lbl: Label = row.get_child(0) as Label
			if name_lbl != null and name_lbl.text.begins_with(ItemRegistry.name_of(item_id)):
				return child as Button
	return null


func _on_heal_applied(who: String, item_id: String, amount: int, hp: int, max_hp: int) -> void:
	_last_heal_signal = {
		"who": who, "item_id": item_id, "amount": amount,
		"hp": hp, "max_hp": max_hp,
	}


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		printerr("[InventoryPanelTest] FAIL: ", msg)
	else:
		print("[InventoryPanelTest] ok: ", msg)


func _finish() -> void:
	if _failures.is_empty():
		print("[InventoryPanelTest] PASS")
		get_tree().quit(0)
	else:
		printerr("[InventoryPanelTest] %d failures" % _failures.size())
		get_tree().quit(1)
