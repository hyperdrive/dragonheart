shader_type canvas_item;

// The living ground (2026-11-15, user: "the landscape is now all one single
// colour but I want it to be default 'meadow with hills'. However each prop
// and building should have an influence that blends the environment into a
// suitable environment. I.e. mountains cause rocky ground. Fields cause flat
// grassland etc.").
//
// One quad under the whole world (GroundTerrain.gd). Everywhere it paints a
// rolling meadow: low-frequency hills lit from the upper left, grass tufts,
// scattered wildflowers. Two splat maps — painted on the CPU from every
// prop's position and reach — blend in the local ground:
//   splat_a: r rock · g farmland (flat grass) · b marsh · a trodden dirt
//   splat_b: r forest floor · g lush meadow · b lake sand · a ash
// Splat lookups are warped by noise so every boundary is organic, and the
// flat grounds (farmland, dirt, lush glade, sand) iron the hills out.

uniform sampler2D splat_a : filter_linear, repeat_disable;
uniform sampler2D splat_b : filter_linear, repeat_disable;
uniform vec2 origin = vec2(-1760.0, -1760.0);   // world rect of this quad
uniform vec2 extent = vec2(3520.0, 3520.0);
uniform vec2 world_half = vec2(960.0, 960.0);   // the playfield's half size
uniform float seed = 0.0;

varying vec2 world;

void vertex() {
	world = origin + UV * extent;
}

