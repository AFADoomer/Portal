// Shapes the texture into an oval with gradient/faded edges

vec4 ProcessTexel()
{
	vec2 texCoord = vTexCoord.st;
	vec4 basicColor = getTexel(texCoord);
	float dist = distance(vec2(gl_TexCoord[0].x * 2, gl_TexCoord[0].y), vec2(1.0, 0.5));
	basicColor *= smoothstep(0.65, 0.45, dist);

	return basicColor;
}