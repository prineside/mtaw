//---------------------------------------------------------------------
// Ped morph settings
//---------------------------------------------------------------------
// float3 uUpLip = float3(0,0,0);
float gTwMouth = 1.0;

//---------------------------------------------------------------------
// Include some common stuff
//---------------------------------------------------------------------
#include "mta-helper.fx"

//---------------------------------------------------------------------
// Structure of data sent to the vertex shader
//---------------------------------------------------------------------
struct VSInput
{
    float3 Position : POSITION0;
    float4 Diffuse : COLOR0;
    float2 TC : TEXCOORD0;
};

//---------------------------------------------------------------------
// Structure of data sent to the pixel shader ( from the vertex shader )
//---------------------------------------------------------------------
struct PSInput
{
    float4 Position : POSITION0;
    float4 Diffuse : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

//------------------------------------------------------------------------------------------
// VertexShaderFunction
//  1. Read from VS structure
//  2. Process
//  3. Write to PS structure
//------------------------------------------------------------------------------------------
PSInput VertexShaderFunction(VSInput VS)
{
	
    PSInput PS = (PSInput)0;

	float uvX = VS.TC[0];
	float uvY = VS.TC[1];
	
// gTwMouth
if ( gTwMouth != 0.0 ) {
	if ( uvX >= 0.115 && uvX <= 0.13 && uvY >= 0.005 && uvY <= 0.02 ) {
		VS.Position += float3( 0.0, 0.0, -0.0130730 * gTwMouth );
	}
	if ( uvX >= 0.22 && uvX <= 0.235 && uvY >= 0.04 && uvY <= 0.055 ) {
		VS.Position += float3( 0.0, 0.0, -0.0124180 * gTwMouth );
	}
	if ( uvX >= 0.43 && uvX <= 0.445 && uvY >= -0.005 && uvY <= 0.01 ) {
		VS.Position += float3( 0.0, 0.0, -0.0249960 * gTwMouth );
	}
	if ( uvX >= 0.435 && uvX <= 0.45 && uvY >= 0.075 && uvY <= 0.09 ) {
		VS.Position += float3( 0.0, 0.0, -0.0088690 * gTwMouth );
	}
	if ( uvX >= 0.44 && uvX <= 0.455 && uvY >= 0.15 && uvY <= 0.165 ) {
		VS.Position += float3( 0.0, 0.0, -0.0014670 * gTwMouth );
	}
	if ( uvX >= 0.44 && uvX <= 0.455 && uvY >= 0.035 && uvY <= 0.05 ) {
		VS.Position += float3( 0.0, 0.0, -0.0204630 * gTwMouth );
	}
	if ( uvX >= 0.8 && uvX <= 0.815 && uvY >= 0.045 && uvY <= 0.06 ) {
		VS.Position += float3( 0.0, 0.0, -0.0151820 * gTwMouth );
	}
	if ( uvX >= 0.705 && uvX <= 0.72 && uvY >= 0.115 && uvY <= 0.13 ) {
		VS.Position += float3( 0.0, 0.0, -0.0022870 * gTwMouth );
	}
	if ( uvX >= 0.935 && uvX <= 0.95 && uvY >= 0.01 && uvY <= 0.025 ) {
		VS.Position += float3( 0.0, 0.0, -0.0169750 * gTwMouth );
	}
	if ( uvX >= 0.825 && uvX <= 0.84 && uvY >= 0.12 && uvY <= 0.135 ) {
		VS.Position += float3( 0.0, 0.0, -0.0081760 * gTwMouth );
	}
	if ( uvX >= 0.985 && uvX <= 1 && uvY >= 0.125 && uvY <= 0.14 ) {
		VS.Position += float3( 0.0, 0.0, -0.0035730 * gTwMouth );
	}
}

	
    PS.Position = MTACalcScreenPosition ( VS.Position );
	PS.TexCoord = VS.TC;
	PS.Diffuse = MTACalcGTABuildingDiffuse( VS.Diffuse );
	
    return PS;
}


//------------------------------------------------------------------------------------------
// Techniques
//------------------------------------------------------------------------------------------
technique tec0
{
    pass P0
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
    }
}

// Fallback
technique fallback
{
    pass P0
    {
        // Just draw normally
    }
}