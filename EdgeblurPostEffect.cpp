/*==========================================================================
* @ filename	  : EdgeblurPostEffect.CPP 
* @ author : Milong.wu
* @ contact: milongwu@gmail.com
* @ created : 2015-4-15  09:09
* @ purpose : Edge light && blur  when mouse is on
*///==========================================================================
#include "stdafx.h"
#include "SceneManager.h"
#include "EdgeblurPostEffect.h"
#include "IRenderEngine.h"
#include "IRenderSystem.h"
#include "IEffectFileManager.h"
#include "FxMaterial.h"

#include "StagedForwardSceneRender.h"
#include "SceneManager.h"
#include "SubSystemIDs.h"
#include "IGlobalClient.h"
#include "appearance.h"
#include "SceneRender.h"
#include "IBufferManager.h"
#include "Property.h"
#include "ICameraController.h"


static IEffectFile* postEffect = 0;

#define FILTER_CULL(cull) mReverseCull ? reverseCullMode(cull) : cull

IMPLEMENT_CLASS(EdgeblurPostEffect,PostEffect)
IMPLEMENT_CREATOR(EdgeblurPostEffect)

EdgeblurPostEffect::EdgeblurPostEffect()
{
	EffectMacro macro;
	macro.name = "MAX_BONE_NUM";
	macro.define = "59";
	if(postEffect == 0)
	{
		//Shader
		postEffect = getRenderEngine()->getRenderSystem()->getEffectFileManager()->getEffectFile(_T("Shader\\Edgeblur.fx"),&macro, 1);
		if (!postEffect)
		{
			MERRORLN(_T("加载Edgeblur全屏后处理Shader失败！！"));
		}
	}
	resetBlendFactor();

	enableMask = PEM_BLUR;
	enabled = true;
}

EdgeblurPostEffect::~EdgeblurPostEffect()
{
	releaseResources();
}

bool EdgeblurPostEffect::load( Stream &source )
{
	PostEffect::load(source);
	return true;
}

bool EdgeblurPostEffect::save( Stream &dest )
{
	PostEffect::save(dest);
	return true;
}

void EdgeblurPostEffect::releaseResources()
{

}

void EdgeblurPostEffect::notifyDeviceLost()
{

}

