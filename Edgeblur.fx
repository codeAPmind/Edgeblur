#include "Shader\PostEffectCommon.hlsl"
#include "Shader\MeshCommon.hlsl"
//milongwu@gmail.com  for any QA

uniform float4 edgeColor;
uniform float4x4 vp_mat : VIEWPROJECT_MATRIX;
uniform float4x4 v_mat : VIEW_MATRIX;
uniform float4x4 p_mat : WORLDVIEWPROJECT_MATRIX;

sampler2D modelTex;
sampler2D blurTex;

//---------------------------------------------------------------------
// rimback no maco model
struct  RimbackNomaco_VS_OUTPUT
{
	float4 pos : POSITION0;
	float2 uv  : TEXCOORD0;
};

RimbackNomaco_VS_OUTPUT RimbackNomaco_vs(VertexInput input)
{
	RimbackNomaco_VS_OUTPUT output;


	float3 pos = input.pos;

	//float3 pos = input.pos.xyz;
	output.pos = mul(float4(pos, 1), p_mat);
	// minuse is for z-flighting phenomenon
	output.pos.z -= 0.01f;
	output.uv = input.uv0;
	return output;
}
float4  RimbackNomaco_ps(float2 uv : TEXCOORD0): color0   
{
	float4 color = tex2D(modelTex, uv); 
	color.xyz= edgeColor.xyz;
	return float4(color.rgb,1);
}

//----------------------------------------------------------------------
// rimback pass

struct Rimback_VS_OUTPUT
{
	float4 pos : POSITION0;
	float2 uv  : TEXCOORD0;
};

Rimback_VS_OUTPUT Rimback_vs(VertexInput input)
{
	// localspace×ª»»µ½worldspace£¬²¢ÇÒÃÉÆ¤
	WorldVertex wv = VertexInputToWorld(input);
	Rimback_VS_OUTPUT output;

	float3 pos = wv.worldPos.xyz;
		//float3 pos = input.xyz;
	float4 viewPos = mul(float4(pos,1),v_mat);
	float dis = distance(viewPos.xyz,float3(0,0,0));
	float scale =  dis / 20;
	//pos = pos + wv.normal * 0.06f * scale;
	output.pos = mul(float4(pos, 1), vp_mat);
	output.uv = input.uv0;
	return output;
}

float4 Rimback_ps(float2 uv : TEXCOORD0): color0   
{
	float4 color = tex2D(modelTex, uv);
	clip(color.a-0.5);  
	color.xyz= edgeColor.xyz;
	//clip(color.a);  
	return float4(color.rgb,1);
}


//------------------------------------------------------------------------
//  horizontal blur , for improve performce if necessary

uniform float4 viewport_inv_size;

//#define WEIGHT_COUNT 7

float weight[6] = {0.9f, 0.85f, 0.70f, 0.5f, 0.25f, 0.15f};


float colorIntensity = 1.0f;
float intensity = 1.0f;

struct BlurHorizontal_VS_OUTPUT
{
	float4 pos	: POSITION0;
	float2 uv	: TEXCOORD0;
	float4 uvProj : TEXCOORD1;
};


float4 PS_BlurHorizontal(float2 uv : TEXCOORD0) : color0 
{
	float alpha = 0;
	float mult = 1.0f;
	float alphatemp =0;
	for(int i=0; i<6; i++)
	{
		alphatemp =  tex2D(blurTex, float2(uv.x+(intensity*viewport_inv_size.x*mult), uv.y)).a;
		//alpha += tex2D(blurTex, float2(uv.x+(intensity*viewport_inv_size.x*mult[i]), uv.y)).a;// * weight[i];
		alpha +=  alphatemp*weight[i];
		alphatemp =  tex2D(blurTex, float2(uv.x-(intensity*viewport_inv_size.x*mult), uv.y)).a;
		alpha +=  alphatemp*weight[i];
		mult += 1.0f;
	}  
	alpha /= 6;
	return float4(1,0,0,alpha); 
}
//-------------------------------------------------------------------------
// use main_vs as blurpass's vertex function
// vertical blur , for improve performce if necessary
struct BlurVertical_VS_OUTPUT
{
	float4 pos	: POSITION0;
	float2 uv	: TEXCOORD0;
	float4 uvProj : TEXCOORD1;
};

