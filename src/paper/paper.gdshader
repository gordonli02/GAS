// Paper: flat shaded (face normals), lit plus a strong self-light so print stays readable,
// like the web build's emissive 0.62. The flap's inner face uses back_tex.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D front_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D back_tex : source_color, filter_nearest, repeat_disable;
uniform bool has_back = false;
uniform float self_light = 0.62;

void fragment() {
	// Face normal from screen-space derivatives, turned to face the camera.
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VERTEX) > 0.0) {
		n = -n;
	}
	NORMAL = n;
	vec3 c = (FRONT_FACING || !has_back) ? texture(front_tex, UV).rgb : texture(back_tex, UV).rgb;
	ALBEDO = c;
	EMISSION = c * self_light;
	ROUGHNESS = 1.0;
}
