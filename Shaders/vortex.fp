// Adapted from https://www.shadertoy.com/view/Ml2GDR

uniform float timer;

const vec2 NE = vec2(0.05,0.0);
const vec4 waterColor = vec4(0.5, 0.0, 0.0, 1.0);
vec3 lightDir = normalize(vec3(10.0,15.0,5.0));

float height(in vec2 uv)
{
    return getTexel(uv).b*texture(displacement, uv+vec2(0.0,timer*0.1)).b;
}

vec3 normal(in vec2 uv)
{
    return normalize(vec3(height(uv+NE.xy)-height(uv-NE.xy),
                          0.0,
                          height(uv+NE.yx)-height(uv-NE.yx)));
}

vec4 Process(vec4 color)
{
	vec2 uv = gl_TexCoord[0].st - 0.5;

    float dist = length(uv);
    float angle = atan(uv.y,uv.x);
    
    vec2 ruv = uv;
    uv = vec2(cos(angle-dist*3.),dist-(timer*0.2));

    vec3 norm = normal(uv);
	// return mix(vec4(0.), mix(getTexel(uv), getTexel(norm.xz*0.5+0.5), 0.3), min(5.,length(ruv)*10.)); 
	return  mix(vec4(0.), mix(mix(waterColor+waterColor*max(0.0,dot(lightDir,norm))*0.1,
       		getTexel(uv),0.5),
            getTexel(norm.xz*0.5+0.5),0.3),min(5.,length(ruv)*10.));
}