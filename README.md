# CIS 5660 HW0 — Procedural Noise on Custom Geometry

Extends the CIS 5660 WebGL/TypeScript starter code with custom cube geometry,
an interactive material control, a procedural fragment shader built on 3D
fractional Brownian motion, and time-based non-uniform vertex deformation.

The cube's surface colour is not textured or authored. Every pixel evaluates a
noise function of its own position on the surface, so the pattern is generated
at render time and is continuous across all six faces.

**Live demo:** _TODO: link_

## Demos

| Recording | What it shows |
| --- | --- |
| [`demos/FBM+colorpicker.mp4`](demos/FBM+colorpicker.mp4) | The fBM pattern on the cube's surface, with the GUI colour picker changing the base colour underneath it |
| [`demos/vertex-deformation.mp4`](demos/vertex-deformation.mp4) | The time-driven sine deformation displacing the cube's vertices |

<!--
  GitHub will not play a repo-relative .mp4 inline: an image tag renders as a
  broken image and a <video> tag is stripped by the README sanitizer, so the
  links above open the file instead of embedding a player.

  To get inline players, drag each .mp4 into the comment box of any GitHub issue
  or pull request. GitHub uploads it and returns a
  https://github.com/user-attachments/assets/... URL, and that URL does embed.
  Paste the two URLs on their own lines here and delete the table above.
-->

_TODO: still screenshot_

## Controls

| Control | Description |
| --- | --- |
| Color Picker | Base material colour passed to the shader as `u_Color` |
| Tessellations | Subdivision level of the starter code's icosphere |
| Load Scene | Rebuilds the scene geometry |

## Setup

### Dependencies

| Package | Version |
| --- | --- |
| TypeScript | ^4.4.2 |
| Webpack | ^5.52.0 |
| glMatrix | ^3.3.0 |
| dat.GUI | ^0.7.7 |
| stats.js | ^1.0.1 |

Rendering targets **WebGL 2** with shaders written in **GLSL ES 3.00**.

```bash
npm install
```

### Running locally

Node 17 and later disable the hash algorithm Webpack 5 relies on, so the legacy
OpenSSL provider has to be enabled before starting the dev server. Without it
the build fails with `ERR_OSSL_EVP_UNSUPPORTED`.

```bash
$env:NODE_OPTIONS="--openssl-legacy-provider"
npm start
```

The development server runs at http://localhost:5660/.

## Implementation

### Custom cube geometry

`Cube` inherits from `Drawable` and builds its buffers in `create()`:
24 vertices, 24 normals, and 36 indices forming 12 triangles across 6 faces.

A cube has only 8 distinct corner positions, but each corner is stored three
times, once per face that meets there. Vertex attributes are interpolated per
vertex, not per face, so a shared corner would have to carry a single averaged
normal and the faces would shade as a smooth blob. Duplicating the position lets
each copy carry its own face normal, which is what gives the cube flat faces and
hard edges.

### Interactive colour control

A `dat.GUI` colour picker drives the material colour. dat.GUI reports RGB in
`[0, 255]`, so `main.ts` divides by 255 before building the `vec4` that is
uploaded to the `u_Color` uniform.

```
dat.GUI → controls.colorpicker → main.ts → u_Color → fragment shader
```

### Procedural fragment shader

The fragment shader implements fractional Brownian motion over 3D value noise,
built up in three layers:

- `random3D` hashes a 3D position into a pseudo-random scalar in `[0, 1]`. The
  dot product collapses the position to one number, `sin` scrambles it, and
  `fract` keeps it in range.
- `valueNoise3D` samples that hash only at the eight integer lattice corners
  surrounding a point and interpolates between them. The interpolation weights
  use Perlin's quintic fade curve, `6t⁵ - 15t⁴ + 10t³`, whose first and second
  derivatives both vanish at 0 and 1. A plain `mix` leaves visible creases along
  the lattice.
- `fbm` sums five octaves of that noise, doubling frequency and halving
  amplitude each time, so the result carries detail at several scales at once.

The noise is sampled at the vertex's **object-space** position, which is what
keeps the pattern fixed to the surface. Sampling world-space position instead
would leave the noise field stationary in the world and let the surface slide
through it.

### Animated vertex shader

`main.ts` accumulates elapsed time and uploads it to a `u_Time` uniform every
frame. The vertex shader offsets each vertex's `y` by a sine of its own `x` and
of time, so the displacement varies along the surface instead of translating the
cube as a whole.

## Data flow

**Geometry**

```
Cube.ts → positions / normals / indices → WebGL buffers
        → vertex shader → rasterization → fragment shader → screen
```

**Shader parameters**

```
main.ts controls → ShaderProgram setters → uniforms → GLSL
```

`u_Color` and `u_Time` both travel this path: `ShaderProgram` looks up each
uniform's location once at link time and exposes a typed setter, so `main.ts`
never touches a raw WebGL call.

**Position, twice**

The vertex shader passes two different positions down to the fragment shader:

| Output | Space | Used for |
| --- | --- | --- |
| `gl_Position` | clip | where the deformed geometry is drawn |
| `fs_Pos` | object | where the procedural pattern is sampled |

Keeping them separate is what lets the geometry animate while the noise stays
locked to the surface it belongs to.
