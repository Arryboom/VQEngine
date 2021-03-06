//	VQEngine | DirectX11 Renderer
//	Copyright(C) 2018  - Volkan Ilbeyli
//
//	This program is free software : you can redistribute it and / or modify
//	it under the terms of the GNU General Public License as published by
//	the Free Software Foundation, either version 3 of the License, or
//	(at your option) any later version.
//
//	This program is distributed in the hope that it will be useful,
//	but WITHOUT ANY WARRANTY; without even the implied warranty of
//	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.See the
//	GNU General Public License for more details.
//
//	You should have received a copy of the GNU General Public License
//	along with this program.If not, see <http://www.gnu.org/licenses/>.
//
//	Contact: volkanilbeyli@gmail.com

#include "BlurCommon.hlsl"

Texture2D<float>  texOcclusion;
Texture2D<half4>  texNormals;
Texture2D<float>  texDepth;
SamplerState      sSampler;

RWTexture2D<float>  texBlurredOcclusionOut;

struct BlurConstants
{
	float normalDotThreshold; // filters out := dot(normals) < normalDotThreshold 
	float depthThreshold;     // filters out := abs(depthDifference) > depthThreshold 
};
cbuffer BlurConstantsBuffer
{
	BlurConstants cParameters;
	matrix matProjInverse;
};

// These are defined by the application compiling the shader
//-----------------------------------------------------------
//#define THREAD_GROUP_SIZE_X 1
//#define THREAD_GROUP_SIZE_Y 1920
//#define THREAD_GROUP_SIZE_Z 1
//#define IMAGE_SIZE_Y 1080
//#define IMAGE_SIZE_X 1920
//#define PASS_COUNT 1
//#define KERNEL_SIZE 3
//-----------------------------------------------------------
// KERNEL_RANGE is this: center + half width of the kernel
//
// consider a blur kernel 5x5 - '*' indicates the center of the kernel
//
// x   x   x   x   x
// x   x   x   x   x
// x   x   x*  x   x
// x   x   x   x   x
// x   x   x   x   x
//
//
// separate into 1D kernels
//
// x   x   x*  x   x
//         ^-------^
//        KERNEL_RANGE
//
#define KERNEL_RANGE  ((KERNEL_DIMENSION - 1) / 2) + 1
#define KERNEL_RANGE_EXCLUDING_MIDDLE  (KERNEL_RANGE - 1)

#if VERTICAL
	#define PIXEL_CACHE_SIZE    IMAGE_SIZE_Y + KERNEL_RANGE_EXCLUDING_MIDDLE * 2
#else
	#define PIXEL_CACHE_SIZE    IMAGE_SIZE_X + KERNEL_RANGE_EXCLUDING_MIDDLE * 2
#endif

#define WQHD (IMAGE_SIZE_X > 1920)
//-----------------------------------------------------------

#if WQHD
groupshared float3 gNormals[PIXEL_CACHE_SIZE];
//groupshared float gDepth[PIXEL_CACHE_SIZE];		// out of LDS memory
//groupshared float gOcclusion[PIXEL_CACHE_SIZE];	// out of LDS memory
#else
groupshared float3 gNormals[PIXEL_CACHE_SIZE];
//groupshared float gDepth[PIXEL_CACHE_SIZE];	// out of LDS memory
groupshared float gOcclusion[PIXEL_CACHE_SIZE];
#endif