/**
* renderlmpl for edge hight light and blur
* @ param IRenderSystem for set render state or texture.., SceneManger for ger render queue and so on
* @ return null
* @ flow: render target-> render state->setupStream-> setTexture-> setTechnique->begin pass->end pass
* @ author Milong.Wu 
*/
void EdgeblurPostEffect::renderImpl( IRenderSystem* pRenderSys, SceneManager* scene )
{
	if(!postEffect) 
		return;

	SceneManager * scenemgr = SUBSYSTEMX(SceneManager,ISceneManager);
	SceneRender * scenerender = scenemgr->getSceneRender(); 
	StagedForwardSceneRender *Stagescenerender=(StagedForwardSceneRender*)scenerender ;

	const RenderQueue::RenderableList& highItems =(*Stagescenerender).specialRenderQueue.getRenderableList((RenderQueueOrder)StagedForwardSceneRender::RENDER_QUEUE_HIGHLIGHT);
	if (highItems.size() <= 0)
		return ;

	uint blurRTT1 = scene->currentView->getFullRGBRTT1();
	uint blurRTT2 = scene->currentView->getFullRGBRTT2();
	float viewSizeFactor = 0.5f;

	if(blurRTT1 == 0 || blurRTT2 == 0)
		return;
	int numRendered = 0;

	uint oldTarget = pRenderSys->getCurrentRenderTarget();

	pRenderSys->setCurrentRenderTarget(blurRTT1);
    // so the unsee part can't be hightlihght
	pRenderSys->setDepthBufferCheckEnabled(true);
	pRenderSys->setDepthBufferFunction(CMP_LESSEQUAL);
	pRenderSys->setDepthBufferWriteEnabled(false);
	pRenderSys->setCullingMode(CULL_NONE);
	//setup common rendering state
	pRenderSys->clearFrameBuffer(ColorValue(0,0,0,0), 1.0f);

	setupRenderingState(pRenderSys);
	//get highlight queue
	
	int colorID = 0;
	int idCount = 0;
	FillMode oldFillMode = pRenderSys->getFillMode();
	bool highlight = false;

	for(size_t qi = 0; qi <highItems.size()  && colorID <Stagescenerender->highLights.num(); ++qi)
	{
		highlight = true;
		IRenderable *renderable = highItems[qi];
		const Appearance& appear = renderable->getAppearance();
		Appearance::Geometry  geo = appear.geometry;
		geo.indexBuffer =  appear.geometry.indexBuffer;     
		if(appear.material[eMaterial_0].renderOrder < RENDER_QUEUE_BLEND && geo.indexBuffer)
		{
			appear.geometry.setupStream(pRenderSys);
			//edgeColor and rimback_biggerFactor  are uniform values defined in this pass of edgeblur.fx (../date/shader) file
			postEffect->setupAutoParameters(renderable);
			postEffect->setVector4("edgeColor", (Vector4*)(&Stagescenerender->highLights(colorID).color));  
			ColorValue *ed = (ColorValue*)(&Stagescenerender->highLights(colorID).color);
			setupRenderingState(pRenderSys);  

			if(appear.material[eMaterial_0].numTextureUnit)
				appear.material[eMaterial_0].setTextureUnit(pRenderSys,0);
			else
				pRenderSys->setTexture(0, 0); 

			//postEffect->setupAutoParameters(renderable);
			uint iPass;
			//"Rimback" is defined in edgeblur.fx (../date/shader) file
			int macAcount=0;
			const EffectMacro *mac = postEffect->getMacros(macAcount);

			// for the weapon can not be paint, as no maco, so use a special technique
			if(geo.isSkinning())
			{
				postEffect->setTechnique("Rimback");
			}
			else{
				postEffect->setTechnique("RimbackNomaco");
			}
			postEffect->begin(&iPass);
			postEffect->beginPass(0);
			pRenderSys->drawRangeIndexedPrimitive(PT_TRIANGLES, geo.indexBuffer->getType(),geo.indexStart,geo.indexCount,geo.vertexStart,geo.vertexEnd);
			postEffect->endPass();
			postEffect->end();
			appear.geometry.resetStream(pRenderSys);
		}
		idCount++;
		if(idCount >= Stagescenerender->highLights(colorID).numRenderable)
		{
			colorID++;
			idCount = 0;
		}
	}

	if(highlight)
	{
		pRenderSys->setCurrentRenderTarget(blurRTT2);
		pRenderSys->clearFrameBuffer(ColorValue(0,0,0,0), 1.0f);
		// use texture in prerender
		pRenderSys->setTexture(0, (ITexture*)pRenderSys->getRenderTargetTexture(blurRTT1));
		//"Edgeblur" is defined in edgeblur.fx (../date/shader) file
		postEffect->setTechnique("pengzhang");
		// set uniform value
		int l,t, w, h;
		pRenderSys->getViewport(l, t, w, h);
		Vector4 viewport_inv_sizeex(1.0f /w, 1.0f /h, 0, 0);
		postEffect->setVector4("viewport_inv_size", &viewport_inv_sizeex);

		renderQuad(pRenderSys, postEffect);
		// for inflation may add a  border line around, so reset the color 
		pRenderSys->setTextureBorderColor(0,ColorValue(0,0,0,0));
		//set new target
		pRenderSys->setCurrentRenderTarget(blurRTT1);
		//be similar to outline color, for scene blend
		pRenderSys->clearFrameBuffer(ColorValue(0,0,0,0), 1.0f);
		// use texture in prerender
		pRenderSys->setTexture(0, (ITexture*)pRenderSys->getRenderTargetTexture(blurRTT2));


		//"Edgeblur" is defined in edgeblur.fx (../date/shader) file
		postEffect->setTechnique("Edgeblur");

		pRenderSys->getViewport(l, t, w, h);
		Vector4 viewport_inv_size(1.0f / w, 1.0f / h, 0, 0);
		postEffect->setVector4("viewport_inv_size", &viewport_inv_size);

		renderQuad(pRenderSys, postEffect);
	}

	// final pass
	pRenderSys->setCurrentRenderTarget(oldTarget);

	pRenderSys->setTexture(0, (ITexture*)pRenderSys->getRenderTargetTexture(blurRTT1));

	postEffect->setTechnique("FinalBlend");
	
	//pRenderSys->setSceneBlending(quadSrcFactor, quadDestFactor);
	renderQuad(pRenderSys, postEffect);

    //reset
	//pRenderSys->setDepthBufferFunction(CMP_GREATEREQUAL);
}

void EdgeblurPostEffect::registerProperties()
{
	PropertySet *psheet = new PropertySet(_T("EdgeblurPostEffect"),_T("PostEffect"));
	PropertySystem::getInstance().registerPropertySet(psheet);
}

void EdgeblurPostEffect::notifyDeviceRestored()
{
}

void EdgeblurPostEffect::setupRenderingState( IRenderSystem* pRenderSys )
{
	pRenderSys->setSceneBlending(SBF_SOURCE_ALPHA, SBF_ONE_MINUS_SOURCE_ALPHA);
	pRenderSys->setAlphaToCoverage(false);
	pRenderSys->setDepthBufferWriteEnabled(true);
	pRenderSys->setDepthBufferFunction(CMP_LESSEQUAL);
	pRenderSys->setDepthBias(0,0);

	pRenderSys->setAlphaCheckEnabled(false);
	pRenderSys->setCullingMode(CULL_CLOCKWISE); 

	pRenderSys->setColorBufferWriteEnabled( 0xFFFFFFFF );
}