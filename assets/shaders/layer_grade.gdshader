shader_type canvas_item;

// One layer's colour grade (2026-11-15, layered palettes — Palettes.gd,
// LayerGrade.gd). Set as the material of a prop/building/character root;
// its CanvasItem descendants inherit it (use_parent_material). The pixel's
// luminance looks up the palette's three-stop ramp (dark → mid → light),
// which replaces the original colour by `ramp_mix`; then saturation and
// exposure. Fire and blood (saturated, bright, red-leading) are left alone.

uniform vec3 ramp_dark : source_color = vec3(0.1);
uniform vec3 ramp_mid : source_color = vec3(0.5);
uniform vec3 ramp_light : source_color = vec3(0.9);
uniform float ramp_mix = 0.0;
uniform float saturation = 1.0;
uniform float exposure = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec3 rgb = c.rgb;
	float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));

	float mx = max(rgb.r, max(rgb.g, rgb.b));
	float mn = min(rgb.r, min(rgb.g, rgb.b));
	float sat = (mx - mn) / (mx + 0.0001);
	float fire = smoothstep(0.6, 0.85, sat) * smoothstep(0.45, 0.75, mx)
		* smoothstep(0.3, 0.55, rgb.r - rgb.b) * step(rgb.g, rgb.r + 0.001);

	vec3 ramp = l < 0.5 ? mix(ramp_dark, ramp_mid, l * 2.0) : mix(ramp_mid, ramp_light, l * 2.0 - 1.0);
	vec3 g = mix(rgb, ramp, ramp_mix);
	float gl = dot(g, vec3(0.2126, 0.7152, 0.0722));
	g = mix(vec3(gl), g, saturation) * exposure;
	COLOR = vec4(mix(clamp(g, 0.0, 1.0), rgb, fire), c.a);
}
