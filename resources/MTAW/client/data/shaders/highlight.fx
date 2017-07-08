#include "mta-helper.fx"

float fadeInterval = 7;
float fadeDelta = 0.2;
float opacity = 1.0;

float Time : TIME;

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
  float3 WorldNormal : TEXCOORD1;
  float3 WorldPos : TEXCOORD2;
};

PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;

    MTAFixUpNormal( VS.Normal );

	VS.Position = VS.Position + ( VS.Normal * 0.0002 );
	
    PS.Position = MTACalcScreenPosition ( VS.Position );

    PS.TexCoord = VS.TexCoord;

    PS.Diffuse = MTACalcGTABuildingDiffuse( VS.Diffuse );

    PS.WorldNormal = MTACalcWorldNormal( VS.Normal );
    PS.WorldPos = MTACalcWorldPosition( VS.Position );

    return PS;
}

float4 PixelShaderFunction( float2 TexCoord : TEXCOORD0 ) : COLOR0
{
	float4 texel = tex2D( Sampler0, TexCoord );
	
    float b = sin( ( Time ) * fadeInterval ) * fadeDelta * opacity * texel.a; 
	
	if ( b > 0 ) {
		return float4( 1, 1, 1, b );
	} else {
		return float4( 0, 0, 0, -b );
	}
}

technique simple
{
    pass P0
    {
		VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}