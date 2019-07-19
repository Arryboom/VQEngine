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

#include "Engine.h"

#include "Renderer/Renderer.h"

using namespace VQEngine;



std::mutex Engine::mLoadRenderingMutex;


#if USE_DX12


void Engine::StartThreads()
{

}
void Engine::StopThreads()
{

}



void Engine::RenderThread()	
{

}

void Engine::SimulationThread()
{

}

void Engine::LoadingThread()
{

}

#else


void Engine::StartRenderThread()
{
	mbStopRenderThread = false;
	mRenderThread = std::thread(&Engine::RenderThread, this);
}


void Engine::StopRenderThreadAndWait()
{
	mbStopRenderThread = true;
	mSignalRender.notify_all();
	mRenderThread.join();
}


void Engine::RenderThread()	// This thread is currently only used during loading.
{
	constexpr bool bOneTimeLoadingScreenRender = false; // We're looping;
	while (!mbStopRenderThread)
	{
		std::unique_lock<std::mutex> lck(mLoadRenderingMutex);
		mSignalRender.wait(lck); /// , [=]() { return !mbStopRenderThread; });


#if USE_DX12
		// TODO-DX12: GET SWAPCHAIN IMAGE
		if (mbLoading)
		{
			continue;
		}
		mpCPUProfiler->BeginEntry("CPU");

		mpGPUProfiler->BeginProfile(mFrameCount);
		mpGPUProfiler->BeginEntry("GPU");

		mpRenderer->BeginFrame();
#else
		mpCPUProfiler->EndProfile();
		mpCPUProfiler->BeginProfile();
		mpCPUProfiler->BeginEntry("CPU");

		mpGPUProfiler->BeginProfile(mFrameCount);
		mpGPUProfiler->BeginEntry("GPU");

		mpRenderer->BeginFrame();
#endif

		RenderLoadingScreen(bOneTimeLoadingScreenRender);
		RenderUI();

		mpGPUProfiler->EndEntry();	// GPU
		mpGPUProfiler->EndProfile(mFrameCount);


		mpCPUProfiler->BeginEntry("Present");
#if USE_DX12
		// TODO-DX12: PRESENT QUEUE
#else
		mpRenderer->EndFrame();
#endif
		mpCPUProfiler->EndEntry(); // Present


		mpCPUProfiler->EndEntry();	// CPU
		///fmpCPUProfiler->StateCheck();
		mAccumulator = 0.0f;
		++mFrameCount;
	}

	// when loading is finished, we use the same signal variable to signal
	// the update thread (which woke this thread up in the first place)
	mpCPUProfiler->Clear();
	mpGPUProfiler->Clear();
	mSignalRender.notify_all();
}


#endif