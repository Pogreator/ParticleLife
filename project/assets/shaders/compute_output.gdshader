shader_type canvas_item;

uniform sampler2D rendered_image : filter_nearest;
uniform float rows = 4.0;
uniform float range = 2000.0;
uniform float col_amount = 6.0;
uniform vec4 display;

void fragment() {
	vec4 data = vec4(0.);

	int i = int(floor(UV.y * rows));

	if (i == 0){
		data += vec4(texture(rendered_image,vec2((UV.x/rows),0.)).rg / range , 0., 0.);
		data += vec4(0., 0., texture(rendered_image,vec2((UV.x/rows),0.)).b / col_amount, 0.);
	}
	else if (i > 0 && UV.y < 1.0){
		data += vec4(texture(rendered_image,vec2((UV.x/rows)+float(i)/rows,0.)).rg / range, 0., 0.);
		data += vec4(0., 0., texture(rendered_image,vec2((UV.x/rows)+float(i)/rows,0.)).b / col_amount, 0.);
	}

	COLOR = (data*display) + vec4(0., 0., 0., 1.);
}
