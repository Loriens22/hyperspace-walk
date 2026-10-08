shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(0.4, 0.9, 1.0, 1.0);
uniform float energy = 2.0;
uniform float pulse = 0.0;
void fragment() { ALBEDO = color.rgb * energy * (1.0 + pulse * sin(TIME * 6.0)); }
