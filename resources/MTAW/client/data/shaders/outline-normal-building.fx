#include "mta-helper.fx"

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

PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;

    PS.Position = MTACalcScreenPosition ( VS.Position );
    PS.TexCoord = VS.TexCoord;
    PS.Diffuse = MTACalcGTABuildingDiffuse( VS.Diffuse );
	
	//float3 WorldNormal = MTACalcWorldNormal( VS.Normal );
    //PS.Diffuse = MTACalcGTAVehicleDiffuse( WorldNormal, VS.Diffuse );

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
		ZWriteEnable = TRUE;
		DepthBias = -0.002f;
    }
}

technique fallback
{
    pass P0
    {

    }
}
