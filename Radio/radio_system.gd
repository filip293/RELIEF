extends CanvasLayer

# RELIEF radio system: CSV-driven dialogue, radio SFX and chest-mounted 3D audio.
# Required nodes:
# RadioSystem (CanvasLayer)
# |- HUD (PanelContainer)
# |  `- VBoxContainer
# |     |- Header
# |     |- Speaker (Label)
# |     `- Subtitle (Label)
# |- Voice (AudioStreamPlayer)             # Ellis, unfiltered and non-positional
# `- HandheldSpeaker (Node3D)
#    |- IncomingVoice (AudioStreamPlayer3D)
#    |- RadioStart (AudioStreamPlayer3D)
#    |- RadioStatic (AudioStreamPlayer3D)
#    `- RadioEnd (AudioStreamPlayer3D)

const DIALOGUE_CSV: String = "res://Radio/radio_dialogue.csv"
const VOICE_DIRECTORY: String = "res://Radio/Voice Lines"

# Used for development only. Disable when story triggers are implemented.
@export var play_test_on_start: bool = true
@export var test_line_id: String = "S01_VOSS_000"

@onready var hud: PanelContainer = $HUD
@onready var speaker_label: Label = $HUD/VBoxContainer/Speaker
@onready var subtitle_label: Label = $HUD/VBoxContainer/Subtitle

@onready var ellis_voice: AudioStreamPlayer = $Voice
@onready var handheld_speaker: Node3D = $HandheldSpeaker
@onready var incoming_voice: AudioStreamPlayer3D = $HandheldSpeaker/IncomingVoice
@onready var radio_start: AudioStreamPlayer3D = $HandheldSpeaker/RadioStart
@onready var radio_static: AudioStreamPlayer3D = $HandheldSpeaker/RadioStatic
@onready var radio_end: AudioStreamPlayer3D = $HandheldSpeaker/RadioEnd

# Godot units are assumed to be metres in this project.
# The radio sits below the eyes, forward of the chest, and near the centre.
const CHEST_BELOW_CAMERA: float = 0.48
const CHEST_FORWARD: float = 0.18

var dialogue: Dictionary = {}
var message_queue: Array[Dictionary] = []
var is_transmitting: bool = false


func _ready() -> void:
	hud.hide()
	ellis_voice.finished.connect(_on_voice_finished)
	incoming_voice.finished.connect(_on_voice_finished)
	_load_dialogue_csv()

	if play_test_on_start:
		await get_tree().create_timer(3.0).timeout

		play_sequence([
		"S01_VOSS_001",
		"S01_ELLIS_001",
		"S01_VOSS_002",
		"S01_VOSS_003",
		"S01_ELLIS_002"
	])


func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	# Use horizontal facing only; the chest radio does not tilt with the head.
	var forward: Vector3 = -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	else:
		forward = Vector3.FORWARD

	handheld_speaker.global_position = (
		camera.global_position
		+ Vector3(0.0, -CHEST_BELOW_CAMERA, 0.0)
		+ forward * CHEST_FORWARD
	)


func _load_dialogue_csv() -> void:
	dialogue.clear()
	var file: FileAccess = FileAccess.open(DIALOGUE_CSV, FileAccess.READ)
	if file == null:
		push_error("Radio dialogue CSV cannot be opened: " + DIALOGUE_CSV)
		return

	# Columns: id,speaker,subtitle,audio_path,incoming
	var header: PackedStringArray = file.get_csv_line()
	if header.size() != 5 or header[0].strip_edges() != "id":
		push_error("Invalid radio dialogue CSV header. Expected: id,speaker,subtitle,audio_path,incoming")
		return

	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == 1 and row[0].strip_edges().is_empty():
			continue
		if row.size() != 5:
			push_warning("Skipping malformed radio CSV row (needs 5 columns).")
			continue

		var line_id: String = row[0].strip_edges()
		if line_id.is_empty():
			continue
		if dialogue.has(line_id):
			push_warning("Duplicate radio line ID: " + line_id)
			continue

		var incoming_text: String = row[4].strip_edges().to_lower()
		if incoming_text != "true" and incoming_text != "false":
			push_warning("Radio CSV needs true/false for line: " + line_id)
			continue

		dialogue[line_id] = {
			"speaker": row[1].strip_edges(),
			"subtitle": row[2],
			"audio_path": row[3].strip_edges(),
			"incoming": incoming_text == "true"
		}


# Call from any gameplay/story trigger: RadioSystem.play_line("S02_BRANDT_001")
func play_line(line_id: String) -> void:
	if not dialogue.has(line_id):
		push_warning("Unknown radio line ID: " + line_id)
		return

	var entry: Dictionary = dialogue[line_id]
	var audio_path: String = str(entry["audio_path"])

	# Most recordings only need to be named after their dialogue IDs.
	# Custom filenames may be supplied in the CSV's audio_path column.
	if audio_path.is_empty():
		audio_path = VOICE_DIRECTORY + "/" + line_id + ".mp3"

	if not ResourceLoader.exists(audio_path):
		push_warning("Recording not found for " + line_id + ": " + audio_path)
		return

	var recording: AudioStream = load(audio_path) as AudioStream
	if recording == null:
		push_warning("Not a usable audio stream for " + line_id + ": " + audio_path)
		return

	play_transmission(
		str(entry["speaker"]),
		str(entry["subtitle"]),
		recording,
		bool(entry["incoming"])
	)


# A sequence is queued in order. Missing recordings are skipped with a warning.
func play_sequence(line_ids: Array) -> void:
	for line_id in line_ids:
		play_line(str(line_id))


# Existing API remains available for any manually supplied AudioStream.
func play_transmission(
	speaker: String,
	subtitle: String,
	recording: AudioStream,
	incoming: bool = true
) -> void:
	if recording == null:
		push_warning("Radio transmission has no recording.")
		return

	message_queue.append({
		"speaker": speaker,
		"subtitle": subtitle,
		"recording": recording,
		"incoming": incoming
	})

	if not is_transmitting:
		_play_next()


func _play_next() -> void:
	if message_queue.is_empty():
		is_transmitting = false
		hud.hide()
		return

	is_transmitting = true
	var message: Dictionary = message_queue.pop_front()

	speaker_label.text = str(message["speaker"])
	subtitle_label.text = str(message["subtitle"])

	var recording: AudioStream = message["recording"] as AudioStream
	var is_incoming: bool = str(message["speaker"]).to_upper() != "ELLIS"

	if is_incoming:
		incoming_voice.stream = recording
	else:
		ellis_voice.stream = recording

	if not hud.visible:
		hud.modulate.a = 0.0
		hud.show()
		var tween: Tween = create_tween()
		tween.tween_property(hud, "modulate:a", 1.0, 0.15)

	_start_radio_audio(is_incoming)


func _start_radio_audio(is_incoming: bool) -> void:
	# Radio click. This MUST be a non-looping audio stream.
	if radio_start.stream != null:
		radio_start.play()
		await radio_start.finished

	# Quiet interference. This SHOULD loop until the voice finishes.
	if radio_static.stream != null:
		radio_static.play()

	if is_incoming:
		incoming_voice.play()
	else:
		ellis_voice.play()


func _on_voice_finished() -> void:
	radio_static.stop()

	# Closing click must also be non-looping.
	if radio_end.stream != null:
		radio_end.play()
		await radio_end.finished

	await get_tree().create_timer(0.8).timeout
	_play_next()
