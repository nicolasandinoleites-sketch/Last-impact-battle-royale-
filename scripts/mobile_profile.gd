extends RefCounted
# Preserve native canvas layout on desktop. Android uses a bounded internal viewport
# because Compatibility does not implement every 3D scaling path consistently.
static func apply_android(window: Window, profile: int) -> void:
	if not OS.has_feature("android"):
		return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = [Vector2i(800,450),Vector2i(960,540),Vector2i(1280,720)][clampi(profile,0,2)]
	window.scaling_3d_scale = 1.0
