#version 460 core
#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform sampler2D uImageSrc0;
uniform vec2 uDstOrigin;
uniform vec2 uDstSize;
uniform vec2 uAtlasSize;
uniform float uFrames;
uniform vec2 uFrameSize;
uniform mat4 uVoxelModelMatrixInverse;

uniform float uExplodeTime;

out vec4 fragColor;

const float FADE_START_TIME = 0.6;
const float FADE_END_TIME = 0.9;

vec2 calculateScreenUV(vec2 fragCoord);
vec4 marchRay(vec3 pos);
vec4 sampleShadedVolume(vec3 posUnrotated);
vec4 volumeMap(vec3 pos);
bool isOutOfBounds(vec3 pos);
vec2 calculateAtlasUV(vec3 pos);
vec3 getExplosionColor(float progress);

void main() {
    vec2 uv = FlutterFragCoord().xy;
    vec2 screenUV = calculateScreenUV(FlutterFragCoord().xy);
    vec3 startPos = vec3(screenUV.x, screenUV.y, 0.5);
    fragColor = marchRay(startPos);
    fragColor.rgb *= fragColor.a;
}

// --- Helper: Calculate normalized screen UV (-0.5 to 0.5) ---
vec2 calculateScreenUV(vec2 fragCoord) {
    return (fragCoord - uDstOrigin) / uDstSize - 0.5;
}

// --- Core: March a ray (SIMPLIFIED - First Hit Wins) ---
vec4 marchRay(vec3 pos) {
    const int numSteps = 128;
    const float stepSize = 1.0 / float(numSteps);
    for (int i = 0; i < numSteps; i++) {
        vec4 sampledColor = sampleShadedVolume(pos);
        if (sampledColor.a > 0.0) { return sampledColor; }
        pos.z -= stepSize;
        if (pos.z < -0.5) { break; }
    }
    return vec4(0.0);
}
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

vec4 sampleShadedVolume(vec3 posUnrotated) {

    // Transform position using the inverse model matrix to get local coordinates
    vec3 localPos = (uVoxelModelMatrixInverse * vec4(posUnrotated, 1.0)).xyz;

    localPos = floor(localPos * uFrameSize.x) / uFrameSize.x;

    float rnd = random(localPos.xy/100) + random(localPos.xz/100);
    float explodeTime = uExplodeTime + rnd / 4;

    vec3 displacement = vec3(0.0, (uExplodeTime - localPos.y - rnd) * uExplodeTime, 0.0);
    vec3 samplingPos = localPos - displacement;
    if (isOutOfBounds(samplingPos)) { return vec4(0.0); }

    vec4 originalVoxelColor = volumeMap(samplingPos);

    if (originalVoxelColor.a == 0.0 || explodeTime < FADE_START_TIME) {
        return originalVoxelColor;
    }

    float finalAlpha = originalVoxelColor.a;
    float fadeDuration = FADE_END_TIME - FADE_START_TIME;
    float fadeProgress = clamp((explodeTime - FADE_START_TIME) / fadeDuration, 0.0, 1.0);
    finalAlpha = originalVoxelColor.a * pow(1.0 - fadeProgress, 2.0);// Quadratic fade
    if (finalAlpha < 0.2) return vec4(0.0);
    vec3 finalRgb = getExplosionColor(fadeProgress);
    if (finalRgb.r < 0.1 && finalRgb.g < 0.1 && finalRgb.b < 0.1) return vec4(0.0);
    return vec4(finalRgb, finalAlpha);
}

vec4 volumeMap(vec3 pos) {
    vec2 uv = calculateAtlasUV(pos);
    return texture(uImageSrc0, uv);
}

bool isOutOfBounds(vec3 pos) {
    return pos.x < -0.5 || pos.x > 0.5 ||
    pos.y < -0.5 || pos.y > 0.5 ||
    pos.z < -0.5 || pos.z > 0.5;
}

vec2 calculateAtlasUV(vec3 pos) {
    // Map local position [-0.5, 0.5] to texture coordinates [0, frameSize]
    vec2 pixel_uv;
    pixel_uv.x = (pos.x + 0.5) * uFrameSize.x;
    pixel_uv.y = (pos.z + 0.5) * uFrameSize.y;// Z maps to V within a slice

    // Determine the slice index based on Y coordinate
    // Clamp Y to avoid issues if displacement pushes it slightly out of [-0.5, 0.5] range
    float y_clamped = clamp(pos.y, -0.5, 0.5);
    float slice = floor((y_clamped + 0.5) * uFrames);
    // Clamp slice index just in case
    slice = clamp(slice, 0.0, uFrames - 1.0);

    // Calculate the Y offset in the atlas based on the slice index
    float pixel_offset_y = slice * uFrameSize.y;
    pixel_uv.y += pixel_offset_y;

    // Normalize UVs to [0, 1] based on the total atlas size
    return pixel_uv / uAtlasSize;
}

vec3 getExplosionColor(float progress) {
    progress = clamp(progress, 0.0, 1.0);
    vec3 white = vec3(1.0, 1.0, 1.0);
    vec3 yellow = vec3(1.0, 1.0, 0.0);
    vec3 orange = vec3(1.0, 0.5, 0.0);
    vec3 red = vec3(1.0, 0.0, 0.0);
    vec3 darkRed = vec3(0.5, 0.0, 0.0);
    vec3 black = vec3(0.0, 0.0, 0.0);// Fade to black

    const float numSegments = 5.0;// white->yellow->orange->red->darkRed->black
    float segment = 1.0 / numSegments;
    float t = mod(progress, segment) / segment;// Interpolation factor within segment

    if (progress < segment) { // White -> Yellow
        return mix(white, yellow, t);
    } else if (progress < segment * 2.0) { // Yellow -> Orange
        return mix(yellow, orange, t);
    } else if (progress < segment * 3.0) { // Orange -> Red
        return mix(orange, red, t);
    } else if (progress < segment * 4.0) { // Red -> Dark Red
        return mix(red, darkRed, t);
    } else { // Dark Red -> Black
        return mix(darkRed, black, t);
    }
}
