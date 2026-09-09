import {vec3, vec4} from 'gl-matrix';
import Drawable from '../rendering/gl/Drawable';
import {gl} from '../globals';

// One face of the cube, described as a single corner plus the two edge vectors
// that leave it. Any point on the face is then
//
//     origin + u * s + v * t        with s and t in [0, 1]
//
// which is what lets a face be walked with a pair of loops.
interface Face {
  origin: vec3;
  u: vec3;
  v: vec3;
}

// The six faces. Two invariants hold for every entry, and between them they
// pin down both the geometry and the winding:
//   * `u` and `v` lie in the face, so origin + u and origin + v are themselves
//     corners of the cube and the component along the face's axis stays fixed
//   * `cross(u, v)` points away from the cube's centre, which orients the
//     generated triangles and supplies the normal shared by the whole face
const FACES: Array<Face> = [
  // front (+Z)
  {origin: vec3.fromValues(-1, -1,  1), u: vec3.fromValues( 2, 0,  0), v: vec3.fromValues(0,  2,  0)},
  // right (+X)
  {origin: vec3.fromValues( 1, -1,  1), u: vec3.fromValues( 0, 0, -2), v: vec3.fromValues(0,  2,  0)},
  // back (-Z)
  {origin: vec3.fromValues( 1, -1, -1), u: vec3.fromValues(-2, 0,  0), v: vec3.fromValues(0,  2,  0)},
  // left (-X)
  {origin: vec3.fromValues(-1, -1, -1), u: vec3.fromValues( 0, 0,  2), v: vec3.fromValues(0,  2,  0)},
  // top (+Y)
  {origin: vec3.fromValues(-1,  1,  1), u: vec3.fromValues( 2, 0,  0), v: vec3.fromValues(0,  0, -2)},
  // bottom (-Y)
  {origin: vec3.fromValues(-1, -1, -1), u: vec3.fromValues( 2, 0,  0), v: vec3.fromValues(0,  0,  2)},
];

// A cube whose faces are tessellated into a grid rather than drawn as two
// triangles each, so that a vertex shader displacement has enough sample
// points to read as a wave across the surface instead of tilting the face.
class Cube extends Drawable {
  indices: Uint32Array;
  positions: Float32Array;
  normals: Float32Array;
  center: vec4;

  // `subdivisions` is how many pieces each face edge is cut into, and must be a
  // positive integer. At 1 the result is the plain 24-vertex cube.
  constructor(center: vec3, public subdivisions: number = 1) {
    super();
    this.center = vec4.fromValues(center[0], center[1], center[2], 1);
  }

  create() {
    const n = this.subdivisions;

    const positions: Array<number> = [];
    const normals: Array<number> = [];
    const indices: Array<number> = [];

    for (let f = 0; f < FACES.length; f++) {
      const face = FACES[f];

      // The face's outward normal, shared by all of its vertices. Storing one
      // normal per face rather than averaging at the shared corners is what
      // gives the cube flat faces and hard edges.
      const normal = vec3.create();
      vec3.cross(normal, face.u, face.v);
      vec3.normalize(normal, normal);

      const base = f * ((n+1) ** 2);

      // Each vertex stores four floats. w is 1 for a position and 0 for a
      // normal, so normals ignore the translation column of any matrix applied
      // later.
      for (let j = 0; j <= n; j++) {
        for (let i = 0; i <= n; i++) {
            let s = i / n;
            let t = j / n; 

            const p = vec3.create();
            vec3.scaleAndAdd(p, face.origin, face.u, s);
            vec3.scaleAndAdd(p, p, face.v, t);

            positions.push(p[0] + this.center[0], p[1] + this.center[1], p[2] + this.center[2], 1);
            normals.push(normal[0], normal[1], normal[2], 0);  
        }
      }

      for (let j = 0; j < n; j++) {
        for (let i = 0; i < n; i++) {
          // i is the inner loop of the vertex pass, so consecutive i sit next
          // to each other and stepping j jumps a whole row of n + 1 vertices.
          const index = base + j * (n + 1) + i;
          const indexRight = index + 1;
          const indexUp = index + (n + 1);
          const indexUpRight = indexUp + 1;

          indices.push(index, indexRight, indexUpRight);
          indices.push(index, indexUpRight, indexUp);
        }
      }
    }

    this.indices = new Uint32Array(indices);
    this.positions = new Float32Array(positions);
    this.normals = new Float32Array(normals);

    this.generateIdx();
    this.generatePos();
    this.generateNor();

    this.count = this.indices.length;

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.bufIdx);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, this.indices, gl.STATIC_DRAW);

    gl.bindBuffer(gl.ARRAY_BUFFER, this.bufNor);
    gl.bufferData(gl.ARRAY_BUFFER, this.normals, gl.STATIC_DRAW);

    gl.bindBuffer(gl.ARRAY_BUFFER, this.bufPos);
    gl.bufferData(gl.ARRAY_BUFFER, this.positions, gl.STATIC_DRAW);

    console.log(`Created cube: ${n}x${n} per face, ${this.positions.length / 4} vertices, ${this.indices.length / 3} triangles`);
  }
}

export default Cube;
