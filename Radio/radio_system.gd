
extends CanvasLayer

@onready var hud: PanelContainer = $HUD
@onready var speaker_label: Label = $HUD/VBoxContainer/Speaker
@onready var subtitle_label: Label = $HUD/VBoxContainer/Subtitle
@onready var voice: AudioStreamPlayer = $Voice

var message_queue: Array[Dictionary] = []
var is_transmitting: bool = false


func _ready() -> void:
	# Save the recording assigned in the Voice Inspector.
	var test_recording: AudioStream = voice.stream

	hud.hide()
	voice.finished.connect(_on_voice_finished)

	await get_tree().create_timer(3.0).timeout

	if test_recording == null:
		push_error("No recording assigned to the Voice node!")
		return

	play_transmission(
		"VOSS",
		"Ellis, this is Voss. Report back to Control when you're finished.",
		test_recording
	)


func play_transmission(
	speaker: String,
	subtitle: String,
	recording: AudioStream
) -> void:

	if recording == null:
		push_warning("Radio transmission has no recording.")
		return

	message_queue.append({
		"speaker": speaker,
		"subtitle": subtitle,
		"recording": recording
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

	voice.stream = message["recording"] as AudioStream

	if not hud.visible:
		hud.modulate.a = 0.0
		hud.show()

		var tween = create_tween()
		tween.tween_property(hud, "modulate:a", 1.0, 0.15)

	voice.play()


func _on_voice_finished() -> void:
	await get_tree().create_timer(3.0).timeout
	_play_next()
