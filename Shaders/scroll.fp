// Simple vertical scroll shader by AFADoomer
//  with additional handling for the annoying seam line between the bottom and top of every texture processed by GZDoom...

vec4 Scroll(vec2 texCoord);

void SetupMaterial(inout Material material)
{
	vec2 texCoord = vTexCoord.st;

	material.Base = Scroll(texCoord);
	material.Normal = ApplyNormalMap(texCoord);
	material.Bright = texture(brighttexture, texCoord);

#if defined(SPECULAR)
   	material.Specular = texture(speculartexture, texCoord).rgb;
	material.Glossiness = uSpecularMaterial.x;
	material.SpecularLevel = uSpecularMaterial.y;
#endif
}

vec4 Scroll(vec2 texCoord)
{
	vec2 texSize = textureSize(tex, 0);
	vec2 texelSize = 1.0 / texSize;

	texCoord.y = mod(texCoord.y + timer * 0.75, 1.0);

	// Hacky patching because of the obnoxious seam...  Not perfect, but better than having an unstable line.
	float min = texelSize.y * 0.25;
	if (texCoord.y <= min || texCoord.y >= 1.0 - min) { return getTexel(vec2(texCoord.x, texelSize.y - min / 2)); }

	return getTexel(texCoord);
}