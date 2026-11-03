extends CanvasLayer

@export var fade_in_time: float = 0.16
@export var fade_out_time: float = 0.12

@onready var vignette: ColorRect = $Vignette
@onready var center_fade: ColorRect = $CenterFade
@onready var inventory_panel: PanelContainer = $Panel
@onready var inventory_list: Label = $Panel/MarginContainer/InventoryList
@onready var pickup_message: Label = $PickupMessage

var notification_tween: Tween
var inventory_tween: Tween
var inventory_open: bool = false


func _ready() -> void:
	vignette.hide()
	inventory_panel.hide()
	pickup_message.hide()
	center_fade.hide()
	center_fade.modulate.a = 0.0
	center_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

	vignette.modulate.a = 0.0
	inventory_panel.modulate.a = 0.0

	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Panel/MarginContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pickup_message.mouse_filter = Control.MOUSE_FILTER_IGNORE

	Globals.inventory_changed.connect(update_inventory)
	Globals.item_acquired.connect(show_pickup_notification)

	update_inventory()


func _process(_delta: float) -> void:
	var holding_tab: bool = Input.is_action_pressed("inventory")

	if holding_tab != inventory_open:
		inventory_open = holding_tab
		set_inventory_visible(holding_tab)


func set_inventory_visible(show_inventory: bool) -> void:
	if inventory_tween and inventory_tween.is_running():
		inventory_tween.kill()

	vignette.show()
	center_fade.show()
	inventory_panel.show()

	var target_alpha: float = 1.0 if show_inventory else 0.0
	var duration: float = fade_in_time if show_inventory else fade_out_time

	inventory_tween = create_tween()

	inventory_tween.tween_property(
		vignette,
		"modulate:a",
		target_alpha,
		duration
	)

	inventory_tween.parallel().tween_property(
		center_fade,
		"modulate:a",
		target_alpha,
		duration
	)

	inventory_tween.parallel().tween_property(
		inventory_panel,
		"modulate:a",
		target_alpha,
		duration
	)

	if not show_inventory:
		inventory_tween.tween_callback(hide_inventory)

func hide_inventory() -> void:
	vignette.hide()
	center_fade.hide()
	inventory_panel.hide()


func update_inventory() -> void:
	var equipment: Array[String] = []
	var keycards: Array[String] = []
	var other_items: Array[String] = []

	for item in Globals.get_items():
		var item_name: String = str(item.get("name", "Unknown"))
		var category: String = str(item.get("category", "Other"))

		match category:
			"Equipment":
				equipment.append(item_name)

			"Keycard":
				keycards.append(item_name)

			_:
				other_items.append(item_name)

	var lines: PackedStringArray = []

	lines.append("PERSONAL EFFECTS")
	lines.append("")

	if not equipment.is_empty():
		lines.append("EQUIPMENT")

		for item_name in equipment:
			lines.append(item_name)

		lines.append("")

	if not keycards.is_empty():
		lines.append("KEYCARDS")

		for item_name in keycards:
			lines.append(item_name)

		lines.append("")

	if not other_items.is_empty():
		lines.append("OTHER ITEMS")

		for item_name in other_items:
			lines.append(item_name)

		lines.append("")

	if equipment.is_empty() and keycards.is_empty() and other_items.is_empty():
		lines.append("No items")

	inventory_list.text = "\n".join(lines)


func show_pickup_notification(item_name: String) -> void:
	if notification_tween and notification_tween.is_running():
		notification_tween.kill()

	pickup_message.text = item_name.to_upper() + " ACQUIRED"
	pickup_message.modulate.a = 1.0
	pickup_message.show()

	notification_tween = create_tween()

	notification_tween.tween_interval(2.0)

	notification_tween.tween_property(
		pickup_message,
		"modulate:a",
		0.0,
		0.5
	)

	notification_tween.tween_callback(pickup_message.hide)
