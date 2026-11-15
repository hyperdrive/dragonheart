shader_type canvas_item;

// The grim-dark colour grade (2026-11-15, user: "we also need to harmonise
// the colour grades across all assets. Pick a colour grading for a grim
// dark setting and apply."). A full-screen pass over the WORLD (CanvasLayer 1,
// built by GameManager._build_color_grade) — under the HUD and the story
// popups, so every sprite, prop, NPC and the ground share one grade:
//
//   exposure   a little under: dusk, not noon
//   saturation pulled down evenly — EXCEPT fire and blood: saturated, bright,
//              warm pixels keep (and gain) their colour, so the dragon's
//              flame is the most vivid thing on screen
//   contrast   a firm S around the mid-tones
//   split tone cold slate shadows, tarnished-amber highlights
//   lift       blacks raised toward cold blue-grey (old, faded film)
//   vignette   the edges of the world sink into gloom

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float exposure = 0.8;
uniform float saturation = 0.64;
uniform float fire_saturation = 1.25;
uniform float contrast = 1.2;
uniform vec3 shadow_tint = vec3(0.80, 0.91, 1.08);
uniform vec3 highlight_tint = vec3(1.06, 0.97, 0.83);
uniform vec3 lift_color = vec3(0.045, 0.052, 0.07);
uniform float vignette = 0.5;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));

	// fire & blood: saturated, warm (red leads, blue lags), not dark
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / (mx + 0.0001);
	float warm = smoothstep(0.25, 0.55, c.r - c.b) * step(c.g, c.r + 0.001);
	float fire = smoothstep(0.55, 0.85, sat) * smoothstep(0.35, 0.7, mx) * warm;

	vec3 g = c * mix(exposure, 1.0, fire);
	float gl = l * mix(exposure, 1.0, fire);
	g = mix(vec3(gl), g, mix(saturation, fire_saturation, fire));

	// firm S-curve around the mid-tones
	g = clamp((g - 0.45) * contrast + 0.45, 0.0, 1.0);
	g = mix(g, g * g * (3.0 - 2.0 * g), 0.25);

	// split toning (fire keeps its own hue)
	vec3 tone = mix(shadow_tint, highlight_tint, smoothstep(0.12, 0.72, gl));
	g *= mix(tone, vec3(1.0), fire);

	// faded blacks, cold
	g = lift_color + g * (1.0 - lift_color);

	// vignette
	vec2 v = UV - 0.5;
	v.x *= 1.25;
	g *= 1.0 - vignette * smoothstep(0.3, 0.78, length(v));

	COLOR = vec4(g, 1.0);
}
