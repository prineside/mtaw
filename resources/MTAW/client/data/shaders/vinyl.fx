#include "mta-helper.fx"

texture Tex0;
float lightLevel = 0.7f;

sampler Sampler0 = sampler_state
{
    Texture = (Tex0);
};

struct VSInput
{
    float3 Position : POSITION0;
    float4 Diffuse : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

struct PSInput
{
    float4 Position : POSITION0;
    float4 Diffuse : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;

    PS.Position = MTACalcScreenPosition( VS.Position );
    PS.TexCoord = VS.TexCoord;
	
    PS.Diffuse = float4(lightLevel * 1.0f, lightLevel * 0.9f, lightLevel * 0.8f, 1.0f);
	
    return PS;
}

float4 PixelShaderFunction(PSInput PS) : COLOR0
{
	return tex2D(Sampler0, PS.TexCoord) * PS.Diffuse;
}

technique tec0
{
    pass P0
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}

technique fallback
{
    pass P0
    {

    }
}