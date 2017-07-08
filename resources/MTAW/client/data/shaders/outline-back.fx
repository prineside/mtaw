#include "mta-helper.fx"

float3 lineColor = float3(0,0.8,0);

sampler Sampler0 = sampler_state
{
    Texture = (gTexture0);
};

struct VSInput
{
    float3 Position : POSITION0;
    float3 Normal : NORMAL0;
    float4 Diffuse : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

struct PSInput
{
    float4 Position : POSITION0;
    float4 Diffuse : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

struct PSOutput
{
	float4 Color0 : COLOR0;
};

PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;

    VS.Position += VS.Normal * 0.012;
    PS.Position = MTACalcScreenPosition ( VS.Position );
    PS.TexCoord = VS.TexCoord;

    PS.Diffuse = MTACalcGTABuildingDiffuse( VS.Diffuse );

    return PS;
}

PSOutput PixelShaderFunction(PSInput PS)
{
	PSOutput Output;
	
	float4 texel = tex2D( Sampler0, PS.TexCoord );
	Output.Color0 = float4( lineColor, texel.a );
 
	return Output;
}

technique tec0
{
    pass P0
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PixelShaderFunction();
		ZWriteEnable = TRUE;
		DepthBias = 0.001f;
    }
}

technique fallback
{
    pass P0
    {
        
    }
}
