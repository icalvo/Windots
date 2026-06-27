// Dims and blue-tints inactive panes.
// Used via unfocusedAppearance.experimental.pixelShaderPath in settings.json.

Texture2D shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings {
    float  Time;
    float  Scale;
    float2 Resolution;
    float4 Background;
};

static const float DimStrength = 0.45;      // 0 = none, 1 = black
static const float Desaturate = 0.35;       // 0 = full color, 1 = grayscale
static const float BlueTintStrength = 0.8;  // 0 = none, 1 = full blue cast
static const float3 BlueTint = float3(0.55, 0.72, 1.0); // multiply toward this color

float Luminance(float3 rgb)
{
    return dot(rgb, float3(0.299, 0.587, 0.114));
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float4 color = shaderTexture.Sample(samplerState, tex);

    // Keep empty cells (alpha 0) untouched so acrylic/background still works.
    if (color.w <= 0.001)
    {
        return color;
    }

    float3 rgb = color.rgb;

    // Partial desaturate, darken, then blue tint.
    float lum = Luminance(rgb);
    rgb = lerp(rgb, lum.xxx, Desaturate);
    rgb = lerp(rgb, float3(0.0, 0.0, 0.0), DimStrength);
    rgb = lerp(rgb, rgb * BlueTint, BlueTintStrength);

    return float4(rgb, color.w);
}
