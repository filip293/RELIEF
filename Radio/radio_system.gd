extends CanvasLayer


# ==========================================
# RADIO UI
# ==========================================

@onready var hud: PanelContainer = $HUD
@onready var speaker_label: Label = $HUD/VBoxContainer/Speaker
@onready var subtitle_label: Label = $HUD/VBoxContainer/Subtitle


# ==========================================
# AUDIO PLAYERS
# ==========================================

# Ellis's own voice (non-positional).
@onready var voice: AudioStreamPlayer = $Voice

# Physical walkie-talkie speaker.
@onready var handheld_speaker: Node3D = $HandheldSpeaker

# Incoming radio transmissions.
@onready var incoming_voice: AudioStreamPlayer3D = \
	$HandheldSpeaker/IncomingVoice

# Radio sound effects.
@onready var radio_start: AudioStreamPlayer3D = \
	$HandheldSpeaker/RadioStart

@onready var radio_static: AudioStreamPlayer3D = \
	$HandheldSpeaker/RadioStatic

@onready var radio_end: AudioStreamPlayer3D = \
	$HandheldSpeaker/RadioEnd


# ==========================================
# RADIO SETTINGS
# ==========================================

# Temporary test for Voss's first transmission.
@export var play_test_on_start: bool = true

# Assumes approximately 1 Godot unit = 1 metre.
const RADIO_CHEST_OFFSET: Vector3 = Vector3(
	0.0,
	-0.55,
	0.0
)

const RADIO_FORWARD_DISTANCE: float = 0.18


# ==========================================
# MESSAGE QUEUE
# ==========================================

var message_queue: Array[Dictionary] = []

var is_transmitting: bool = false


# ==========================================
# INITIALIZATION
# ==========================================

func _ready() -> void:

	hud.hide()

	# Both kinds of voice playback use the same
	# transmission completion function.
	voice.finished.connect(_on_voice_finished)
	incoming_voice.finished.connect(_on_voice_finished)

	# Capture Voss's recording from the Inspector.
	var test_recording: AudioStream = incoming_voice.stream

	# Temporary test.
	if play_test_on_start:

		await get_tree().create_timer(3.0).timeout

		if test_recording != null:

			play_transmission(
				"VOSS",
				"Ellis, this is Voss. Report back to Control when you're finished.",
				test_recording,
				true
			)

		else:

			push_warning(
				"No Voss recording assigned to IncomingVoice!"
			)


# ==========================================
# POSITION THE RADIO ON ELLIS'S CHEST
# ==========================================

func _process(_delta: float) -> void:

	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera == null:
		return

	# Obtain the direction the camera is facing.
	var forward: Vector3 = -camera.global_transform.basis.z

	# Ignore vertical camera rotation.
	# The radio stays at chest height even when
	# Ellis looks up or down.
	forward.y = 0.0

	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	else:
		forward = Vector3.FORWARD

	# Position the radio below the camera and
	# slightly forward from Ellis's chest.
	handheld_speaker.global_position = (
		camera.global_position
		+ RADIO_CHEST_OFFSET
		+ forward * RADIO_FORWARD_DISTANCE
	)


# ==========================================
# ADD RADIO TRANSMISSION
# ==========================================

func play_transmission(
	speaker: String,
	subtitle: String,
	recording: AudioStream,
	incoming: bool = true
) -> void:

	if recording == null:

		push_warning(
			"Radio transmission has no recording."
		)

		return

	message_queue.append({
		"speaker": speaker,
		"subtitle": subtitle,
		"recording": recording,
		"incoming": incoming
	})

	if not is_transmitting:
		_play_next()


# ==========================================
# PLAY NEXT TRANSMISSION
# ==========================================

func _play_next() -> void:

	if message_queue.is_empty():

		is_transmitting = false
		hud.hide()

		return

	is_transmitting = true

	var message: Dictionary = message_queue.pop_front()

	# Update subtitles.
	speaker_label.text = str(message["speaker"])
	subtitle_label.text = str(message["subtitle"])

	var recording: AudioStream = \
		message["recording"] as AudioStream

	var is_incoming: bool = bool(message["incoming"])

	# Assign the recording to the correct player.
	if is_incoming:

		incoming_voice.stream = recording

	else:

		voice.stream = recording

	# Fade in the subtitle UI.
	if not hud.visible:

		hud.modulate.a = 0.0
		hud.show()

		var tween = create_tween()

		tween.tween_property(
			hud,
			"modulate:a",
			1.0,
			0.15
		)

	# Start the transmission sequence.
	_start_radio_audio(is_incoming)


# ==========================================
# START TRANSMISSION AUDIO
# ==========================================

func _start_radio_audio(is_incoming: bool) -> void:

	# 1. Opening radio click.
	if radio_start.stream != null:

		radio_start.play()

		await radio_start.finished

	# 2. Start quiet radio interference.
	if radio_static.stream != null:

		radio_static.play()

	# 3. Play the appropriate voice.
	if is_incoming:

		# Voss, Brandt, Nair, etc.
		incoming_voice.play()

	else:

		# Ellis replying.
		voice.play()


# ==========================================
# END TRANSMISSION
# ==========================================

func _on_voice_finished() -> void:

	# Stop radio interference.
	radio_static.stop()

	# Play the closing radio click.
	if radio_end.stream != null:

		radio_end.play()

		await radio_end.finished

	# Short pause between transmissions.
	await get_tree().create_timer(0.8).timeout

	# Continue with the next message.
	_play_next()
