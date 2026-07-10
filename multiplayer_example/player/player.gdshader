shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;
uniform float alpha_multiplier : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec4 result = tex_color;

	if (tex_color.a < 0.5) {
		vec2 offset = TEXTURE_PIXEL_SIZE * outline_width;
		float alpha = 0.0;

		alpha += texture(TEXTURE, UV + vec2(offset.x, 0.0)).a;
		alpha += texture(TEXTURE, UV + vec2(-offset.x, 0.0)).a;
		alpha += texture(TEXTURE, UV + vec2(0.0, offset.y)).a;
		alpha += texture(TEXTURE, UV + vec2(0.0, -offset.y)).a;
		alpha += texture(TEXTURE, UV + vec2(offset.x, offset.y)).a;
		alpha += texture(TEXTURE, UV + vec2(-offset.x, offset.y)).a;
		alpha += texture(TEXTURE, UV + vec2(offset.x, -offset.y)).a;
		alpha += texture(TEXTURE, UV + vec2(-offset.x, -offset.y)).a;

		if (alpha > 0.0) {
			result = outline_color;
			result.a = 1.0;
		}
	}

	result.a *= alpha_multiplier;
	COLOR = result;
}
