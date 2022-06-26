vec4 texture_bilinear(in sampler2D t, in vec2 uv, in vec2 textureSize);
vec4 SimSun(vec3 lightDir, vec3 normal);

// Modified by AFADoomer
//  from http://johnsietsma.com/2015/12/01/flow-maps/
//  with reference to https://steamcdn-a.akamaihd.net/apps/valve/2010/siggraph2010_vlachos_waterflow.pdf
Material ProcessMaterial()
{
	vec2 texCoord = vTexCoord.st;

	vec2 texresolution = textureSize(tex, 0);
	vec2 mapresolution = textureSize(flowmap, 0);

	// Scale the effect based on the resolution of the base texture and the flow map
	float scale = (256.0 / texresolution.x) * 0.125;

	// Look up the flow direction from the flow map
	// Offset and scale the coordinates so that a flow map will be centered at 0, 0
	vec2 samplecoord = texCoord * scale + vec2(0.5, 0.5);

	// Take a bilinear sample of the flow map to eliminate pixellation in the effect and allow using lower-resolution maps
	vec4 flowsample = texture_bilinear(flowmap, samplecoord, mapresolution);

	// Direction vector is stored in red and green channels of map
	vec2 flowDirection = (flowsample.rg - 0.5) * 2.0;
	float flowspeed = clamp(length(flowDirection), 0.0, 1.0);
/*
	// Get a noise sample (grayscale noise texture "Textures/Shader/Noise.png" passed into shader)
	// Unused!  Intended for use in reducing visibility of pixellation in overlay transition
	float noisesample = texture(noise, samplecoord).r;
	noisesample = abs(noisesample - 0.5) * 2.0;
*/
	// Use two cycles, offset by a half so we can blend between them
	// Allows the image to smoothly animate without visible resetting or distortion
	float t1 = timer / 20.0;
	float t2 = t1 + 0.5;
	float cycleTime1 = t1 - floor(t1);
	float cycleTime2 = t2 - floor(t2);

	// Calculate a phase variable for blending the two samples
	float phase = abs(cycleTime1 - 0.5) * 2.0;

	// Calculate the offset coordinates for the two overlay samples
	vec2 flowcoord1 = texCoord + flowDirection * cycleTime1;
	vec2 flowcoord2 = texCoord + flowDirection * cycleTime2;

	Material material;

	// Pull the base color from the 'color' texture

	// Sample across the texture.  This allows for colors to shift if you want...
	// vec4 color1 = texture(color, flowcoord1);
	// vec4 color2 = texture(color, flowcoord2);
	// material.Base = mix(color1, color2, phase);

	// Sample in one spot to get a base color
	material.Base = texture(color, vec2(0.5, 0.5));

	// Overlay base texture for surface texture and debris effect
	vec4 foamcolor1 = getTexel(texCoord + flowDirection * (cycleTime1 - 0.5) * flowspeed); // Foam moves more in faster water
	vec4 foamcolor2 = getTexel(texCoord + flowDirection * (cycleTime2 - 0.5) * flowspeed); // Also uses offset cycle time for less distortion
	vec4 foammixed = mix(foamcolor1, foamcolor2, phase);
	float flowvisibility = pow(0.25 + (1.0 - flowspeed) * 0.75, 2) / 2;
	material.Base = mix(material.Base, foammixed, flowvisibility); // Foam is less visible in faster water

	// Normal map is dynamically altered based on the direction and speed of movement
	vec3 normal1 = ApplyNormalMap(flowcoord1) * (1.0 - phase);
	normal1.z *= flowspeed * 2.0;
	vec3 normal2 = ApplyNormalMap(flowcoord2) * phase;
	normal2.z *= flowspeed * 2.0;
	vec3 normalmix = normalize(normal1 + normal2);
	material.Normal = 1.1 * normalmix; // Slightly overbright so that the bright spots blend together

	// Add a small amount of fake ambient lighting
	material.Base = mix(material.Base, SimSun(vec3(0.75, -1.0, -0.5), material.Normal), 0.075);

#if defined(SPECULAR)
	// Specular sampling mirrors the base texture sampling
	vec4 specular1 = texture(speculartexture, flowcoord1);
	vec4 specular2 = texture(speculartexture, flowcoord2);
	material.Specular = mix(specular1, specular2, phase).rgb;
	material.Glossiness = uSpecularMaterial.x;
	material.SpecularLevel = uSpecularMaterial.y;
#endif

#if defined(BRIGHTMAP)
	vec4 bright1 = texture(brighttexture, flowcoord1);
	vec4 bright2 = texture(brighttexture, flowcoord2);
	material.Bright = mix(bright1, bright2, phase);
#endif

/* Debug */
	//  Overlay the flow map image
	// material.Base = mix(material.Base, flowsample, 0.25);

	//  Overlay red, amount based on flow speed for that point
	// material.Base = mix(material.Base, vec4(flowspeed, 0, 0, 1.0), 0.25);

	//  Overlay green, amount based on flow visibility for that point
	// material.Base = mix(material.Base, vec4(0, flowvisibility, 0, 1.0), 0.25);

	//  Overlay blue, amount based on noise sample for that point
	// material.Base = mix(material.Base, vec4(0, 0, noisesample, 1.0), 0.25);
/*********/

	return material;
}

// Modified by AFADoomer from peterfilm and sashley at https://community.khronos.org/t/manual-bilinear-filter/58504
vec4 texture_bilinear(in sampler2D t, in vec2 uv, in vec2 textureSize)
{
	vec2 texelSize = 1.0 / textureSize;

	vec2 f = fract( uv * textureSize );
	uv += ( 0.5 - f ) * texelSize;

	vec4 tl = texture(t, uv);
	vec4 tr = texture(t, uv + vec2(texelSize.x, 0.0));
	vec4 bl = texture(t, uv + vec2(0.0, texelSize.y));
	vec4 br = texture(t, uv + vec2(texelSize.x, texelSize.y));

	vec4 tA = mix( tl, tr, f.x );
	vec4 tB = mix( bl, br, f.x );

	return mix( tA, tB, f.y );
}

// Modified by AFADoomer from Cherno's SimSun shader at https://forum.zdoom.org/viewtopic.php?f=103&t=67183
//  Function takes two parameters: light direction and the texture's normal
//  Used to apply ambient light effect to liquids, even when there are no dynamic lights around
const float pi = 3.14159265359;
vec4 SimSun(vec3 l, vec3 normal)
{
   vec3 n = normalize(vWorldNormal.xyz - normal);

   float angle = acos
   (
      (l.x*n.x + l.y*n.y + l.z * n.z)
      /
      (
         (   
            sqrt
            (
               (l.x*l.x)+(l.y*l.y)+(l.z*l.z)
            )
            *
            sqrt
            (
               (n.x*n.x) + (n.y*n.y) + (n.z*n.z)
            )
         )
      )
   );

   float lightLevel = angle / pi;

   return vec4(lightLevel, lightLevel, lightLevel, 1.0);
}