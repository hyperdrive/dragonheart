shader_type canvas_item;

// The dragon's breath (2026-11-15, user: "increase saturation of the flame.
// Maybe we should try writing a flame shader?"). Drawn on one ColorRect
// inside Vis/FireArea/Flame (Dragon._build_flame_fx), so the Flame node's
// facing flip and Greater Flame's ×2 length apply unchanged. UV.x runs from
// the mouth (0) to the tip (1), UV.y across the jet.
//
// A turbulent jet: noise scrolls outward from the mouth, the cone flares
// and then breaks into tongues at the tip. Heat maps through a fully
// saturated ramp — white-hot core, yellow, orange, blood-red, smoke-dark
// fringe — with a soft halo. `power` (the breath animation's burst, 0..1.5)
// and `fade` (its alpha) are fed every frame by Dragon.

uniform float power = 1.0;
uniform float fade = 1.0;
uniform float seed = 0.0;

float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p)) + ivec2(1048576));
	uint h = (q.x * 1597334677u) ^ (q.y * 3812015801u) ^ uint(seed * 7919.0);
	h = (h ^ (h >> 16u)) * 2246822519u;
	h = (h ^ (h >> 13u)) * 3266489917u;
	h = h ^ (h >> 16u);
	return float(h) * (1.0 / 4294967295.0);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec2(3.1, 7.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float x = UV.x;
	float y = UV.y - 0.5;
	float t = TIME;

	// turbulence streaming out of the mouth
	float n = fbm(vec2(x * 5.0 - t * 9.0, y * 6.0 + t * 0.7));
	float n2 = fbm(vec2(x * 11.0 - t * 15.0, y * 11.0 - t * 1.3) + 5.0);
	// the jet wavers sideways a little
	y += (n - 0.5) * 0.18 * x;

	// cone: narrow at the mouth, flaring, then breaking up near the tip
	float reach = clamp(power, 0.0, 1.5) / 1.5 * 0.35 + 0.65;   // the burst reaches further
	float width = mix(0.07, 0.42, pow(clamp(x / reach, 0.0, 1.0), 0.55));
	float d = 1.0 - abs(y) / width;
	d += (n2 - 0.5) * 0.7;
	float tip = smoothstep(0.45 * reach, reach, x);
	d -= tip * (1.25 - n) * 1.4;           // tongues and gaps at the tip
	d *= smoothstep(0.0, 0.03, x);         // born at the mouth

	// heat: hottest along the axis near the mouth
	float heat = d * (1.15 - x * 0.75) * (0.75 + 0.35 * power);

	vec3 deep = vec3(0.55, 0.0, 0.0);
	vec3 red = vec3(1.0, 0.08, 0.0);
	vec3 orange = vec3(1.0, 0.42, 0.0);
	vec3 yellow = vec3(1.0, 0.82, 0.05);
	vec3 white = vec3(1.0, 0.98, 0.78);
	vec3 col = deep;
	col = mix(col, red, smoothstep(0.02, 0.22, heat));
	col = mix(col, orange, smoothstep(0.22, 0.48, heat));
	col = mix(col, yellow, smoothstep(0.48, 0.74, heat));
	col = mix(col, white, smoothstep(0.78, 1.0, heat));

	float body = smoothstep(0.0, 0.1, heat);
	// a soft halo of light around the jet
	float halo = smoothstep(-0.55, 0.0, heat) * (1.0 - body) * 0.35 * (1.0 - x * 0.6);
	vec3 out_col = mix(vec3(1.0, 0.3, 0.0), col, body);
	// fade everything out before the rectangle's edges (no visible seams)
	float edges = smoothstep(0.0, 0.06, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x))
		* smoothstep(0.0, 0.18, UV.y) * (1.0 - smoothstep(0.82, 1.0, UV.y));
	float a = clamp(body + halo, 0.0, 1.0) * fade * edges;
	COLOR = vec4(out_col, a);
}
