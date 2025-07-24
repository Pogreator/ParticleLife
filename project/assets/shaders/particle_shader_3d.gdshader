shader_type particles;

uniform sampler2D particle_data;
uniform float scale = 0.25;
uniform vec4 colors[100];

void process() {
	ivec2 pos_image_size = textureSize(particle_data,0);

	ivec2 texel_pos = ivec2(int(mod(float(INDEX),float(pos_image_size.x))),
							int(float(INDEX)/float(pos_image_size.x)));

	vec4 particle_pos_type = texelFetch(particle_data, texel_pos, 0);

	COLOR = colors[int(particle_pos_type.a)];

	TRANSFORM[0].x = scale;
	TRANSFORM[1].y = scale;
	TRANSFORM[2].z = scale;

	TRANSFORM[3].xyz = vec3(particle_pos_type.r,particle_pos_type.g,particle_pos_type.b);
}