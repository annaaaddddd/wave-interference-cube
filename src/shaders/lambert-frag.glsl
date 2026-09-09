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

@import ./wavefield;

uniform vec4 u_Color; // The color with which to render this instance of geometry.
uniform float u_WaveFreq;
uniform float u_Time;
uniform float u_WarpAmount;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

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

        // Evaluate the shared interference field (see wavefield.glsl) at the
        // object-space position, domain-warped by fBM.
        vec3 p = fs_Pos.xyz;
        vec3 warp = fbmWarp(p);
        vec2 fe = waveSum(p + u_WarpAmount * warp, u_WaveFreq, u_Time);
        float f = fe.x;
        float env = fe.y;

        // Nodal lines are the zero set of f:
        //   - fwidth(f) is how much f changes between neighbouring pixels
        //   - abs(f) / fwidth(f) is therefore the distance to the nearest
        //     zero in pixels, so the line width is constant on screen
        //   - smoothstep fades the edge over 1.5 px to anti-alias
        float dist = abs(f) / max(fwidth(f), 1e-5);
        float line = 1.0 - smoothstep(0.0, 1.5, dist);

        // Brightness: full-contrast fringes scaled by the envelope.
        //   - equals env * (0.5 + 0.5 * f / env) with the division folded in
        //   - bright patches keep sharp fringes, dead patches darken as a whole
        float field = 0.5 * env + 0.5 * f;

        // Base colour: fBM (warp.x + 0.5) blends the GUI colour with a deeper
        // shade. u_Color is sRGB from the picker, so decode to linear first.
        vec3 colorA = pow(u_Color.rgb, vec3(2.2));
        vec3 colorB = vec3(0.0, 0.05, 0.25);
        vec3 base = mix(colorA, colorB, warp.x + 0.5);

        // White nodal lines over the shaded base, then encode linear to sRGB.
        vec3 finalColor = mix(base * field, vec3(1.0), line);
        out_Col = vec4(pow(finalColor, vec3(1.0 / 2.2)), 1.0);
}
