class_name ReliefPlatformDiagnostics
extends Node

## Relief Cross-Platform Monitor & Lockstep Sync
## Add this script as an Autoload in Project Settings.

# --- LOCKSTEP SETTINGS ---
@export_group("Lockstep Syncing")
## When enabled, physics ticks are tied to the frame rate / display refresh rate.
@export var lockstep_enabled: bool = true

## If true, syncs to the monitor's physical refresh rate (recommended for stability).
## If false, dynamically updates physics ticks per second to match current rendering FPS.
@export var sync_to_screen_refresh_rate: bool = true

## Clamping limits to prevent physics engine collapse during severe frame drops or extreme FPS.
@export var min_physics_ticks: int = 30
@export var max_physics_ticks: int = 240

# --- DEBUG DISPLAY SETTINGS ---
@export_group("Developer HUD")
@export var show_debug_hud: bool = true
@export var hud_update_interval: float = 0.5 # In seconds

# --- ROOT TREE & SYSTEM REFERENCES ---
var root_tree: SceneTree
var root_window: Window

# --- INTERNAL STATE ---
var _time_since_last_hud_update: float = 0.0
var _hud_label: Label
var _hud_canvas: CanvasLayer


func _ready() -> void:
	# 1. Grab and hold the root tree and root viewport/window
	root_tree = get_tree()
	root_window = root_tree.root
	
	# Keep this node running even if the scene tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 2. Configure initial Lockstep synchronization
	#apply_lockstep_settings() #TURNED OFF FOR DEVELOPMENT PURPOSES
	
	#if OS.get_name() == "macOS":        #malce po optimised e, ne se igra na 30
		#var screen_refresh = DisplayServer.screen_get_refresh_rate()
		#var target_ticks: int = screen_refresh / 2
		#Engine.physics_ticks_per_second = target_ticks
		#Engine.max_fps = target_ticks
			
	# 3. Print initial platform audit to the console
	print_full_diagnostics_report()
	
	# 4. Set up on-screen HUD (works across Desktop, Mobile, and Web)
	if show_debug_hud:
		_setup_debug_hud()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
	# Continuous lockstep if dynamic frame-rate matching is enabled
	if lockstep_enabled and not sync_to_screen_refresh_rate:
		_sync_physics_to_dynamic_fps()
	
	# Periodic HUD and state checks
	_time_since_last_hud_update += delta
	if _time_since_last_hud_update >= hud_update_interval:
		_time_since_last_hud_update = 0.0
		if show_debug_hud and _hud_label != null:
			_update_hud()


# ==============================================================================
# LOCKSTEP SYNCHRONIZATION
# ==============================================================================

## Configures the physics ticks per second to match frame timing.
func apply_lockstep_settings() -> void:
	if not lockstep_enabled:
		return
		
	if sync_to_screen_refresh_rate:
		var refresh_rate: float = DisplayServer.screen_get_refresh_rate()
		
		# Some web browsers and mobile drivers return <= 0 for refresh rate
		if refresh_rate <= 0.0:
			push_warning("[Relief] Refresh rate undetected. Falling back to 60 Hz lockstep.")
			refresh_rate = 60.0
			
		var target_ticks: int = clampi(int(round(refresh_rate)), min_physics_ticks, max_physics_ticks)
		
		Engine.physics_ticks_per_second = target_ticks
		Engine.max_fps = target_ticks # Lock rendering to match
		
		print("[Relief Lockstep] Fixed to screen refresh rate: %d Hz (Physics: %d, Max FPS: %d)" % [
			int(refresh_rate),
			Engine.physics_ticks_per_second,
			Engine.max_fps
		])
	else:
		# Unlock max_fps so dynamic tracking can take over
		Engine.max_fps = 0


## Dynamically adjusts physics ticks to follow actual rendered FPS.
func _sync_physics_to_dynamic_fps() -> void:
	var current_fps: int = int(round(Engine.get_frames_per_second()))
	if current_fps > 0:
		var clamped_ticks: int = clampi(current_fps, min_physics_ticks, max_physics_ticks)
		if Engine.physics_ticks_per_second != clamped_ticks:
			Engine.physics_ticks_per_second = clamped_ticks


# ==============================================================================
# DIAGNOSTICS & METRICS GATHERING
# ==============================================================================

