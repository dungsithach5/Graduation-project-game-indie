shader_type sky;

uniform vec4 sky_color : source_color = vec4(0.05, 0.07, 0.12, 1.0);
uniform vec4 cloud_color : source_color = vec4(0.10, 0.14, 0.22, 1.0);
uniform float cloud_density : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_speed : hint_range(0.0, 0.1) = 0.005;

// Bộ tạo nhiễu 2D ngẫu nhiên để vẽ mây
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    mat2 rot = mat2(vec2(cos(0.5), sin(0.5)), vec2(-sin(0.5), cos(0.5)));
    for (int i = 0; i < 4; ++i) {
        v += a * noise(p);
        p = rot * p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void sky() {
    vec3 eye_dir = EYEDIR;
    
    if (eye_dir.y > -0.1) {
        vec2 sky_uv = eye_dir.xz / (eye_dir.y + 0.05);
        sky_uv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.7);
        float n = fbm(sky_uv * 0.25);
        
        float threshold_low = 0.4 - cloud_density * 0.3;
        float threshold_high = 0.8 - cloud_density * 0.3;
        float cloud_mask = smoothstep(threshold_low, threshold_high, n);
        
        float horizon_fade = smoothstep(-0.05, 0.15, eye_dir.y);
        cloud_mask *= horizon_fade;
        
        vec3 final_color = mix(sky_color.rgb, cloud_color.rgb, cloud_mask);
        COLOR = final_color;
    } else {
        COLOR = sky_color.rgb;
    }
}
