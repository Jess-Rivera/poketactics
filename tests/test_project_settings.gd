extends GdUnitTestSuite
## Issue #1 end-goal relation 5: project settings match the rulings
## (2026-11-15-renderer-compatibility, 2026-11-15-base-resolution).


func test_renderer_is_compatibility() -> void:
	assert_str(ProjectSettings.get_setting("rendering/renderer/rendering_method")).is_equal("gl_compatibility")


func test_base_resolution_is_640_by_360() -> void:
	assert_int(ProjectSettings.get_setting("display/window/size/viewport_width")).is_equal(640)
	assert_int(ProjectSettings.get_setting("display/window/size/viewport_height")).is_equal(360)


func test_scaling_is_whole_numbers_of_the_whole_viewport() -> void:
	assert_str(ProjectSettings.get_setting("display/window/stretch/mode")).is_equal("viewport")
	assert_str(ProjectSettings.get_setting("display/window/stretch/scale_mode")).is_equal("integer")


func test_default_texture_filter_is_nearest() -> void:
	assert_int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) \
		.is_equal(Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