## Returns a comprehensive dictionary of variables relevant across platforms.
func get_platform_diagnostics() -> Dictionary:
	var screen_idx: int = DisplayServer.window_get_current_screen()
	
	return {
		# OS & Hardware Identity
		"os_name": OS.get_name(),
		"device_model": OS.get_model_name(),
		"cpu_architecture": Engine.get_architecture_name(),
		"processor_name": OS.get_processor_name(),
		"cpu_cores": OS.get_processor_count(),
		"is_mobile": OS.has_feature("mobile"),
		"is_pc": OS.has_feature("pc"),
		"is_web": OS.has_feature("web"),
		"has_touchscreen": DisplayServer.is_touchscreen_available(),
		
		# Rendering & GPU
		"rendering_driver": DisplayServer.get_name(),
		"gpu_name": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		
		# Display & Resolution
		"window_size": DisplayServer.window_get_size(),
		"screen_resolution": DisplayServer.screen_get_size(screen_idx),
		"screen_dpi": DisplayServer.screen_get_dpi(screen_idx),
		"screen_scale": DisplayServer.screen_get_scale(screen_idx),
		"screen_refresh_rate": DisplayServer.screen_get_refresh_rate(screen_idx),
		"window_mode": DisplayServer.window_get_mode(),
		
		# Performance & Runtime Metrics
		"fps": Engine.get_frames_per_second(),
		"physics_ticks_per_sec": Engine.physics_ticks_per_second,
		"static_ram_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"static_ram_max_mb": Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0,
		"vram_total_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives_rendered": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"process_time_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_process_time_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		
		# Peripherals & Input
		"connected_joypads": Input.get_connected_joypads().size()
	}


## Prints a clean breakdown to the Godot output console.
func print_full_diagnostics_report() -> void:
	var d: Dictionary = get_platform_diagnostics()
	var report: String = """
===================== [RELIEF PLATFORM REPORT] =====================
OS: %s (%s) | Model: %s | CPU: %s (%d cores)
Target Type: Mobile: %s | PC: %s | Web: %s | Touchscreen: %s
GPU: %s (%s) via %s
Resolution: Screen %s | Window %s | DPI: %d | Scale: %.2f | Refresh: %.1f Hz
Physics Ticks: %d/sec | Lockstep Active: %s
====================================================================
""" % [
		d.os_name, d.cpu_architecture, d.device_model, d.processor_name, d.cpu_cores,
		d.is_mobile, d.is_pc, d.is_web, d.has_touchscreen,
		d.gpu_name, d.gpu_vendor, d.rendering_driver,
		d.screen_resolution, d.window_size, d.screen_dpi, d.screen_scale, d.screen_refresh_rate,
		d.physics_ticks_per_sec, lockstep_enabled
	]
	print(report)


# ==============================================================================
# ON-SCREEN DEVELOPER OVERLAY (HUD)
# ==============================================================================

func _setup_debug_hud() -> void:
	_hud_canvas = CanvasLayer.new()
	_hud_canvas.layer = 128 # Draw on top of game content
	add_child(_hud_canvas)
	
	_hud_label = Label.new()
	_hud_label.position = Vector2(16, 16)
	_hud_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2, 1.0)) # Terminal green
	_hud_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hud_label.add_theme_constant_override("shadow_offset_x", 1)
	_hud_label.add_theme_constant_override("shadow_offset_y", 1)
	_hud_canvas.add_child(_hud_label)


func _update_hud() -> void:
	var d: Dictionary = get_platform_diagnostics()
	_hud_label.text = (
		"RELIEF DEV MONITOR\n" +
		"Platform: %s (%s) | FPS: %d | Physics: %d tps\n" % [d.os_name, d.cpu_architecture, d.fps, d.physics_ticks_per_sec] +
		"Frame Time: %.2f ms | Physics Time: %.2f ms\n" % [d.process_time_ms, d.physics_process_time_ms] +
		"RAM: %.1f MB (Peak: %.1f MB) | VRAM: %.1f MB\n" % [d.static_ram_mb, d.static_ram_max_mb, d.vram_total_mb] +
		"Draw Calls: %d | Primitives: %d\n" % [d.draw_calls, d.primitives_rendered] +
		"Display: %dx%d (Scale: %.2f)\n" % [d.window_size.x, d.window_size.y, d.screen_scale] +
		"Controllers: %d" % [d.connected_joypads]
	)
