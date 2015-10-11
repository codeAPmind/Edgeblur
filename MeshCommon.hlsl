#include "Shader\Common.hlsl"

#ifndef TEXCOORD_NUM
#define TEXCOORD_NUM 1
#endif

#ifndef MAX_BONE_NUM
#define MAX_BONE_NUM 0
#endif

#ifdef REFLECT_UV
	uniform float4 eyePosition : EYE_POSITION;
#endif

struct VertexInput
{
	float3	pos						: POSITION;
	float3	normal					: NORMAL;
	float4  color					: COLOR0;
	
#ifdef NORMAL_MAP
	float3 tangent					: TANGENT;
	float3 bitangent				: BINORMAL ; 
#endif
	
#if MAX_BONE_NUM > 0
	float4 weights : BLENDWEIGHT;
	float4 indices : BLENDINDICES;
#endif
	
#if TEXCOORD_NUM >= 1
	float4 uv0  : TEXCOORD0;
#endif
#if TEXCOORD_NUM >= 2
	float4 uv1	: TEXCOORD1;
#endif
#if TEXCOORD_NUM >= 3
	float4 uv2	: TEXCOORD2;
#endif
};

struct VertexOutput
{
	float4 pos		: POSITION;
	float4 diffuse	: COLOR0;
	
#if TEXCOORD_NUM >= 1
	float4 uv0  : TEXCOORD0;
#endif
#if TEXCOORD_NUM >= 2
	float4 uv1	: TEXCOORD1;
#endif

#if TEXCOORD_NUM >= 3
	float4 uv2	: TEXCOORD2;
#endif

#ifdef REFLECT_UV
	float2 reflectUV  : TEXCOORD2;
#endif

#ifdef ENV_CUBEMAP
	float3 cubeReflectUV : TEXCOORD3;
#endif 
};

//uniform float4 eyePos : EYE_DIRECTION;
uniform float4x4 localToWorld:WORLD_MATRIX;

#ifdef WAVE_ANIMATION
	uniform float4 timeVector  :  TIME; //x 系统时间(毫秒）， y 上一帧时间间隔，z 系统时间（秒）, w 帧计数
	uniform float4 waveParam;
#endif //WAVE_ANIMATION

#if MAX_BONE_NUM == 0
WorldVertex VertexInputToWorld(VertexInput input)
{
#ifdef WAVE_ANIMATION
	float weight = clamp((input.pos.y - waveParam.x) / waveParam.y, 0, 1.0);
	weight *= weight * waveParam.w;
	input.pos.x += sin(timeVector.x * waveParam.z + localToWorld[3][0]) * weight;
	input.pos.z += cos(timeVector.x * waveParam.z + localToWorld[3][0]) * weight;
#endif //WAVE_ANIMATION
	
	WorldVertex result;
	result.worldPos = mul(float4(input.pos,1),localToWorld);
	result.normal   = normalize(mul(input.normal, (float3x3)localToWorld));
	//result.normal   = normalize(input.normal);
	
	#ifdef NORMAL_MAP
		/// modified by xufang
		/// 解决镜像uv法线纹理问题， 直接将反法线的计算放在程序计算， 这里直接使用
		result.tangent = normalize(mul(input.tangent.xyz, (float3x3)localToWorld));
		//float3 bb = (cross(result.normal.xyz, result.tangent.xyz)) ;//* input.tangent.w;
		result.bitangent = normalize(mul(input.bitangent, (float3x3)localToWorld));
	#endif
	
	//float fSign = sign(dot(normalize(eyePos.xyz - result.worldPos.xyz), result.normal) + 0.000000001f);
	//result.normal *= fSign;
	
	return result;
}

#else //MAX_BONE_NUM

uniform float4x4 boneMatrixs[MAX_BONE_NUM] : WORLD_MATRIX_ARRAY;
WorldVertex VertexInputToWorld(VertexInput input)
{
	WorldVertex result;
	result.worldPos = float4(0,0,0,0);
	result.normal   = float3(0,0,0);
	
#ifdef NORMAL_MAP
	result.tangent = float3(0,0,0) ;
	result.bitangent = float3(0,0,0) ;
#endif

	for(int i=0; i < 4; i++)
	{
		result.worldPos += mul(float4(input.pos, 1), boneMatrixs[input.indices[i]]) * input.weights[i];
		result.normal +=  mul(input.normal, (float3x3)(boneMatrixs[input.indices[i]]))  * input.weights[i];
		#ifdef NORMAL_MAP
			result.tangent +=  mul(input.tangent, (float3x3)(boneMatrixs[input.indices[i]]))  * input.weights[i];
			result.bitangent +=  mul(input.bitangent, (float3x3)(boneMatrixs[input.indices[i]]))  * input.weights[i];
		#endif
	}
	result.worldPos.w = 1.0f;

	result.worldPos = mul(result.worldPos, localToWorld);
	result.normal = normalize(mul(result.normal, (float3x3)localToWorld));

	#ifdef NORMAL_MAP
		//result.tangent = normalize(mul(result.tangent, (float3x3)localToWorld));
		//result.bitangent = cross(result.normal, result.tangent);
		result.tangent = normalize(mul(result.tangent, (float3x3)localToWorld));
		result.bitangent = normalize(mul(result.bitangent, (float3x3)localToWorld));
	#endif
	
	//float fSign = sign(dot(normalize(eyePos.xyz - result.worldPos.xyz), result.normal) + 0.000000001f);
	//result.normal *= fSign;
		
	return result;
}
#endif //MAX_BONE_NUM
