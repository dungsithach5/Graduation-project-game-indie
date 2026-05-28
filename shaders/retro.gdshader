// Fear to Fathom style shader: VHS Analog look, radial chromatic aberration, head-switching noise, shadow lift, and custom scanlines.

shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap, repeat_enable;

// General & Grain
uniform float grain_intensity : hint_range(0.0, 1.0) = 0.08;
uniform float min_lum : hint_range(0.0, 1.0) = 0.0;
uniform float max_lum : hint_range(0.0, 1.0) = 1.0;
uniform float time_scale : hint_range(0.0, 1.0) = 0.5;

// Vignette
uniform float vignette_darkness : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_outer_radius : hint_range(0.1, 2.0) = 0.8;
uniform float vignette_inner_radius : hint_range(0.0, 1.9) = 0.3;

// CRT & Distortion
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.12;
uniform float scanline_count : hint_range(100.0, 1000.0) = 480.0;
uniform float barrel_distortion : hint_range(0.0, 0.5) = 0.08;
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.008;
uniform float crt_vignette_power : hint_range(0.0, 5.0) = 2.5; 

// Pixelation & Quantization (PSX styles disabled by default for FtF style)
uniform bool enable_pixelation = false;
uniform int pixel_resolution_x : hint_range(32, 1920) = 640;
uniform int pixel_resolution_y : hint_range(24, 1080) = 480;
uniform bool enable_color_quantization = false;
uniform float color_quant_steps : hint_range(2.0, 64.0) = 32.0;

// VHS Tracking / Jitter
uniform float warble_amount : hint_range(0.0, 0.01) = 0.001;
uniform float warble_speed : hint_range(0.0, 10.0) = 4.0;
uniform float vhs_jitter_amount : hint_range(0.0, 0.05) = 0.002;
uniform float vhs_jitter_speed : hint_range(0.0, 20.0) = 12.0;
uniform float head_switching_noise : hint_range(0.0, 0.2) = 0.08;
uniform float composite_blur : hint_range(0.0, 5.0) = 0.6;

// Color Grading & Saturation
uniform float saturation : hint_range(0.0, 2.0) = 0.82;
uniform float contrast : hint_range(0.5, 2.0) = 1.08;
uniform float shadow_lift : hint_range(0.0, 0.2) = 0.04;


