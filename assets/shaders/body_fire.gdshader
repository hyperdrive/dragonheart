shader_type canvas_item;

// Rising fire (2026-11-15, user: "When NPCs are alit with fire they need a
// better shader too."). One ColorRect over a burning body (BaseNPC) or a
// Greater Flame ground patch (GroundFire). UV.y runs from the top (0) to
// the base (1); the fire is born along the base and licks upward.
//
// The same saturated ramp as the dragon's breath (dragon_flame.gdshader):
// white-hot base, yellow, orange, blood-red tips, a deep-red fringe and a
// soft halo — plus sparks drifting up. `intensity` (0..1) is the fire's
// life: it flares at ignition and gutters as the burn runs out. `seed`
// keeps two fires from flickering in step.

uniform float intensity = 1.0;
uniform float seed = 0.0;
// 0 = a body (a candle-like teardrop), 1 = a ground patch (wide, low)
uniform float spread = 0.0;
// -1..1: the body's run, left/right — the flame streams back from it
uniform float lean = 0.0;

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
	float t = TIME + seed * 13.0;
	float x = UV.x - 0.5;
	float v = 1.0 - UV.y;                       // height above the base, 0..1
	float life = clamp(intensity, 0.0, 1.0);

	float n = fbm(vec2(UV.x * 4.0, v * 3.2 - t * 3.6));
	float n2 = fbm(vec2(UV.x * 9.0 + 3.0, v * 7.0 - t * 6.5));
	float d;
	float heat;
	if (spread < 0.5) {
		// A candle flame (2026-11-15, user: "the flame has a very flat bottom
		// and seems static … make it more like a candle flame"): a rounded
		// teardrop — round base, pinched, flickering tip — that streams back
		// from the run and wavers on its own.
		float flick = vnoise(vec2(t * 3.1, seed * 5.0));
		float top = mix(0.62, 1.0, life) * (0.86 + 0.2 * flick);
		float u = clamp(v / top, 0.0, 1.0);
		float sway = (vnoise(vec2(t * 2.3, seed * 3.0 + 9.0)) - 0.5) * 0.16;
		x += (lean * 0.34 + sway) * u * u;          // the tip trails behind the run
		x += (n - 0.5) * 0.18 * u;                  // turbulence
		float w = 0.38 * sin(PI * pow(u, 0.55));    // teardrop: round base, pointed tip
		d = (1.0 - abs(x) / max(w, 0.001)) * step(v, top);
		d += (n2 - 0.5) * (0.3 + 0.55 * u);         // ragged, licking edges
		float lick = fbm(vec2(UV.x * 14.0, v * 10.0 - t * 9.0));
		d -= smoothstep(0.55, 0.8, lick) * 0.45 * u; // dark gaps flicker through
		d *= smoothstep(1.0, 0.86, u) * 0.6 + 0.4;  // the tip thins to a wisp
		heat = d * (1.18 - u * 0.62) * (0.6 + 0.5 * life);
	} else {
		// a ground patch: a wide, low, ragged bed of tongues
		x += (n - 0.5) * 0.22 * v;
		float top = mix(0.55, 1.0, life) * 0.75;
		float width = mix(0.47, 0.06, pow(clamp(v / top, 0.0, 1.0), 0.8));
		d = 1.0 - abs(x) / max(width, 0.001);
		d += (n2 - 0.5) * 0.8;
		d -= smoothstep(0.5 * top, top, v) * (1.2 - n) * 1.1;
		d *= smoothstep(0.0, 0.08, v);
		heat = d * (1.12 - v * 0.65) * (0.55 + 0.5 * life);
	}

	vec3 deep = vec3(0.55, 0.0, 0.0);
	vec3 red = vec3(1.0, 0.08, 0.0);
	vec3 orange = vec3(1.0, 0.42, 0.0);
	vec3 yellow = vec3(1.0, 0.82, 0.05);
	vec3 white = vec3(1.0, 0.98, 0.78);
	vec3 col = deep;
	col = mix(col, red, smoothstep(0.02, 0.22, heat));
	col = mix(col, orange, smoothstep(0.22, 0.48, heat));
	col = mix(col, yellow, smoothstep(0.48, 0.74, heat));
	col = mix(col, white, smoothstep(0.88, 1.08, heat));
	float body = smoothstep(0.0, 0.1, heat);

	// sparks: small bright motes drifting up through the fire and above it
	vec2 sp = vec2(UV.x * 9.0, v * 6.0 - t * 2.4);
	vec2 cell = floor(sp);
	vec2 f = fract(sp);
	float h = hash(cell + 11.0);
	vec2 c = vec2(0.2 + 0.6 * hash(cell + 2.0), fract(h * 7.3));
	float spark = (1.0 - smoothstep(0.03, 0.09, length(f - c)))
		* step(0.82, h) * smoothstep(1.0, 0.35, v) * life;

	// glow around the figure
	float halo = smoothstep(-0.7, 0.0, heat) * (1.0 - body) * 0.3 * (1.0 - v * 0.7) * life;

	vec3 out_col = mix(vec3(1.0, 0.3, 0.0), col, body);
	out_col = mix(out_col, vec3(1.0, 0.75, 0.25), spark);
	float edges = smoothstep(0.0, 0.12, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x))
		* smoothstep(0.0, 0.1, UV.y);
	float a = clamp(body * life + halo + spark, 0.0, 1.0) * edges;
	COLOR = vec4(out_col, a);
}