float4 PS_BlurVertical(float2 uv : TEXCOORD0) : color0
{
	float alpha = 0;
	float mult = 1.0f;
	float alphatemp= 0;
	for(int i=0; i<6; i++)
	{
		alphatemp =  tex2D(blurTex, float2(uv.x, uv.y+(intensity*viewport_inv_size.y*mult))).a;
		//alpha += tex2D(blurTex, float2(uv.x, uv.y+(intensity*viewport_inv_size.y*mult[i]))).a;// * weight[i];
		alpha +=  alphatemp*weight[i];
		alphatemp =  tex2D(blurTex, float2(uv.x, uv.y-(intensity*viewport_inv_size.y*mult))).a;
		alpha +=  alphatemp*weight[i];
		mult += 1.0f;
	}
	alpha /= 6;
	return float4(1,0,0,alpha);
}
//------------------------------------------------------------------------
float4 edegblur_ps(float2 uv : TEXCOORD0) : color0
{
    // 0.7 is for pixel bias
	const float4 samples[9] = {
		-3.70, -3.70, 0, 1.0/16.0,
		-3.70,  3.70, 0, 1.0/16.0,
		3.70, -3.70, 0, 1.0/16.0,
		3.70,  3.70, 0, 1.0/16.0,
		-3.70,  0.70, 0, 2.0/16.0,
		3.70,  0.70, 0, 2.0/16.0,   
		0.70, -3.70, 0, 2.0/16.0,
		0.70,  3.70, 0, 2.0/16.0,
		0.70,  0.70, 0, 4.0/16.0
	};

	float4 col = float4(0, 0, 0, 0);
		//Sample and output the averaged colors
		for(int i=0;i<9;i++)
			col += samples[i].w * tex2D(blurTex, uv + samples[i].xy * viewport_inv_size.xy);
	return float4(edgeColor.r,edgeColor.g,edgeColor.b,col.a);
}
//----------------------------------------------------------------
float4 pengzhang_ps(float2 uv : TEXCOORD0) : color0
{
	const float2 flation[25] =
	{
		-2.70,-2.70,
		-2.70,-1.70,
		-2.70, 0.70,
		-2.70, 1.70,
		-2.70, 2.70,
		-1.70,-2.70,
		-1.70,-1.70,
		-1.70, 0.70,
		-1.70, 1.70,
		-1.70, 2.70,
		0.70,-2.70,
		0.70,-1.70,
		0.70, 0.70,
		0.70, 1.70,
		0.70, 2.70,
		1.70,-2.70,
		1.70,-1.70,
		1.70, 0.70,
		1.70, 1.70,
		1.70, 2.70,
		2.70,-2.70,
		2.70,-1.70,
		2.70, 0.70,
		2.70, 1.70,
		2.70, 2.90,
	};
	float4 outColor = tex2D(blurTex, uv);

		for(int i = 0; i< 25; i++)
		{
			float4 color = tex2D(blurTex, uv + flation[i].xy * viewport_inv_size.xy);
				// add color to flation
				if(color.a >= 0.98)
					outColor = color;
		}

		return outColor;
}

//----------------------------------------------------------------------------
// scene blend pass

struct SceneBlend_VS_OUTPUT
{
	float4 pos	: POSITION0;
	float2 uv	: TEXCOORD0;
	float4 uvProj : TEXCOORD1;
};

VS_OUTPUT  scene_blend__vs(VS_INPUT vert)
{
	VS_OUTPUT vsout;

	vsout.pos = float4(vert.pos,1);
	vsout.uv  = vert.uv;

	vsout.pos.z = 1.0f;

	return vsout;
}


float4 scene_blend_ps(VS_OUTPUT input):color0
{
	float alpha = tex2D(blurTex,input.uv).a;
	clip(1.0 - (alpha + 0.2f));
	return tex2D(blurTex, input.uv);
}

technique RimbackNomaco
{
	pass
	{
		VertexShader = compile vs_2_0 RimbackNomaco_vs();
		PixelShader = compile ps_2_0 RimbackNomaco_ps();
	}
}

technique Rimback
{
	pass
	{
		VertexShader = compile vs_2_0 Rimback_vs();
		PixelShader = compile ps_2_0 Rimback_ps();
	}
}

technique BlurHorizontal
{
	pass 
	{
		VertexShader = compile vs_2_0 main_vs();
		PixelShader = compile ps_2_0 PS_BlurHorizontal();
	}
}

technique BlurVertical
{
	pass 
	{
		VertexShader = compile vs_2_0 main_vs();
		PixelShader = compile ps_2_0 PS_BlurVertical();
	}
}

technique Edgeblur
{
	pass
	{
		VertexShader = compile vs_2_0 main_vs();
		PixelShader = compile ps_2_0 edegblur_ps();
	}
}

technique pengzhang
{
	pass
	{
		VertexShader = compile vs_3_0 main_vs();
		PixelShader = compile ps_3_0 pengzhang_ps();
	}
}

// alphablend
technique FinalBlend
{
	pass
	{
		VertexShader = compile vs_2_0 scene_blend__vs();
		PixelShader = compile ps_2_0 scene_blend_ps();
	}
}