float noise(vec2 p) {
    return (fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 2.0;
}

vec3 soft_light(vec3 A, vec3 B) {
    vec3 branch1 = 2.0 * A * B + A * A * (1.0 - 2.0 * B);
    vec3 branch2 = 2.0 * A * (1.0 - B) + sqrt(A) * (2.0 * B - 1.0);
    vec3 condition = step(0.5, B);
    return mix(branch1, branch2, condition);
}

vec3 quantize_color(vec3 color, float steps) {
    return floor(color * steps) / steps;
}


void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
    
    // 1. VHS Horizontal Sync Jitter
    float time_val = TIME * vhs_jitter_speed;
    float jitter_mask = step(0.88, noise(vec2(floor(uv.y * 45.0), TIME * 0.1)));
    float line_jitter = noise(vec2(TIME * vhs_jitter_speed, floor(uv.y * 120.0))) * vhs_jitter_amount;
    
    vec2 sample_uv = uv;
    sample_uv.x += line_jitter * jitter_mask;
    
    // Periodic VHS wobble/warble distortion (runs every 6.0 seconds for a 1.5-second burst)
    float warble_cycle = mod(TIME, 6.0);
    float warble_mask = smoothstep(0.0, 0.3, warble_cycle) * (1.0 - smoothstep(1.2, 1.5, warble_cycle));
    sample_uv.x += sin(uv.y * 12.0 + TIME * warble_speed) * warble_amount * warble_mask;

    // 2. VHS Bottom Head-Switching Noise & Tearing
    float bottom_y = 1.0 - sample_uv.y;
    float noise_bound = 0.025 + noise(vec2(TIME * 5.0, 0.0)) * 0.005;
    bool is_bottom_noise = bottom_y < noise_bound;
    
    if (is_bottom_noise) {
        float factor = (noise_bound - bottom_y) / noise_bound;
        // Warp lines horizontally near the bottom
        sample_uv.x += sin(bottom_y * 130.0 + TIME * 10.0) * factor * head_switching_noise * 0.2;
        // Jitter the horizontal line even more at the bottom
        sample_uv.x += noise(vec2(bottom_y, TIME * 40.0)) * factor * head_switching_noise * 0.1;
    }

    // 3. Pixelation (Disabled by default, but kept for compatibility)
    if (enable_pixelation) {
        sample_uv = floor(sample_uv * vec2(float(pixel_resolution_x), float(pixel_resolution_y))) 
                  / vec2(float(pixel_resolution_x), float(pixel_resolution_y));
    }

    // 4. Lens / Barrel Distortion
    vec2 center_uv = sample_uv - 0.5;
    float r2 = dot(center_uv, center_uv);
    vec2 distorted_uv = center_uv * (1.0 + barrel_distortion * r2);
    distorted_uv += 0.5;

    // Outer edge vignette / bounds clipping
    if (distorted_uv.x < 0.0 || distorted_uv.x > 1.0 || distorted_uv.y < 0.0 || distorted_uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        vec3 col;
        vec2 radial_dir = distorted_uv - 0.5;

        // 5. Radial Chromatic Aberration & Softness Blending
        if (composite_blur > 0.0) {
            float blur_size = composite_blur * 0.001;
            
            // Left sample
            vec3 col_l;
            col_l.r = texture(SCREEN_TEXTURE, distorted_uv - vec2(blur_size, 0.0) + radial_dir * chromatic_aberration).r;
            col_l.g = texture(SCREEN_TEXTURE, distorted_uv - vec2(blur_size, 0.0)).g;
            col_l.b = texture(SCREEN_TEXTURE, distorted_uv - vec2(blur_size, 0.0) - radial_dir * chromatic_aberration).b;
            
            // Center sample
            vec3 col_c;
            col_c.r = texture(SCREEN_TEXTURE, distorted_uv + radial_dir * chromatic_aberration).r;
            col_c.g = texture(SCREEN_TEXTURE, distorted_uv).g;
            col_c.b = texture(SCREEN_TEXTURE, distorted_uv - radial_dir * chromatic_aberration).b;
            
            // Right sample
            vec3 col_r;
            col_r.r = texture(SCREEN_TEXTURE, distorted_uv + vec2(blur_size, 0.0) + radial_dir * chromatic_aberration).r;
            col_r.g = texture(SCREEN_TEXTURE, distorted_uv + vec2(blur_size, 0.0)).g;
            col_r.b = texture(SCREEN_TEXTURE, distorted_uv + vec2(blur_size, 0.0) - radial_dir * chromatic_aberration).b;
            
            col = (col_l + col_c * 2.0 + col_r) * 0.25;
        } else {
            col.r = texture(SCREEN_TEXTURE, distorted_uv + radial_dir * chromatic_aberration).r;
            col.g = texture(SCREEN_TEXTURE, distorted_uv).g;
            col.b = texture(SCREEN_TEXTURE, distorted_uv - radial_dir * chromatic_aberration).b;
        }

        // Apply VHS bottom tape static lines
        if (is_bottom_noise) {
            float tape_static = noise(vec2(distorted_uv.x * 350.0 + TIME * 80.0, distorted_uv.y * 950.0));
            if (tape_static > 0.1) {
                float factor = (noise_bound - bottom_y) / noise_bound;
                col = mix(col, vec3(tape_static * 0.7 + 0.3), factor * 0.85);
            }
        }

        vec3 processed_color = col;

        // 6. Optional Color Quantization
        if (enable_color_quantization) {
            processed_color = quantize_color(processed_color, color_quant_steps);
        }

        // 7. Dynamic Film Grain
        float lum = dot(processed_color, vec3(0.299, 0.587, 0.114));
        float factor = 1.0 - smoothstep(min_lum, max_lum, lum);
        
        vec2 offset = vec2(sin(TIME * time_scale), cos(TIME * time_scale)) * 20.0;
        vec2 noise_uv = uv + offset; 
        
        float noise_val = noise(noise_uv);
        vec3 grain = vec3(noise_val) * grain_intensity * factor;
        
        vec3 grain_color = clamp(vec3(0.5) + grain, 0.0, 1.0);
        processed_color = soft_light(processed_color, grain_color);

        // 8. Soft Outer Vignette
        float aspect_ratio = screen_size.x / screen_size.y;
        vec2 adjusted_uv = uv - 0.5;
        adjusted_uv.x *= aspect_ratio;
        
        float inner_rad = min(vignette_inner_radius, vignette_outer_radius - 0.01);
        float dist = length(adjusted_uv); 
        float vignette_pct = smoothstep(vignette_outer_radius, inner_rad, dist);
        float vignette_factor = mix(1.0 - vignette_darkness, 1.0, vignette_pct);
        
        processed_color *= vignette_factor;

        // 9. Fine CRT Scanlines
        float scanline_alpha = sin(uv.y * scanline_count * 3.14159265 * 2.0);
        scanline_alpha = clamp(scanline_alpha * 0.5 + 0.5, 0.0, 1.0);
        scanline_alpha = 1.0 - (scanline_alpha * scanline_intensity);
        processed_color *= scanline_alpha;

        // 10. CRT Curved Vignette
        float crt_vignette = pow(1.0 - r2, crt_vignette_power);
        processed_color *= crt_vignette;

        // 11. Fear to Fathom Analog Color Grading
        // A. Saturation
        float final_luma = dot(processed_color, vec3(0.299, 0.587, 0.114));
        processed_color = mix(vec3(final_luma), processed_color, saturation);
        
        // B. Contrast
        processed_color = (processed_color - 0.5) * contrast + 0.5;
        processed_color = clamp(processed_color, 0.0, 1.0);
        
        // C. Shadow Lift (Washed-out dusty black look)
        processed_color = mix(vec3(shadow_lift), vec3(1.0), processed_color);

        COLOR = vec4(processed_color, 1.0);
    }
}