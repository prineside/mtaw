
texture Tex0;
 
technique simple
{
    pass P0
    {
        // First pass
        Texture[0] = Tex0;
    }
}