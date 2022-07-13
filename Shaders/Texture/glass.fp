// From https://forum.zdoom.org/viewtopic.php?f=124&t=61298&p=1063865&hilit=shiny+shader#p1063865
// Original by Marisa Kirisame
// Adapted to Material Shader by and otherwise modified by AFADoomer

#define amt 0.125

Material ProcessMaterial()
{
	vec2 texCoord = vTexCoord.st;
	vec4 color = getTexel(texCoord);

	vec3 eyedir = normalize(uCameraPos.xyz - pixelpos.xyz);
	vec3 norm = reflect(eyedir, normalize(vWorldNormal.xyz));

	Material material;
#if defined(reflection)
	material.Base = color + texture(reflection, vec2(pow(norm.x, 1.0 / amt), norm.z)) * (1.0 - texCoord.y) * amt;
//	material.Base = color + texture(reflection, vec2(pow(norm.x, 1.0 / amt), norm.z)) * mod(1.0 - texCoord.y, 1.0) * 10.0 * amt;
//	material.Base = color + texture(reflection, vec2(1.0, 1.0) - texCoord) * mod(1.0 - texCoord.y, 1.0) * 10.0 * amt;
//	material.Base = color + texture(reflection, vec2(1.0, 1.0) - texCoord) * mod(1.0 - texCoord.y, 1.0) * 10.0 * amt;
#else
	material.Base = color + getTexel(norm.xz * 0.5) * 0.0625 * amt;
#endif
	material.Normal = ApplyNormalMap(texCoord);
	material.Specular = texture(speculartexture, texCoord).rgb;
	material.Glossiness = uSpecularMaterial.x;
	material.SpecularLevel = uSpecularMaterial.y;

	material.Bright = texture(brighttexture, texCoord);

	return material;
}