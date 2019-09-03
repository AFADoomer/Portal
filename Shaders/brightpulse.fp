vec4 ProcessTexel()
{
	vec2 texCoord = vTexCoord.st;

	const float pi = 3.14159265358979323846;

	texCoord.x += sin(pi * 2.0 * (texCoord.x + timer * 0.125)) * 0.5;

	return getTexel(texCoord);
}

vec4 ProcessLight(vec4 color)
{
	vec4 brightpix = desaturate(vec4(255, 255, 255, 255));
	return vec4(min (color.rgb + brightpix.rgb, 1.0), color.a);
}

