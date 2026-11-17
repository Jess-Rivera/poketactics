class_name TurnBar
extends CanvasLayer
## The turn bar on the right edge (issue #8, docs/discussion-outputs/turn-order-plan.md): the active unit at the
## bottom and larger, the turns after it stacked above, leaning so the top sits closer to the screen edge. A thin
## divider with the round number marks where a new round starts. Each entry is the unit's Normal portrait (#16),
## whole in the active entry and a centred crop in the others, never scaled, in a frame of its side's colour, with
## an HP sliver. Hovering an entry or clicking it is announced by signal. Since #13 (strike rank) each entry shows
## the SR of that turn in its corner, and a faded copy of the active unit previews where the action being chosen
## would put its next turn.

signal unit_hovered(unit: BattleUnit)
signal unit_clicked(unit: BattleUnit)

const SCREEN_SIZE := Vector2(640, 360)
const ENTRY_COUNT := 8
## Sized so the inside of the frame is the whole 40x40 portrait (active) or a 30x30 crop of it (the others).
const ACTIVE_ENTRY_SIZE := 44.0
const ENTRY_SIZE := 32.0
const ENTRY_GAP := 3.0
## Extra room between two rounds, enough for the round label.
const ROUND_DIVIDER_GAP := 13.0
const ROUND_LABEL_WIDTH := 48.0
const RIGHT_MARGIN := 8.0
const BOTTOM_MARGIN := 10.0
## How far each entry leans toward the edge per pixel it sits above the bar's bottom.
const LEAN_PER_PIXEL := 0.08
const ACTIVE_BORDER_WIDTH := 2
const BORDER_WIDTH := 1
const ENTRY_BACKGROUND := Color(0.0, 0.0, 0.0, 0.6)
const SIDE_COLOURS := {Battle.Side.PLAYER: Color(0.35, 0.6, 1.0), Battle.Side.ENEMY: Color(1.0, 0.35, 0.35)}
const HIT_POINTS_COLOUR := Color(0.4, 0.9, 0.4)
const HIT_POINTS_HEIGHT := 2.0
const DIVIDER_COLOUR := Color(1.0, 1.0, 1.0, 0.5)
## The landing preview is drawn this opaque.
const LANDING_OPACITY := 0.45
const STRIKE_RANK_FONT_SIZE := 8
const STRIKE_RANK_OUTLINE := 3

var _pack: PackData
var _portraits_by_unit := {}


func _init() -> void:
	layer = 2


func set_pack(pack: PackData) -> void:
	_pack = pack


## Where each entry goes on screen, bottom (index 0, the active unit) first. slot_rounds holds each slot's round
## number; a divider gap goes in wherever the round changes.
static func entry_rects(slot_rounds: Array) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var bar_bottom := SCREEN_SIZE.y - BOTTOM_MARGIN
	var next_bottom := bar_bottom
	var widest_lean := 0.0
	for index in slot_rounds.size():
		if index > 0:
			next_bottom -= ENTRY_GAP
			if slot_rounds[index] != slot_rounds[index - 1]:
				next_bottom -= ROUND_DIVIDER_GAP
		var size := ACTIVE_ENTRY_SIZE if index == 0 else ENTRY_SIZE
		rects.append(Rect2(0.0, next_bottom - size, size, size))
		next_bottom -= size
	if not rects.is_empty():
		var top_rect: Rect2 = rects.back()
		widest_lean = (bar_bottom - top_rect.get_center().y) * LEAN_PER_PIXEL
	var leftmost_right_edge := SCREEN_SIZE.x - RIGHT_MARGIN - widest_lean
	for index in rects.size():
		var rect := rects[index]
		var lean := (bar_bottom - rect.get_center().y) * LEAN_PER_PIXEL
		# Whole pixels, so the frames stay crisp.
		rect.position.x = roundf(leftmost_right_edge + lean - rect.size.x)
		rects[index] = rect
	return rects


