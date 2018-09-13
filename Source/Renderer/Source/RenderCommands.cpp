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

#include "RenderCommands.h"
#include "Renderer.h"



// store XSSetShaderResources function pointers in array and index through ShaderType enum
//static void(__cdecl ID3D11DeviceContext:: *SetShaderConstants[6])
//(UINT StartSlot, UINT NumBuffers, ID3D11Buffer *const *ppConstantBuffers) =
//{
//	&ID3D11DeviceContext::VSSetConstantBuffers,
//	&ID3D11DeviceContext::GSSetConstantBuffers,
//	&ID3D11DeviceContext::DSSetConstantBuffers,
//	&ID3D11DeviceContext::HSSetConstantBuffers,
//	&ID3D11DeviceContext::PSSetConstantBuffers,
//	&ID3D11DeviceContext::CSSetConstantBuffers,
//};

#ifdef _WIN64
#define CALLING_CONVENTION __cdecl
#else	// _WIN32
#define CALLING_CONVENTION __stdcall
#endif
static void(CALLING_CONVENTION ID3D11DeviceContext:: *SetShaderResources[EShaderStage::COUNT])
(UINT StartSlot, UINT NumViews, ID3D11ShaderResourceView *const *ppShaderResourceViews) =
{
	&ID3D11DeviceContext::VSSetShaderResources,
	&ID3D11DeviceContext::GSSetShaderResources,
	&ID3D11DeviceContext::DSSetShaderResources,
	&ID3D11DeviceContext::HSSetShaderResources,
	&ID3D11DeviceContext::PSSetShaderResources,
	&ID3D11DeviceContext::CSSetShaderResources,
};

void SetTextureCommand::SetResource(Renderer * pRenderer)
{
	assert(textureID >= 0);
	if (&pRenderer->mTextures[textureID]._uav && shaderTexture.shaderStage == EShaderStage::CS)
	{
		UINT UAVInitialCounts = 0;
		pRenderer->m_deviceContext->CSSetUnorderedAccessViews(shaderTexture.bufferSlot, 1, &pRenderer->mTextures[textureID]._uav, &UAVInitialCounts);
		return;
	}

	(pRenderer->m_deviceContext->*SetShaderResources[shaderTexture.shaderStage])(shaderTexture.bufferSlot, 1, &pRenderer->mTextures[textureID]._srv);
}

static void(CALLING_CONVENTION ID3D11DeviceContext:: *SetSampler[EShaderStage::COUNT])
(UINT StartSlot, UINT NumViews, ID3D11SamplerState* const *ppShaderResourceViews) =
{
	&ID3D11DeviceContext::VSSetSamplers,
	&ID3D11DeviceContext::GSSetSamplers,
	&ID3D11DeviceContext::DSSetSamplers,
	&ID3D11DeviceContext::HSSetSamplers,
	&ID3D11DeviceContext::PSSetSamplers,
	&ID3D11DeviceContext::CSSetSamplers,
};

void SetSamplerCommand::SetResource(Renderer * pRenderer)
{
	assert(samplerID >= 0);
	(pRenderer->m_deviceContext->*SetSampler[shaderSampler.shaderStage])(shaderSampler.bufferSlot, 1, &pRenderer->mSamplers[samplerID]._samplerState);
}

ClearCommand ClearCommand::Depth(float depthClearValue)
{
	const bool bDoClearColor = false;
	const bool bDoClearDepth = true;
	const bool bDoClearStencil = false;
	return ClearCommand (
		bDoClearColor, bDoClearDepth, bDoClearStencil,
		{ 0, 0, 0, 0 }, depthClearValue, 0
	);
}

ClearCommand ClearCommand::Color(const std::array<float, 4>& clearColorValues)
{
	const bool bDoClearColor = true;
	const bool bDoClearDepth = false;
	const bool bDoClearStencil = false;
	return ClearCommand(
		bDoClearColor, bDoClearDepth, bDoClearStencil,
		clearColorValues, 0, 0
	);
}

ClearCommand ClearCommand::Color(float r, float g, float b, float a)
{
	return ClearCommand::Color({ r,g,b,a });
}

