// Custom water shader integrated with parallax shader from https://forum.zdoom.org/viewtopic.php?f=103&t=62104

 #define RELIEF_PARALLAX
// #define NORMAL_PARALLAX

mat3 GetTBN();
vec3 GetBumpedNormal(mat3 tbn, vec2 texcoord);
vec2 ParallaxMap(mat3 tbn);

const float pi = 3.14159265358979323846;

vec2 GetRippleOffset(vec2 texCoord)
{
	vec2 offset;

	offset.x = 0.005 * cos(timer + 200.0 * texCoord.y);
	offset.y = 0.05 * cos(timer + 50.0 * texCoord.y);

	return offset;
}

vec2 GetWarpOffset(vec2 texCoord)
{
	vec2 offset;
	const float pi = 3.14159265358979323846;

/*
	// This is basically the old warp2 shader - secondary image is used as a very subdued background warp
	offset.y = 0.5 + sin(pi * 2.0 * (texCoord.y + timer * 0.15 + 900.0/8192.0)) + sin(pi * 2.0 * (texCoord.x * 2.0 + timer * 0.15 + 300.0/8192.0));
	offset.x = 0.5 + sin(pi * 2.0 * (texCoord.y + timer * 0.125 + 700.0/8192.0)) + sin(pi * 2.0 * (texCoord.x * 2.0 + timer * 0.125 + 1200.0/8192.0));

	offset *= 0.25;
*/
	// This is basically the old warp3 shader - secondary image is used as a subdued overlay warp that catches attenuated lights
	float siny = sin(pi * 2.0 * (texCoord.y * 2.0 + timer * 0.75)) * 0.03;
	offset.y = siny + sin(pi * 2.0 * (texCoord.x + timer * 0.75)) * 0.03;
	offset.x = siny + sin(pi * 2.0 * (texCoord.x + timer * 0.45)) * 0.02;

	offset *= 0.05;

	return offset;
}

Material ProcessMaterial()
{
	mat3 tbn = GetTBN();
	vec2 texCoord = ParallaxMap(tbn);
//	vec2 texCoord = vTexCoord.st;
	vec2 rippleoffset = GetRippleOffset(texCoord);
	vec2 warpoffset = GetWarpOffset(texCoord);

	Material material;
	material.Base = getTexel(texCoord + rippleoffset) * 0.85 + texture(background, vTexCoord.st + warpoffset) * 0.08;
	material.Normal = GetBumpedNormal(tbn, texCoord + rippleoffset);
//	material.Normal = ApplyNormalMap(texCoord + rippleoffset);
#if defined(SPECULAR)
	material.Specular = (texture(speculartexture, texCoord + rippleoffset).rgb + texture(background, vTexCoord.st + warpoffset).rgb) / 2;
	material.Glossiness = uSpecularMaterial.x;
	material.SpecularLevel = uSpecularMaterial.y;
#endif
#if defined(PBR)
	material.Metallic = texture(metallictexture, texCoord).r;
	material.Roughness = texture(roughnesstexture, texCoord).r;
	material.AO = texture(aotexture, texCoord).r;
#endif
#if defined(BRIGHTMAP)
	material.Bright = texture(brighttexture, texCoord);
#endif
	return material;
}

// Tangent/bitangent/normal space to world space transform matrix
mat3 GetTBN()
{
    vec3 n = normalize(vWorldNormal.xyz);
    vec3 p = pixelpos.xyz;
    vec2 uv = GetRippleOffset(vTexCoord.st); //vTexCoord.st;

    // get edge vectors of the pixel triangle
    vec3 dp1 = dFdx(p);
    vec3 dp2 = dFdy(p);
    vec2 duv1 = dFdx(uv);
    vec2 duv2 = dFdy(uv);

    // solve the linear system
    vec3 dp2perp = cross(n, dp2); // cross(dp2, n);
    vec3 dp1perp = cross(dp1, n); // cross(n, dp1);
    vec3 t = dp2perp * duv1.x + dp1perp * duv2.x;
    vec3 b = dp2perp * duv1.y + dp1perp * duv2.y;

    // construct a scale-invariant frame
    float invmax = inversesqrt(max(dot(t,t), dot(b,b)));
    return mat3(t * invmax, b * invmax, n);
}

vec3 GetBumpedNormal(mat3 tbn, vec2 texcoord)
{
#if defined(NORMALMAP)
    vec3 map = texture(normaltexture, texcoord).xyz;
    map = map * 255./127. - 128./127.; // Math so "odd" because 0.5 cannot be precisely described in an unsigned format
    map.xy *= vec2(0.5, -0.5); // Make normal map less strong and flip Y
    return normalize(tbn * map);
#else
    return normalize(vWorldNormal.xyz);
#endif
}

float GetDisplacementAt(vec2 currentTexCoords)
{
    return 0.5 - texture(displacement, currentTexCoords).r;
}

#if defined(NORMAL_PARALLAX)
vec2 ParallaxMap(mat3 tbn)
{
    const float parallaxScale = 0.5;

    // Calculate fragment view direction in tangent space
    mat3 invTBN = transpose(tbn);
    vec3 V = normalize(clamp(0.0, 1.0)(invTBN * (uCameraPos.xyz - pixelpos.xyz));

    vec2 texCoords = vTexCoord.st;
    vec2 p = V.xy / abs(V.z) * GetDisplacementAt(texCoords) * parallaxScale;
    return texCoords - p;
}

#elif defined(RELIEF_PARALLAX)
vec2 ParallaxMap(mat3 tbn)
{
    const float parallaxScale = 0.4;
    const float minLayers = 12.0;
    const float maxLayers = 16.0;

    // Calculate fragment view direction in tangent space
    mat3 invTBN = transpose(tbn);
    vec3 V = normalize(invTBN * (uCameraPos.xyz - pixelpos.xyz));
    vec2 T = vTexCoord.st;

    float numLayers = mix(maxLayers, minLayers, clamp(V.z, -1.0, 1.0)); // clamp is required due to precision loss

    // calculate the size of each layer
    float layerDepth = 1.0 / numLayers;

    // depth of current layer
    float currentLayerDepth = 0.0;

    // the amount to shift the texture coordinates per layer (from vector P)
    vec2 P = V.xy * parallaxScale;
    vec2 deltaTexCoords = P / numLayers;
    vec2 currentTexCoords = T + (P * 0.07);
    float currentDepthMapValue = GetDisplacementAt(currentTexCoords);

    while (currentLayerDepth < currentDepthMapValue)
    {
        // shift texture coordinates along direction of P
        currentTexCoords -= deltaTexCoords;

        // get depthmap value at current texture coordinates
        currentDepthMapValue = GetDisplacementAt(currentTexCoords);

        // get depth of next layer
        currentLayerDepth += layerDepth;
    }


	deltaTexCoords *= 0.5;
	layerDepth *= 0.5;

	currentTexCoords += deltaTexCoords;
	currentLayerDepth -= layerDepth;


	const int _reliefSteps = 14;
	int currentStep = _reliefSteps;
	while (currentStep > 0) {
	float currentGetDisplacementAt = GetDisplacementAt(currentTexCoords);
		deltaTexCoords *= 0.5;
		layerDepth *= 0.5;


		if (currentGetDisplacementAt > currentLayerDepth) {
			currentTexCoords -= deltaTexCoords;
			currentLayerDepth += layerDepth;
		}

		else {
			currentTexCoords += deltaTexCoords;
			currentLayerDepth -= layerDepth;
		}
		currentStep--;
	}

	return currentTexCoords - (P * 0.01);
}

#endif