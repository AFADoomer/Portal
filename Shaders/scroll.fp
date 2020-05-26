// Simple vertical scroll shader by AFADoomer
//  with additional handling for the annoying seam line between the bottom and top of every texture processed by GZDoom...

vec4 Process(vec4 color)
{
	vec2 texCoord = vTexCoord.st;
	vec2 texSize = textureSize(tex, 0);
	vec2 texelSize = 1.0 / texSize;

	texCoord.y = mod(texCoord.y + timer * 0.75, 1.0);

	// Hacky patching because of the obnoxious seam...  Not perfect, but better than having an unstable line.
	float min = texelSize.y * 0.25;
	if (texCoord.y <= min || texCoord.y >= 1.0 - min) { return getTexel(vec2(texCoord.x, texelSize.y - min / 2)); }

	return getTexel(texCoord);
}