## Redraws the bar from a TurnOrder forecast (an Array of TurnOrder.Slot, the active unit first).
func show_forecast(slots: Array) -> void:
	for child in get_children():
		child.queue_free()
	unit_hovered.emit(null)
	var slot_rounds := []
	for slot in slots:
		slot_rounds.append(slot.round_number)
	var rects := entry_rects(slot_rounds)
	for index in slots.size():
		var slot: TurnOrder.Slot = slots[index]
		var entry := _entry(slot.unit, rects[index], index == 0)
		entry.add_child(_strike_rank_label(slot.strike_rank))
		if slot.is_landing:
			entry.modulate.a = LANDING_OPACITY
		add_child(entry)
		if index > 0 and slot.round_number != slots[index - 1].round_number:
			_add_divider(rects[index], slot.round_number)


func _entry(unit: BattleUnit, rect: Rect2, is_active: bool) -> Panel:
	var border_width := ACTIVE_BORDER_WIDTH if is_active else BORDER_WIDTH
	var entry := Panel.new()
	entry.position = rect.position
	entry.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = ENTRY_BACKGROUND
	style.border_color = SIDE_COLOURS.get(unit.side, Color.WHITE)
	style.set_border_width_all(border_width)
	entry.add_theme_stylebox_override("panel", style)
	entry.mouse_entered.connect(func() -> void: unit_hovered.emit(unit))
	entry.mouse_exited.connect(func() -> void: unit_hovered.emit(null))
	entry.gui_input.connect(_on_entry_input.bind(unit))

	var inner_size := rect.size - Vector2.ONE * border_width * 2
	var portrait := _portrait(unit, inner_size)
	if portrait != null:
		var picture := TextureRect.new()
		picture.texture = portrait
		picture.position = Vector2.ONE * border_width
		picture.size = inner_size
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(picture)

	if unit.max_hit_points > 0:
		var hit_points_bar := ColorRect.new()
		hit_points_bar.color = HIT_POINTS_COLOUR
		var share := clampf(float(unit.hit_points) / unit.max_hit_points, 0.0, 1.0)
		hit_points_bar.position = Vector2(border_width, rect.size.y - border_width - HIT_POINTS_HEIGHT)
		hit_points_bar.size = Vector2(roundf(inner_size.x * share), HIT_POINTS_HEIGHT)
		hit_points_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(hit_points_bar)
	return entry


## The turn's SR within its round, in the entry's top left corner.
func _strike_rank_label(strike_rank: int) -> Label:
	var label := Label.new()
	label.text = str(strike_rank)
	label.add_theme_font_size_override("font_size", STRIKE_RANK_FONT_SIZE)
	label.add_theme_constant_override("outline_size", STRIKE_RANK_OUTLINE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.position = Vector2(2, -2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _on_entry_input(event: InputEvent, unit: BattleUnit) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		unit_clicked.emit(unit)
		get_viewport().set_input_as_handled()


## A line just below the first entry of a new round, with the round number under it, right-aligned so it
## never runs off the screen edge.
func _add_divider(first_entry_of_round: Rect2, new_round_number: int) -> void:
	var line := ColorRect.new()
	line.color = DIVIDER_COLOUR
	line.position = Vector2(first_entry_of_round.position.x, first_entry_of_round.end.y + 2.0)
	line.size = Vector2(first_entry_of_round.size.x, 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	var label := Label.new()
	label.text = "Round %d" % new_round_number
	label.add_theme_font_size_override("font_size", UnitPanel.FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.size = Vector2(ROUND_LABEL_WIDTH, ROUND_DIVIDER_GAP)
	label.position = Vector2(first_entry_of_round.end.x - ROUND_LABEL_WIDTH, line.position.y - 1.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


## The unit's Normal portrait cut to the entry's inner size, one portrait pixel per screen pixel (stays crisp).
func _portrait(unit: BattleUnit, inner_size: Vector2) -> AtlasTexture:
	var full_portrait: AtlasTexture = _portraits_by_unit.get(unit)
	if full_portrait == null:
		if _pack == null:
			return null
		var pack_unit := _pack.unit(unit.unit_name)
		full_portrait = PortraitLoader.portrait(PortraitLoader.set_id_for(pack_unit, int(pack_unit["dex_number"])))
		_portraits_by_unit[unit] = full_portrait
	return PortraitLoader.cropped(full_portrait, inner_size)
