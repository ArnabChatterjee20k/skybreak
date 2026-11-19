// One-frame anime impact frame: inverts the screen and crushes it to stark contrast.
shader_type canvas_item;

// Read only on the 1-2 frames the rect is visible; hidden, it costs nothing.
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// 0 = plain inversion, 1 = two-tone ink frame.
uniform float contrast : hint_range(0.0, 1.0) = 0.8;
uniform vec4 light_color : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform vec4 ink_color : source_color = vec4(0.05, 0.03, 0.08, 1.0);

void fragment() {
	vec3 scene = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec3 inverted = 1.0 - scene;
	float lum = dot(inverted, vec3(0.299, 0.587, 0.114));
	float band = mix(0.5, 0.03, contrast);
	float stark = smoothstep(0.5 - band, 0.5 + band, lum);
	vec3 graded = mix(inverted, mix(ink_color.rgb, light_color.rgb, stark), contrast);
	COLOR = vec4(mix(scene, graded, amount), 1.0);
}