// Integer hash of the lattice cell holding p. (A float fract() hash lost
// its precision at world-sized coordinates and striped the map with
// straight bands; integer arithmetic is exact everywhere.)
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
	for (int k = 0; k < 5; k++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

// Rolling hills: three broad octaves only — finer detail read as
// camouflage blotches instead of slopes.
float hill(vec2 w) {
	vec2 p = w / 620.0;
	float v = vnoise(p) * 0.6;
	v += vnoise(p * 2.1 + vec2(5.2, 1.3)) * 0.28;
	v += vnoise(p * 4.3 + vec2(2.7, 8.1)) * 0.12;
	return v;
}

// A speck on a jittered grid: 1 inside the dot, 0 elsewhere.
float speck(vec2 w, float cell, float density, float radius, out float pick) {
	vec2 c = floor(w / cell);
	float h = hash(c + 7.7);
	pick = hash(c + 3.1);
	if (h > density) {
		return 0.0;
	}
	vec2 centre = (c + 0.2 + 0.6 * vec2(hash(c + 1.3), hash(c + 5.9))) * cell;
	return 1.0 - smoothstep(radius * 0.6, radius, length(w - centre));
}

void fragment() {
	vec2 w = world;

	// --- which ground is this? ---------------------------------------------
	vec2 warp = (vec2(vnoise(w / 90.0), vnoise(w / 90.0 + 31.0)) - 0.5) * 2.0 * 40.0;
	vec2 suv = (w + warp - origin) / extent;
	vec4 a = texture(splat_a, suv);
	vec4 b = texture(splat_b, suv);
	// Soft, wide transitions (2026-11-15, user: "the different environments
	// must blend better … make difference more subtle"): the weights follow
	// the painted gradient almost linearly, gently roughened by noise.
	float edge_n = (vnoise(w / 40.0) - 0.5) * 0.22;
	float rock = smoothstep(0.08, 0.95, a.r + edge_n) * 0.85;
	float farm = smoothstep(0.08, 0.95, a.g + edge_n) * 0.9;
	float marsh = smoothstep(0.08, 0.95, a.b + edge_n) * 0.85;
	float dirt = smoothstep(0.10, 0.95, a.a + edge_n) * 0.85;
	float forest = smoothstep(0.08, 0.95, b.r + edge_n) * 0.75;
	float lush = smoothstep(0.08, 0.95, b.g + edge_n) * 0.8;
	float sand = smoothstep(0.20, 0.95, b.b + edge_n) * 0.8;
	float ash = smoothstep(0.10, 0.95, b.a + edge_n) * 0.8;

	// --- the hills: lit from the upper left, ironed flat by tilled ground ---
	float flatness = clamp(max(max(farm, dirt), max(sand, lush * 0.6)), 0.0, 1.0);
	float e = 14.0;
	float hx = hill(w + vec2(e, 0.0)) - hill(w - vec2(e, 0.0));
	float hy = hill(w + vec2(0.0, e)) - hill(w - vec2(0.0, e));
	vec3 n = normalize(vec3(-hx * 14.0, -hy * 14.0, 1.0));
	vec3 sun = normalize(vec3(-0.55, -0.7, 0.55));
	float shade = dot(n, sun) / sun.z;               // 1.0 on flat ground
	shade = mix(shade, 1.0, flatness * 0.85);
	float height = hill(w);

	// --- meadow (the default) -------------------------------------------------
	float m = fbm(w / 95.0);
	vec3 meadow = mix(vec3(0.41, 0.59, 0.28), vec3(0.46, 0.63, 0.30), m);
	meadow = mix(meadow, vec3(0.50, 0.66, 0.31), smoothstep(0.55, 0.8, height) * 0.25); // sunny tops
	meadow = mix(meadow, vec3(0.38, 0.57, 0.28), smoothstep(0.45, 0.25, height) * 0.25); // lush hollows
	float tuft = vnoise(w / 5.0) * vnoise(w / 17.0);
	meadow *= 0.96 + 0.08 * tuft;

	// --- the local grounds, gentlest first. Each is only computed where it
	// has influence: most of the map is plain meadow, and the noise is the
	// expensive part.
	vec3 col = meadow;

	if (farm > 0.0) {   // farmland: flat, even, sun-yellowed grass, mown rows
		vec3 farmc = mix(vec3(0.58, 0.70, 0.34), vec3(0.66, 0.73, 0.38), fbm(w / 70.0));
		farmc *= 0.98 + 0.03 * sin(w.x * 0.11 + vnoise(w / 40.0) * 4.0);
		farmc = mix(farmc, meadow, 0.25);
		col = mix(col, farmc, farm);
	}
	if (lush > 0.0) {   // lush glade/shore: vivid green
		vec3 lushc = mix(vec3(0.34, 0.62, 0.28), vec3(0.43, 0.71, 0.33), fbm(w / 60.0));
		lushc = mix(lushc, meadow, 0.25);
		col = mix(col, lushc, lush);
	}
	if (forest > 0.0) { // forest floor: moss and leaf litter
		vec3 forestc = mix(vec3(0.24, 0.42, 0.20), vec3(0.32, 0.47, 0.22), fbm(w / 45.0));
		float litter = smoothstep(0.62, 0.72, vnoise(w / 9.0));
		forestc = mix(forestc, vec3(0.45, 0.36, 0.20), litter * 0.55);
		forestc = mix(forestc, meadow, 0.25);
		col = mix(col, forestc, forest);
	}
	if (marsh > 0.0) {  // marsh: dark olive with standing water
		vec3 marshc = mix(vec3(0.27, 0.36, 0.20), vec3(0.34, 0.40, 0.22), fbm(w / 50.0));
		float pool = smoothstep(0.58, 0.62, fbm(w / 55.0 + 9.0));
		vec3 water = mix(vec3(0.18, 0.30, 0.28), vec3(0.30, 0.44, 0.40), vnoise(w / 12.0));
		marshc = mix(marshc, water, pool * 0.6);
		marshc = mix(marshc, meadow, 0.25);
		col = mix(col, marshc, marsh);
	}
	if (sand > 0.0) {   // lake sand
		vec3 sandc = mix(vec3(0.80, 0.74, 0.55), vec3(0.86, 0.80, 0.62), vnoise(w / 14.0));
		sandc = mix(sandc, meadow, 0.25);
		col = mix(col, sandc, sand);
	}
	if (dirt > 0.0) {   // trodden dirt
		vec3 dirtc = mix(vec3(0.55, 0.45, 0.31), vec3(0.62, 0.52, 0.36), fbm(w / 40.0));
		dirtc *= 0.92 + 0.12 * vnoise(w / 3.0);
		dirtc = mix(dirtc, meadow, 0.25);
		col = mix(col, dirtc, dirt);
	}
	if (rock > 0.0) {   // stony ground: weathered, grass between the stones
		vec3 rockc = mix(vec3(0.50, 0.50, 0.43), vec3(0.57, 0.56, 0.48), fbm(w / 48.0));
		rockc *= 0.94 + 0.08 * vnoise(w / 7.0);                            // grain
		float weather = smoothstep(0.35, 0.75, fbm(w / 26.0 + 4.0));
		rockc *= 1.0 - weather * 0.08;                                       // faint weathering
		float pk;
		float peb = speck(w, 14.0, 0.14, 2.2, pk);
		rockc = mix(rockc, vec3(0.62, 0.60, 0.54), peb * 0.3);              // a few small stones
		// grass grows through everywhere, more where the stone thins out
		float grass = smoothstep(0.4, 0.75, fbm(w / 30.0 + 2.0));
		rockc = mix(rockc, meadow * 0.95, clamp(grass * 0.55 + (1.0 - rock) * 0.35, 0.0, 0.85));
		col = mix(col, rockc, rock);
	}
	if (ash > 0.0) {    // ash: the dragon's doorstep, embers still glowing
		vec3 ashc = mix(vec3(0.24, 0.22, 0.21), vec3(0.34, 0.31, 0.29), fbm(w / 30.0));
		float ek;
		float ember = speck(w, 19.0, 0.10, 1.6, ek);
		ashc = mix(ashc, vec3(1.0, 0.45, 0.12), ember * 0.45 * (0.6 + 0.4 * sin(TIME * 2.0 + ek * 20.0)));
		ashc = mix(ashc, meadow, 0.25);
		col = mix(col, ashc, ash);
	}

	// --- wildflowers: sparse on the meadow, thick in the glade --------------
	float fp;
	float wild = 1.0 - max(max(rock * 0.8, dirt), max(max(marsh, sand), max(ash, forest * 0.7)));
	float density = mix(0.16, 0.34, lush) * wild * (1.0 - farm * 0.7);
	float fl = speck(w + vec2(3.0, 7.0), 11.0, density, 1.9, fp);
	vec3 petal = fp < 0.3 ? vec3(1.0, 0.95, 0.85) : (fp < 0.55 ? vec3(1.0, 0.86, 0.3)
		: (fp < 0.8 ? vec3(0.95, 0.55, 0.75) : vec3(0.68, 0.58, 0.95)));
	col = mix(col, petal, fl * 0.9);

	// --- light ---------------------------------------------------------------------
	float lit = mix(1.0, clamp(shade, 0.9, 1.08), 1.0 - marsh * 0.5);
	col *= lit;

	// a quieter palette (2026-11-15, user: "a lot less saturated" — the
	// ground is the stage; the dragon's fire carries the colour)
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, 1.0);    // the colour grade (color_grade.gdshader) takes it down to ~0.64

	// beyond the boundary walls the land dims into wilderness
	vec2 outside = max(abs(w) - world_half, vec2(0.0));
	col *= 1.0 - smoothstep(0.0, 260.0, max(outside.x, outside.y)) * 0.45;

	COLOR = vec4(col, 1.0);
}