[numthreads(THREAD_GROUP_SIZE_X, THREAD_GROUP_SIZE_Y, THREAD_GROUP_SIZE_Z)]
void CSMain(
	uint3 dispatchTID : SV_DispatchThreadID,
	uint3 groupTID    : SV_GroupThreadID,
	uint3 groupID     : SV_GroupID,
	uint  groupIndex  : SV_GroupIndex
)
{
	#include "GaussianKernels.hlsl"

	// READ INPUT TEXTURE AND SAVE INTO SHARED MEM (LDS = Local Data Share)
	//
	const uint TEXTURE_READ_COUNT = (uint) ceil(min(
		  ((float)IMAGE_SIZE_X) / THREAD_GROUP_SIZE_X
		, ((float)IMAGE_SIZE_Y) / THREAD_GROUP_SIZE_Y));

	[unroll] for (uint i = 0; i < TEXTURE_READ_COUNT; ++i)
	{
		const uint2 outTexel = dispatchTID.xy + uint2(THREAD_GROUP_SIZE_X * i, 0);
		if (outTexel.x >= IMAGE_SIZE_X)
			break;
		
		const float2 uv = float2(outTexel.xy) / float2(IMAGE_SIZE_X, IMAGE_SIZE_Y);

#if TRANSPOZED_OUT
		const float3 normal = texNormals.SampleLevel(sSampler, uv.yx, 0).xyz;
#else
		const float3 normal = texNormals.SampleLevel(sSampler, uv, 0).xyz;
#endif
		//const float detph  = texDepth.SampleLevel(sSampler, uv, 0).r; 	// out of LDS memory
		const float occlusion = texOcclusion.SampleLevel(sSampler, uv, 0).r;


		if( IsOnImageBorder(outTexel.x, IMAGE_SIZE_X) )
		{
			const int offset = outTexel.x / (IMAGE_SIZE_X - 1);
			[unroll] for (int krn = 0; krn < KERNEL_RANGE_EXCLUDING_MIDDLE; ++krn)
			{
				const uint outOfBoundsIndex = outTexel.x + krn + KERNEL_RANGE_EXCLUDING_MIDDLE * offset + offset;
				gNormals  [outOfBoundsIndex] = normal;
				//gDepth    [outOfBoundsIndex] = detph;	// out of LDS memory
#if WQHD
				;
#else
				gOcclusion[outOfBoundsIndex] = occlusion;
#endif
			}
		}
		const uint imageIndex = outTexel.x + KERNEL_RANGE_EXCLUDING_MIDDLE;
		gNormals  [imageIndex] = normal;
		//gDepth    [imageIndex] = detph;	// out of LDS memory
#if WQHD
		;
#else
		gOcclusion[imageIndex] = occlusion;
#endif


#if TRANSPOZED_OUT
		texBlurredOcclusionOut[outTexel.yx] = 1.0f;
#else
		texBlurredOcclusionOut[outTexel.xy] = 1.0f;
#endif
	}

	// RUN THE HORIZONTAL/VERTICAL BLUR KERNEL
	//
	[unroll] for (uint passCount = 0; passCount < 1/*PASS_COUNT*/; ++passCount)
	{
		// SYNC UP SHARED-MEM SO IT'S READY TO READ
		//
		GroupMemoryBarrierWithGroupSync();

		// BLUR
		//
		[unroll] for (uint px = 0; px < TEXTURE_READ_COUNT; ++px)
		{
			const uint2 outTexel = dispatchTID.xy + uint2(THREAD_GROUP_SIZE_X * px, 0);
			if (outTexel.x >= IMAGE_SIZE_X)
				break;

			float2 uv = float2(outTexel.xy) / float2(IMAGE_SIZE_X, IMAGE_SIZE_Y);

			// linearly run the blur kernel
			float result = 0.0f;
			const float3 centerTapNormal = gNormals[outTexel.x];

#if TRANSPOZED_OUT
			const float centerTapDepth = texDepth.SampleLevel(sSampler, uv.yx, 0).r; //gDepth[outTexel.x];
#else
			const float centerTapDepth = texDepth.SampleLevel(sSampler, uv, 0).r; //gDepth[outTexel.x];
#endif
			const float centerTapDepthLinear = LinearDepth(centerTapDepth, matProjInverse);

			// no need to blur if there's no surface
			if (dot(centerTapNormal, centerTapNormal) < 0.00001)
			{
#if TRANSPOZED_OUT
				texBlurredOcclusionOut[outTexel.yx] = 1.0f;
#else
				texBlurredOcclusionOut[outTexel.xy] = 1.0f;
#endif
				continue;
			}

			float wghSq = 0.0f;
			[unroll] for (int kernelOffset = -(KERNEL_DIMENSION / 2); kernelOffset <= (KERNEL_DIMENSION / 2); ++kernelOffset)
			{
				uv = (dispatchTID.xy + uint2(THREAD_GROUP_SIZE_X * px + kernelOffset, 0)) / float2(IMAGE_SIZE_X, IMAGE_SIZE_Y);;

#if TRANSPOZED_OUT
				const float kernelTapDepth = texDepth.SampleLevel(sSampler, uv.yx, 0).r;
#else
				const float kernelTapDepth = texDepth.SampleLevel(sSampler, uv, 0).r;
#endif
				const float kernelTapDepthLinear = LinearDepth(kernelTapDepth, matProjInverse);

				const uint kernelImageIndex = outTexel.x + kernelOffset + KERNEL_RANGE_EXCLUDING_MIDDLE;
				const float3 kernelNormal = gNormals[kernelImageIndex];
				
				// TODO: there are issues here: depth taps have the same value...
				const bool bReduceGaussianWeightToZero = true &&
				(	false//   (dot(kernelNormal, kernelNormal) < 0.00001)
					//|| (dot(centerTapNormal, kernelNormal) < 0.987 /*cParameters.normalDotThreshold*/)
					|| ( abs(centerTapDepthLinear - kernelTapDepthLinear) == 0.0f /*cParameters.depthThreshold*/)
				);
				const float WEIGHT = bReduceGaussianWeightToZero ? 0.0f : KERNEL_WEIGHTS[abs(kernelOffset)];
#if WQHD
				//if (passCount == 0)
				//{
#if TRANSPOZED_OUT
					result += texOcclusion.SampleLevel(sSampler, uv.yx, 0).r * WEIGHT;
#else
					result += texOcclusion.SampleLevel(sSampler, uv, 0).r * WEIGHT;
#endif
				//}

#else
				result += gOcclusion[kernelImageIndex] * WEIGHT;
#endif
				wghSq += WEIGHT * WEIGHT;
			}


			// normalize weights
			//
			// TODO: fix the incorrect math...
			//if (sqrt(wghSq) > 0.00001)
			//	result /= sqrt(wghSq);


			// save the blurred pixel value
#if TRANSPOZED_OUT
			texBlurredOcclusionOut[outTexel.yx] = result;
#else
			texBlurredOcclusionOut[outTexel.xy] = result;
#endif

		}

#if WQHD
		;
#else
		// UPDATE LDS
		//
		GroupMemoryBarrierWithGroupSync();

		[unroll] for (uint i = 0; i < TEXTURE_READ_COUNT; ++i)
		{
			const uint2 outTexel = dispatchTID.xy + uint2(THREAD_GROUP_SIZE_X * i, 0);
			if (outTexel.x >= IMAGE_SIZE_X)
				break;

#if TRANSPOZED_OUT
			const float occlusion = texBlurredOcclusionOut[outTexel.yx];
#else
			const float occlusion = texBlurredOcclusionOut[outTexel.xy];
#endif

			const bool bFirstPixel = outTexel.x == 0;
			const bool bLastPixel = outTexel.x == (IMAGE_SIZE_X - 1);
			if (bFirstPixel || bLastPixel)
			{
				const int offset = outTexel.x / (IMAGE_SIZE_X - 1);
				[unroll] for (int krn = 0; krn < KERNEL_RANGE_EXCLUDING_MIDDLE; ++krn)
				{
					gOcclusion[outTexel.x + KERNEL_RANGE_EXCLUDING_MIDDLE * offset + krn + offset] = occlusion;
				}
			}
			gOcclusion[outTexel.x + KERNEL_RANGE_EXCLUDING_MIDDLE] = occlusion;
		}
#endif
	}
}
