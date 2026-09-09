// The interference field shared by the vertex and fragment shaders.
//   - the fragment shader colours the surface with it
//   - the vertex shader displaces the surface along the normal with it

// Hash a 3D position to a deterministic value in [0, 1].
float random3D(vec3 p) {
    return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// 3D value noise: random values at the eight lattice corners around p,
// blended with Perlin's fade curve so the result is smooth.
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

    vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float x00 = mix(c000, c100, u.x);
    float x10 = mix(c010, c110, u.x);
    float x01 = mix(c001, c101, u.x);
    float x11 = mix(c011, c111, u.x);

    float y0 = mix(x00, x10, u.y);
    float y1 = mix(x01, x11, u.y);

    return mix(y0, y1, u.z);
}

// Fractional Brownian motion: five octaves of value noise, each at double
// the frequency and half the amplitude, so detail appears at several scales.
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

// Domain warp offset, added to p before the waves read it: the medium the
// waves cross is uneven, so their fronts bend.
//   - three fBM samples at different offsets make an uncorrelated vector
//   - minus 0.5 centres fBM's [0, 1] output so there is no net shift
//   - warping the input keeps the nodal lines sharp; noise on the output
//     would only dirty them
vec3 fbmWarp(vec3 p) {
    const float warpFreq = 1.5;
    return vec3(fbm(p * warpFreq),
                fbm(p * warpFreq + 17.0),
                fbm(p * warpFreq + 43.0)) - 0.5;
}

// Superpose N plane waves at q, each sin(k * dot(q, d) - t).
//   - dot(q, d) is the distance along d, so wavefronts are planes normal to d
//   - k is the spatial frequency
//   - q is in object space, so the pattern crosses cube edges without a seam
// Returns vec2(f, env):
//   - f: the averaged field in [-1, 1], near zero where the waves cancel
//   - env: the amplitude with the oscillation removed, sqrt(sin^2 + cos^2);
//     it stays put while the fringes flow through it
vec2 waveSum(vec3 q, float k, float t) {
    const int N = 5;
    float sum = 0.0;
    float sumC = 0.0;

    for (int i = 0; i < N; i++) {
        // Fibonacci sphere: y steps evenly from 1 to -1, theta advances by
        // the golden angle, so the N directions spread evenly over the sphere.
        float y = 1.0 - 2.0 * (float(i) + 0.5) / float(N);
        float r = sqrt(1.0 - y * y);
        float theta = float(i) * 2.39996;

        vec3 d = vec3(r * cos(theta), y, r * sin(theta));
        float phase = k * dot(q, d) - t;
        sum += sin(phase);
        sumC += cos(phase);
    }

    float f = sum / float(N);
    float env = sqrt(sum * sum + sumC * sumC) / float(N);
    return vec2(f, env);
}
