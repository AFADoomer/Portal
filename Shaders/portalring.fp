// Random amplitude strip - used for portal ring effect
// Modified from http://glslsandbox.com/e#47902.0

#extension GL_OES_standard_derivatives : enable

vec3 permute(vec3 x) { return mod(((x*34.0)+1.0)*x, 289.0); }

float parabola( float x, float k )
{
	return pow( 4.0*x*(1.0-x), k );
}

float snoise(vec2 v){
	const vec4 C = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
	vec2 i	= floor(v + dot(v, C.yy) );
	vec2 x0 = v - i + dot(i, C.xx);
	vec2 i1;
	i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;
	i = mod(i, 289.0);
	vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
	+ i.x + vec3(0.0, i1.x, 1.0 ));
	vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
	m = m*m ;
	m = m*m ;
	vec3 x = 2.0 * fract(p * C.www) - 1.0;
	vec3 h = abs(x) - 0.5;
	vec3 ox = floor(x + 0.5);
	vec3 a0 = x - ox;
	m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
	vec3 g;
	g.x = a0.x * x0.x + h.x * x0.y;
	g.yz = a0.yz * x12.xz + h.yz * x12.yw;
	return 130.0 * dot(m, g);
}

vec4 Flames()
{
	vec2 texCoord = vTexCoord.st;

	if (texCoord.y < 0.5)
	{ // The func_warp1 algorithm
		const float pi = 3.14159265358979323846;
		vec2 offset = vec2(0.0,0.0);

		offset.y = sin(pi * 2.0 * (texCoord.x + timer * 0.125)) * 0.1;
		offset.x = sin(pi * 2.0 * (texCoord.y + timer * 0.125)) * 0.1;

		texCoord += offset * 0.1;
	}

	vec4 basicColor = getTexel(texCoord);

	vec2 thicknessNoiseSample = texCoord * vec2(1., 1.) + vec2(timer * 1., 0.);
	float thicknessNoise = snoise(thicknessNoiseSample) * 0.5 * 20;
	
	vec2 offsetNoiseSample = texCoord * vec2(1., 1.) + vec2(timer * 2., 0.);
	float offsetNoise = snoise(offsetNoiseSample) * 0.25;

	vec4 blend = vec4(parabola(texCoord.y + offsetNoise, 0.5 + pow(thicknessNoise, 2.)));

	if (texCoord.x < 0.25)
	{
		blend *= texCoord.x / 0.25;
	}
	else if (texCoord.x > 15.75)
	{
		blend *= (16.0 - texCoord.x) / 0.25;
	}

 	if (texCoord.y > 0.6) { blend = vec4( 255, 255, 255, 1.0); } // Fill the bottom half of the texture
	else if (texCoord.y > 0.5) { blend += vec4( 255, 255, 255, (texCoord.y - 0.5) / 0.1); }

	blend *= smoothstep(1.0, 0.5, 1.0 - texCoord.y);

	return vec4(basicColor.rgb, clamp(blend.a, 0.0, 1.0));
}

int imod(int a, int b)
{
    return (a - (b * (a/b)));
}

// Perlin fall modified from https://www.shadertoy.com/view/wllGzB and http://glslsandbox.com/e#64546.0
vec4 PerlinFall()
{
	vec2 texCoord = vTexCoord.st;
	vec4 basicColor = getTexel(texCoord);

	vec2 R = vec2(1., 1.), P, D, U = texCoord / R.y, V = 15. * U; 
	V.y += timer;
	float p = 0.;
	
	for (int k=0; k<9; k++)					// neigborhood
		P = vec2(imod(k,3)-1,k/3-1),			// cur. cell 
		D = fract(1e4*sin(ceil(V-P)*mat2(R.xyyx)))-.5,	// node = random offset in cell
		P = fract(V) -.5 + P + D,			// node rel. coords
		p += smoothstep( 1.3*U.y,0.,length(P) );	// its potential

  	p = sqrt(p);
	p = (p -.5) / fwidth(p);

	return vec4(basicColor.rgb, clamp(p, 0.0, 1.0));
}

vec4 ProcessTexel()
{
	return Flames();
}