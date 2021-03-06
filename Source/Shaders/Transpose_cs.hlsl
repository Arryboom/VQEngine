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


#if R32F
RWTexture2D<float> texTranspozeOut;
RWTexture2D<float> texImageIn;
#else

//#if RGBA32F
RWTexture2D<float4> texTranspozeOut;
RWTexture2D<float4> texImageIn;
//#endif
#endif

[numthreads(16, 16, 1)]
void CSMain(
	uint3 groupID     : SV_GroupID,
	uint3 groupTID    : SV_GroupThreadID,
	uint3 dispatchTID : SV_DispatchThreadID,
	uint  groupIndex  : SV_GroupIndex
)
{
	//if(dispatchTID.x < 1920 && dispatchTID.y < 1080)
		texTranspozeOut[dispatchTID.yx] = texImageIn[dispatchTID.xy];
}
