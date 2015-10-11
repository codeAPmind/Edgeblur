uniform float4 worldZ : DEVICE_TO_WORLD_Z;

struct VS_INPUT
{
	float3 pos : POSITION;
	float2 uv  : TEXCOORD0;
};

struct VS_OUTPUT
{
	float4 pos : POSITION;
	float2 uv  : TEXCOORD0;
};

VS_OUTPUT main_vs(VS_INPUT vert)
{
	VS_OUTPUT vsout;// = (VS_OUTPUT)0;
	
	vsout.pos = float4(vert.pos,1);
	vsout.uv  = vert.uv;

	// The input positions adjusted by texel offsets, so clean up inaccuracies
    //vsout.pos.xy = sign(vert.pos.xy);
	vsout.pos.z = 0.0f;

	return vsout;
}

float ConvertFromDeviceZ(float DeviceZ)
{
	return worldZ[0] / (DeviceZ + worldZ[1]);
}

uniform float4x4 viewProjectInverseMatrix : INVERSE_VIEWPROJECT_MATRIX;
sampler2D depthTex;
float4 getWorldPosition(float2 uv)
{
   // Get the depth buffer value at this pixel.  
   float zOverW = tex2D(depthTex, uv);  
   // H is the viewport position at this pixel in the range -1 to 1.  
   float4 H = float4(uv.x * 2 - 1, (1 - uv.y) * 2 - 1,  zOverW, 1);  
   // Transform by the view-projection inverse.  
   float4 D = mul(H, viewProjectInverseMatrix);  
   // Divide by w to get the world position.  
   float4 worldPos = D / D.w;  
   
   return worldPos;
}

float4 getWorldPositionClipInfinite(float2 uv)
{
	// Get the depth buffer value at this pixel.  
   	float zOverW = tex2D(depthTex, uv);
	// clip if depth is 1.0f;
	clip(0.999999f - zOverW);
   	// H is the viewport position at this pixel in the range -1 to 1.  
   	float4 H = float4(uv.x * 2 - 1, (1 - uv.y) * 2 - 1,  zOverW, 1);  
   	// Transform by the view-projection inverse.  
   	float4 D = mul(H, viewProjectInverseMatrix);  
   	// Divide by w to get the world position.  
   	float4 worldPos = D / D.w;  
   
   	return worldPos;
}
