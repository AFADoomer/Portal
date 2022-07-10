const float pi = 3.14159265358979323846;

vec4 SmoothEdges(vec4 basicColor);
vec2 Rotate(vec2 v, float a);

vec4 ProcessTexel()
{
	vec2 texCoord = vTexCoord.st;
	vec3 offset = normalize(uCameraPos.xyz - pixelpos.xyz);
	vec2 normal = normalize(vWorldNormal.xz);

	if (vWorldNormal.x < 0.0) { normal = Rotate(normal, pi); }

	float angle = acos(dot(normal, vec2(0.0, 1.0)));
	float dist = Rotate(offset.xz, -angle).x;

	if (vWorldNormal.x < 0.0) { dist *= -1; }

	texCoord.x = texCoord.x + dist / 4;
	texCoord.y = texCoord.y - offset.y / 4;

	// vec4 overlay = vec4(0, 0, 0, 1.0);
	// overlay.r = (dist > 0.0) ? dist : 0.0;
	// overlay.b = (dist < 0.0) ? abs(dist) : 0.0;
	// overlay.g = abs(offset.y);

	// return mix(SmoothEdges(getTexel(texCoord)), overlay, 0.85);
	return SmoothEdges(getTexel(texCoord));
}

// Shapes the texture into an oval with gradient/faded edges
vec4 SmoothEdges(vec4 basicColor)
{
	float dist = distance(vec2(vTexCoord.s * 2, vTexCoord.t), vec2(1.0, 0.5));
	basicColor *= smoothstep(0.65, 0.45, dist);

	return basicColor;
}

// From https://gist.github.com/yiwenl/3f804e80d0930e34a0b33359259b556c
// and https://thebookofshaders.com/08/
vec2 Rotate(vec2 v, float a)
{
	float s = sin(a);
	float c = cos(a);
	mat2 m = mat2(c, -s, s, c);

	return m * v;
}