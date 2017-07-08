texture Tex0;

sampler Sampler0 = sampler_state
{
    Texture = (Tex0);
};

struct PSInput
{
    float2 TexCoord : TEXCOORD0;
};

float4 PixelShaderFunction(PSInput PS) : COLOR0
{
	return tex2D(Sampler0, PS.TexCoord);
}

technique tec0
{
    pass P0
    {
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}

technique fallback
{
    pass P0
    {

    }
}