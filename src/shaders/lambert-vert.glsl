#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself
uniform float u_Time;       // Time value updated every frame from TypeScript.
                            // Used to animate the vertex deformation.
uniform float u_WaveFreq;   // Spatial frequency of the interference field.
uniform float u_WarpAmount; // Strength of the fBM domain warp.
uniform float u_DispAmount; // How far the field displaces vertices along the normal.

@import ./wavefield;

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Pos;            // Original object-space position.
                            // This is intentionally kept separate from the deformed position
                            // so the procedural FBM pattern stays attached to the object's surface.

const vec4 lightPos = vec4(5, 5, 3, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.

void main()
{
    fs_Col = vs_Col;                         // Pass the vertex colors to the fragment shader for interpolation

    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                            // Transform the geometry's normals by the inverse transpose of the
                                                            // model matrix. This is necessary to ensure the normals remain
                                                            // perpendicular to the surface after the surface is transformed by
                                                            // the model matrix.


    // Displace the vertex radially from the cube's centre by the same
    // interference field the fragment shader colours with, so bright fringes
    // rise and dark ones sink.
    //   - radial rather than along the face normal: edge vertices are
    //     duplicated per face with different normals, and only a direction
    //     that depends on position alone keeps the faces joined
    //   - evaluated in object space, before u_Model, so it turns with the cube
    //   - time-varying through u_Time and different at every vertex
    vec3 p = vs_Pos.xyz;
    float f = waveSum(p + u_WarpAmount * fbmWarp(p), u_WaveFreq, u_Time).x;
    vec4 displaced = vs_Pos + vec4(normalize(p) * u_DispAmount * f, 0.0);

    vec4 modelposition = u_Model * displaced;
    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies

    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices

    // Pass the ORIGINAL object-space position to the fragment shader.
    // This makes the noise pattern behave more like it is attached
    // to the object's surface instead of being sampled from a fixed
    // world-space noise field.
    fs_Pos = vs_Pos;
}
