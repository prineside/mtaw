// Устанавливает цвет вместо текстуры и применяет освещение
// Не layered
#include "mta-helper.fx"

float red = 1.0f;
float green = 0.0f;
float blue = 0.0f;
float diffuseStrength = 0.25f;

sampler Sampler0 = sampler_state
{
    Texture = (gTexture0);
};

struct VSInput
{
    float3 Position : POSITION0;
    float3 Normal : NORMAL0;
    float4 Diffuse : COLOR0;
};

struct PSInput
{
    float4 Position : POSITION0;
    float4 Diffuse : COLOR0;
};

PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;

    PS.Position = MTACalcScreenPosition ( VS.Position );
    PS.Diffuse = MTACalcGTABuildingDiffuse( VS.Diffuse );
	
	//float3 WorldNormal = MTACalcWorldNormal( VS.Normal );
    //PS.Diffuse = MTACalcGTAVehicleDiffuse( WorldNormal, VS.Diffuse );

    return PS;
}

float4 PixelShaderFunction(PSInput PS) : COLOR0
{
	PS.Diffuse.r = min( PS.Diffuse.r * diffuseStrength, 1.0f );
	PS.Diffuse.g = min( PS.Diffuse.g * diffuseStrength, 1.0f );
	PS.Diffuse.b = min( PS.Diffuse.b * diffuseStrength, 1.0f );
	
	return float4(red, green, blue, 1.0f) * PS.Diffuse;
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
