package com.xinguoedu.m.media
{
	import com.xinguoedu.consts.PlayerState;
	import com.xinguoedu.consts.StreamStatus;
	import com.xinguoedu.evt.EventBus;
	import com.xinguoedu.evt.media.MediaEvt;
	import com.xinguoedu.m.vo.MediaVO;
	import com.xinguoedu.utils.MetadataUtil;
	
	import flash.display.Sprite;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.media.SoundTransform;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.utils.clearInterval;

	/**
	 * 媒体基类 
	 * @author yatsen_yang
	 * 
	 */	
	public class BaseMedia extends EventDispatcher
	{
		protected var _display:Sprite;		
		protected var _mediaType:String;
		/** 流的当前位置 **/
		protected var _pos:Number;
		/** 视频时长 **/
		protected var _duration:Number = 0;
		protected var _mediaVO:MediaVO;
		protected var _nc:NetConnection;
		protected var _stream:NetStream;
		/** video对象的引用 **/
		protected var _video:Video;
		/** 视频缓存到本地的比例 **/
		protected var _bufferPercent:Number;
		/** 流播放头位置定时器 **/
		protected var _posInterval:uint;
		/** Object with keyframe times and positions. **/
		protected var _keyframes:Object;
		/** 根据seek时间获取到的关键帧的timestamp **/
		protected var _kfTime:Number=0;
		/** 根据seek时间获取到的关键帧的fileposition **/
		protected var _kfFilePos:Number=0;
		/** 是否mp4文件 **/
		protected var _ismp4:Boolean;
		/** 是否快要播放完 **/
		protected var _isNearlyComplete:Boolean =  false;
		/** 是否播放完 **/
		protected var _isComplete:Boolean = false;
		
		public function BaseMedia(mediaType:String)
		{
			this._mediaType = mediaType;
			
			_display = new Sprite();
		}
		
		public function init(mediaVO:MediaVO):void
		{
			_mediaVO = mediaVO;
		}
		
		/**
		 * 开始加载流并播放 
		 * 交给子类重写
		 */		
		public function startLoadAndPlay():void
		{
			
		}
		
		/**
		 * 视频metadata处理函数 
		 * @param info
		 * 
		 */		
		public function onMetaData(info:Object):void
		{
			if (info['seekpoints']) 
			{
				_ismp4 = true;
				_keyframes = convertSeekpoints(info['seekpoints']);
			}
			else
			{
				_ismp4 = false;
				_keyframes = info['keyframes']; //记录关键帧的位置
			}
			
			_duration = info.duration;
			
			EventBus.getInstance().dispatchEvent(new MediaEvt(MediaEvt.MEDIA_METADATA, {w:info.width, h:info.height}));
		}
		
		protected function convertSeekpoints(dat:Object):Object 
		{
			var kfr:Object = {};
			kfr.times = [];
			kfr.filepositions = [];
			for (var j:String in dat)
			{
				kfr.times[j] = Number(dat[j]['time']);
				kfr.filepositions[j] = Number(dat[j]['offset']);
			}
			return kfr;
		}
		
		/**
		 * 获得离指定时间最近的关键帧的位置或者时间
		 * @param sec 指定的时间
		 * @param tme true获取时间，false获取位置
		 * @return 
		 * 
		 */		
		protected function getOffset(sec:Number, tme:Boolean=false):Number 
		{
			return MetadataUtil.getOffset(_keyframes, sec, tme);
		}
		
		public function get display():Sprite
		{
			return _display;
		}
		
		public function play():void
		{
			_isComplete && (_isComplete = false);
			dispatchMediaStateEvt(PlayerState.PLAYING);
		}
		
		public function pause():void
		{
			dispatchMediaStateEvt(PlayerState.PAUSED);
		}
		
		/**
		 * mouse down timeslider 准备拖动 
		 * 
		 */		
		public function mouseDownToSeek():void
		{
			destroyPosTimer();
		}
		
		/**
		 * 拖动视频 
		 * @param sec 拖动的秒数
		 * 
		 */		
		public function seek(sec:Number):void
		{
			if(_stream)
			{
				_stream.seek(sec);
			}
		}
		
		/**
		 * 设置视频的音量 
		 * @param volume 音量大小 0~100
		 * 
		 */		
		public function setVolume(volume:int):void
		{
			if(_stream != null && _stream.soundTransform.volume != volume / 100)
			{
				_stream.soundTransform = new SoundTransform(volume / 100);
			}
		}
		
		/**
		 * 静音或者取消静音 
		 * @param bool
		 * @param volume 取消静音时，恢复的音量值
		 * 
		 */		
		public function mute(bool:Boolean, volume:int):void
		{
			bool ? setVolume(0) : setVolume(volume);
		}
		
		protected function dispatchEvt(type:String):void
		{
			dispatchEvent(new MediaEvt(MediaEvt.MEDIA_INFO, type));
		}
		
		
		protected function dispatchMediaStateEvt(state:String):void
		{
			dispatchEvent(new MediaEvt(MediaEvt.MEDIA_STATE, state));
		}
		
		protected function destroyPosTimer():void
		{
			if(_posInterval)
			{
				clearInterval(_posInterval);
				_posInterval = undefined;	
			}
		}
		
		/**
		 * 流状态处理函数，交给子类重写 
		 * @param evt
		 * 
		 */		
		protected function netStatusHandler(evt:NetStatusEvent):void
		{
			
		}
		
		/**
		 * 加载视频IOError, 由子类继承调用 
		 * @param evt
		 * 
		 */		
		protected function ioErrorHandler(evt:IOErrorEvent=null):void
		{
			dispatchEvt(StreamStatus.LOAD_MEDIA_IOERROR);
		}
		
		/**
		 * 视频快要播放完 
		 * 
		 */		
		protected function playbackNearlyComplete():void
		{
			dispatchEvt(StreamStatus.PLAY_NEARLY_COMPLETE);
		}
		
		/**
		 *  视频播放完
		 */		
		protected function playbackComplete():void
		{
			_isComplete = true;
			_isNearlyComplete = false;
			dispatchEvt(StreamStatus.PLAY_COMPLETE);
		}
		
		/**
		 * 视频是否播放完 
		 * @return 
		 * 
		 */		
		public function get isComplete():Boolean
		{
			return _isComplete;
		}
		
		
		public function dragTimeSliderMoving(sec:Number):void
		{
			
		}
	}
}