#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.
uniform float u_WaveFreq;
uniform float u_Time;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

// Generates a deterministic pseudo-random value in [0, 1]
// from a 3D input position.
//
// The dot product converts the vec3 position into one scalar,
// sin() scrambles the value, and fract() keeps only the fractional
// part so the result remains between 0 and 1.
float random3D(vec3 p) {
    return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// Generates smooth 3D value noise.
//
// Instead of sampling random values directly at every point,
// random values are generated only at the eight integer lattice
// corners surrounding p. These values are then smoothly interpolated.
float valueNoise3D(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);

    float c000 = random3D(i + vec3(0.0, 0.0, 0.0));
    float c100 = random3D(i + vec3(1.0, 0.0, 0.0));
    float c010 = random3D(i + vec3(0.0, 1.0, 0.0));
    float c110 = random3D(i + vec3(1.0, 1.0, 0.0));
    float c001 = random3D(i + vec3(0.0, 0.0, 1.0));
    float c101 = random3D(i + vec3(1.0, 0.0, 1.0));
    float c011 = random3D(i + vec3(0.0, 1.0, 1.0));
    float c111 = random3D(i + vec3(1.0, 1.0, 1.0));

    // Perlin fade interpolation weights
    vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float x00 = mix(c000, c100, u.x);
    float x10 = mix(c010, c110, u.x);
    float x01 = mix(c001, c101, u.x);
    float x11 = mix(c011, c111, u.x);

    float y0 = mix(x00, x10, u.y);
    float y1 = mix(x01, x11, u.y);

    return mix(y0, y1, u.z);
}

// Fractional Brownian Motion (FBM).
//
// FBM combines multiple layers ("octaves") of noise.
// Each octave has:
// - higher frequency -> smaller spatial details
// - lower amplitude  -> weaker contribution
//
// This produces a pattern containing multiple scales of detail.
float fbm(vec3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < 5; i++) {
        value += amplitude * valueNoise3D(p * frequency);

        frequency *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

void main()
{
    // Material base color (before shading)
        vec4 diffuseColor = u_Color;

        // Calculate the diffuse term for Lambert shading
        float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
        // Avoid negative lighting values
        // diffuseTerm = clamp(diffuseTerm, 0, 1);

        float ambientTerm = 0.2;

        float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                            //to simulate ambient lighting. This ensures that faces that are not
                                                            //lit by our point light are not completely black.

        // Original Lambert-only output:
        // out_Col = vec4(
        //     diffuseColor.rgb * lightIntensity,
        //     diffuseColor.a
        // );
        
        vec3 d = normalize(vec3(1.0, 1.0, 0.0));
        float phase = u_WaveFreq * dot(fs_Pos.xyz, d) - u_Time;
        float field = 0.5 + 0.5 * sin(phase); // remap the range to [0,1]

        vec3 finalColor = u_Color.rgb * field; 
        out_Col = vec4(finalColor, 1.0);
}
