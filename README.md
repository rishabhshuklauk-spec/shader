# Custom Minecraft Shader

A custom Minecraft shader pack built for the Iris/Optifine shader pipeline, focusing on realistic, high-performance water rendering and atmospheric lighting.

## Tech Stack
*   **GLSL (OpenGL Shading Language)**: Core shading logic for fragment and vertex rendering.
*   **Optifine / Iris API**: Pipeline integration for Minecraft rendering buffers.
*   **Minecraft**: Target engine.

## Features
*   **Volumetric Water Physics**: Accurate depth reconstruction using inverse projection matrices, fixing Snell's window and Total Internal Reflection (TIR).
*   **Organic Wave Normals**: Custom 2D Simplex Noise implementation for artifact-free, non-repeating water ripples without grid or checkerboard artifacts.
*   **Depth-Based Absorption**: Uniform light transmittance through water volumes for natural color blending without harsh hue shifting.
*   **Soft Specular Reflections**: Physically-based sun and moon reflections mapped to wave normals.

## How to Contribute
1.  **Fork the repository** and clone it locally.
2.  **Make your changes**: Modify the GLSL code in the `.fsh` (fragment) and `.vsh` (vertex) files.
3.  **Test**: Load the folder as a shader pack in Minecraft using the [Iris Shaders](https://irisshaders.dev/) mod. Use `R` to reload the shader in-game.
