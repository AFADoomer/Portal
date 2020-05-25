vec4 Process(vec4 color)
{
	vec2 texCoord = vTexCoord.st;
	
	texCoord.y = mod(texCoord.y + timer * 0.75, 1.0);

	return getTexel(texCoord);
}