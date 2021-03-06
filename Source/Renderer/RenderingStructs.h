//	VQEngine | DirectX11 Renderer
//	Copyright(C) 2018 - Volkan Ilbeyli
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

#pragma once

#include "RenderingEnums.h"

// todo struct?
using Viewport = D3D11_VIEWPORT;
using RasterizerState = ID3D11RasterizerState;
using DepthStencilState = ID3D11DepthStencilState;
using RenderTargetIDs = std::vector<RenderTargetID>;

struct BlendState
{
	ID3D11BlendState* ptr = nullptr;
};

struct RenderTargetDesc
{
	TextureDesc textureDesc;
	EImageFormat format;
};

struct RenderTarget
{
	ID3D11Resource*	GetTextureResource() const { return texture._tex2D; }

	Texture						texture;
	ID3D11RenderTargetView*		pRenderTargetView = nullptr;
};

struct DepthTargetDesc
{
	TextureDesc textureDesc;
	EImageFormat format;
};

struct DepthTarget
{
	inline ID3D11Resource*	GetTextureResource() const { return texture._tex2D; }
	inline TextureID GetTextureID() const { return texture._id; }

	Texture						texture;
	ID3D11DepthStencilView*		pDepthStencilView;
};

struct PipelineState
{
	ShaderID			shader;
	BufferID			vertexBuffer;
	BufferID			indexBuffer;
	EPrimitiveTopology	topology;
	Viewport			viewPort;
	RasterizerStateID	rasterizerState;
	DepthStencilStateID	depthStencilState;
	BlendStateID		blendState;
	RenderTargetIDs		renderTargets;
	DepthTargetID		depthTargets;
};

struct BufferDesc
{
	EBufferType  mType = EBufferType::BUFFER_TYPE_UNKNOWN;
	EBufferUsage mUsage = EBufferUsage::GPU_READ_WRITE;
	unsigned     mElementCount = 0;
	unsigned     mStride = 0;
	unsigned     mStructureByteStride = 0;
};

struct Buffer
{
	bool			mDirty = true;
	void*			mpCPUData = nullptr;
	ID3D11Buffer*	mpGPUData = nullptr;

	bool			bInitialized = false;
	std::allocator<char> mAllocator;
	BufferDesc		mDesc;

	void Initialize(ID3D11Device* device = nullptr, const void* pData = nullptr);
	void CleanUp();
	void Update(Renderer* pRenderer, const void* pData);

	Buffer(const BufferDesc& desc);
};

struct FullScreenVertexBufferData
{
	vec3 position;
	vec2 uv;
};

struct DefaultVertexBufferData
{
	vec3 position;
	vec3 normal;
	vec3 tangent;
	vec2 uv;
};

#if 0	// TODO: abstract render target descriptor
struct RenderTargetDesc
{
	int width;
	int height;
	EImageFormat format;
	ETextureUsage usage;
	int mipCount;
	int arraySize;

	std::string	 texFileName;
	void* pData;
	int dataPitch;		// used for 2D/3D Textures - how many bytes per row of pixels
	int dataSlicePitch;	// used for 3D Textures

	RenderTargetDesc() :
		width(1),
		height(1),
		format(RGBA32F),
		usage(RESOURCE),
		texFileName(""),
		pData(nullptr),
		dataSlicePitch(0),
		mipCount(1),
		arraySize(1),
	{}

	D3D11_TEXTURE2D_DESC dxDesc;
};
#endif
