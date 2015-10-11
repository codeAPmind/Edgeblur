#ifndef __EDGEBLUR_POST_EFFECT_H__
#define __EDGEBLUR_POST_EFFECT_H__
/*==========================================================================
* @file	  : EdgeblurPostEffect.h 
* @author : Milong.wu  
* @contact:milongwu@gmail.com
* @created : 2015-4-16   
* @purpose : Edge blur for monster and so on
*///==========================================================================
#include "PostEffect.h"

class EdgeblurPostEffect : public PostEffect
{
	DECLARE_CLASS(EdgeblurPostEffect)
	DECLARE_CREATOR(EdgeblurPostEffect)
public:

	EdgeblurPostEffect();
	~EdgeblurPostEffect();

	/**从Stream中load一个对象
	@note 派生类必须要先调用父类的load
	*/
	virtual bool load(Stream &source);

	/**保存对象到Stream中
	@note派生类必须要先调用父类的save
	*/
	virtual bool save(Stream &dest);

	virtual void releaseResources();

	virtual void notifyDeviceLost();

	virtual void notifyDeviceRestored();

	virtual void renderImpl(IRenderSystem* pRenderSystem, SceneManager* scene);

	void setupRenderingState( IRenderSystem* pRenderSys );

	///恢复默认的最终混合参数
	virtual void resetBlendFactor() 
	{
		quadSrcFactor = SBF_ONE;
		quadDestFactor= SBF_ZERO;
	};

	static void registerProperties();
};

#endif // __EDGEBLUR_POST_EFFECT_H__
