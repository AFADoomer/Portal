// Fullbright x-axis wave effect, with ability to be affected by specially configured lights (0 alpha)
// by AFADoomer, with code taken from internal GZDoom shaders

const float pi = 3.14159265358979323846;
vec3 ProcessProximityLight(Material material);

void SetupMaterial(inout Material mat)
{
	vec2 texCoord = vTexCoord.st;

	// Wave in x direction (from wavex shader)
	texCoord.x += sin(pi * 2.0 * (texCoord.y + timer * 0.125)) * 0.1;

	mat.Base = getTexel(texCoord);
	mat.Normal = ApplyNormalMap(texCoord);
	mat.Specular = texture(speculartexture, texCoord).rgb;
	mat.Base += vec4(ProcessProximityLight(mat), mat.Base.a * vColor.a);
	mat.Bright = vec4(1.0);
}

vec3 proximity(int i, vec3 normal, Material material)
{
	vec4 lightpos = lights[i];

	float lightdistance = distance(lightpos.xyz, pixelpos.xyz);

	if (lightdistance <= lightpos.w)
	{
		return (1.5 + length(material.Specular)) * material.Base.rgb * (1.0 - lightdistance / lightpos.w);
	}
	else
	{
		return vec3(0.0);
	}
}

vec3 ProcessProximityLight(Material material)
{
	vec4 dynlight = uDynLightColor;
	vec3 normal = material.Normal;

	if (uLightIndex >= 0)
	{
		ivec4 lightRange = ivec4(lights[uLightIndex]) + ivec4(uLightIndex + 1);
		if (lightRange.z > lightRange.x)
		{
			// modulated lights
			for(int i=lightRange.x; i<lightRange.y; i+=4)
			{
				vec4 lightcolor = lights[i + 2];
				if (lightcolor != vec4(0.0)) { continue; }
				dynlight.rgb += proximity(i, normal, material);
			}
		}
	}

	return dynlight.rgb;
}