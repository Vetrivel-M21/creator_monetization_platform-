import React, { useEffect, useRef, useState, useCallback } from 'react';
import Hls, { type Level } from 'hls.js';
import {
  Play,
  Pause,
  Volume2,
  VolumeX,
  Maximize,
  Minimize,
  Settings,
  Sparkles,
  Check,
  AlertTriangle,
} from 'lucide-react';

interface HLSPlayerProps {
  src: string;
  poster?: string;
  autoPlay?: boolean;
  className?: string;
  onTimeUpdate?: (currentTime: number, duration: number) => void;
  onEnded?: () => void;
}

export const HLSPlayer: React.FC<HLSPlayerProps> = ({
  src,
  poster,
  autoPlay = true,
  className = '',
  onTimeUpdate,
  onEnded,
}) => {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const hlsRef = useRef<Hls | null>(null);

  // Playback state
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [bufferedPercent, setBufferedPercent] = useState(0);
  const [volume, setVolume] = useState(1);
  const [isMuted, setIsMuted] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [isBuffering, setIsBuffering] = useState(false);
  const [showControls, setShowControls] = useState(true);
  const [showSettings, setShowSettings] = useState(false);
  const [settingsTab, setSettingsTab] = useState<'quality' | 'speed'>('quality');
  const [playbackSpeed, setPlaybackSpeed] = useState<number>(1);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [isHls, setIsHls] = useState<boolean>(false);

  // ABR Quality Levels
  const [qualityLevels, setQualityLevels] = useState<Level[]>([]);
  const [currentLevelIndex, setCurrentLevelIndex] = useState<number>(-1); // -1 = Auto
  const [activeHeight, setActiveHeight] = useState<number | null>(null);

  const masterSrcRef = useRef<string>('');
  const availableQualitiesRef = useRef<Level[]>([]);
  const controlsTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const settingsMenuRef = useRef<HTMLDivElement | null>(null);
  const networkRetryCountRef = useRef<number>(0);

  // Close settings popup when clicking outside
  useEffect(() => {
    const handleOutsideClick = (e: MouseEvent) => {
      if (settingsMenuRef.current && !settingsMenuRef.current.contains(e.target as Node)) {
        setShowSettings(false);
      }
    };
    if (showSettings) {
      document.addEventListener('mousedown', handleOutsideClick);
    }
    return () => {
      document.removeEventListener('mousedown', handleOutsideClick);
    };
  }, [showSettings]);

  const handleMouseMove = () => {
    setShowControls(true);
    if (controlsTimeoutRef.current) clearTimeout(controlsTimeoutRef.current);
    if (isPlaying) {
      controlsTimeoutRef.current = setTimeout(() => {
        setShowControls(false);
        setShowSettings(false);
      }, 3000);
    }
  };

  // 1. Initialize HLS or native playback
  useEffect(() => {
    const video = videoRef.current;
    if (!video || !src) return;

    setErrorMsg(null);
    setIsBuffering(true);
    networkRetryCountRef.current = 0;
    setCurrentLevelIndex(-1);
    setActiveHeight(null);
    setQualityLevels([]);

    // Ensure absolute HTTPS URL (never relative, never http on https page)
    let activeSrc = src.trim();
    if (!activeSrc.startsWith('http://') && !activeSrc.startsWith('https://')) {
      activeSrc = 'https://entertainment.aurapictures.online' + (activeSrc.startsWith('/') ? activeSrc : '/' + activeSrc);
    }
    if (typeof window !== 'undefined' && window.location.protocol === 'https:' && activeSrc.startsWith('http://')) {
      activeSrc = activeSrc.replace('http://', 'https://');
    }
    masterSrcRef.current = activeSrc;

    const isHlsStream = activeSrc.includes('.m3u8') || activeSrc.includes('/api/playback/') || activeSrc.includes('/playback/');
    setIsHls(isHlsStream);

    // Destroy existing Hls instance
    if (hlsRef.current) {
      hlsRef.current.destroy();
      hlsRef.current = null;
    }

    if (isHlsStream && Hls.isSupported()) {
      const hls = new Hls({
        maxBufferLength: 30,
        maxMaxBufferLength: 60,
        backBufferLength: 30,
        enableWorker: true,
        lowLatencyMode: false,
        xhrSetup: (xhr, url) => {
          if (typeof window !== 'undefined' && window.location.protocol === 'https:' && url.startsWith('http://')) {
            const secureUrl = url.replace('http://', 'https://');
            xhr.open('GET', secureUrl, true);
          }
        },
      });
      hlsRef.current = hls;

      hls.loadSource(activeSrc);
      hls.attachMedia(video);

      hls.on(Hls.Events.MANIFEST_PARSED, (_, data) => {
        if (data.levels && data.levels.length > 1) {
          availableQualitiesRef.current = data.levels;
          setQualityLevels(data.levels);
        } else if (availableQualitiesRef.current.length > 0) {
          setQualityLevels(availableQualitiesRef.current);
        } else if (data.levels) {
          setQualityLevels(data.levels);
        }
        setIsBuffering(false);
        if (data.levels && data.levels.length > 0) {
          const initialLevel = (hls.currentLevel >= 0 && data.levels[hls.currentLevel]) 
            ? data.levels[hls.currentLevel] 
            : data.levels[0];
          if (initialLevel) {
            setActiveHeight(initialLevel.height);
          }
        }
        if (autoPlay) {
          const p = video.play();
          if (p !== undefined) {
            p.then(() => {
              setIsPlaying(true);
              setIsBuffering(false);
            }).catch(() => {
              // Unmuted autoplay blocked by browser policy. Retry with muted sound:
              video.muted = true;
              setIsMuted(true);
              video.play().then(() => {
                setIsPlaying(true);
                setIsBuffering(false);
              }).catch(() => {
                setIsPlaying(false);
                setIsBuffering(false);
              });
            });
          }
        }
      });

      hls.on(Hls.Events.LEVEL_SWITCHED, (_, data) => {
        const level = hls.levels[data.level];
        if (level) {
          setActiveHeight(level.height);
        }
      });

      const triggerFallback = () => {
        if (hlsRef.current) {
          hlsRef.current.destroy();
          hlsRef.current = null;
        }

        let directMp4 = src;
        if (src.includes('.m3u8')) {
          directMp4 = src.replace('master.m3u8', 'master.mp4').split('?')[0];
        }
        if (!directMp4.startsWith('http://') && !directMp4.startsWith('https://')) {
          directMp4 = (typeof window !== 'undefined' ? window.location.origin : 'https://entertainment.aurapictures.online') + 
            (directMp4.startsWith('/') ? directMp4 : '/' + directMp4);
        }
        directMp4 = directMp4.replace(/^http:\/\//, 'https://');

        if (video.src !== directMp4) {
          setIsBuffering(true);
          video.src = directMp4;
          video.load();
          if (autoPlay) {
            video.play().catch(() => {
              setIsPlaying(false);
              setIsBuffering(false);
            });
          }
        } else {
          setIsBuffering(false);
          setErrorMsg('Stream unavailable — video may still be processing.');
        }
      };

      hls.on(Hls.Events.ERROR, (_, data) => {
        if (!data.fatal) return;

        console.warn('[HLSPlayer] Fatal HLS error:', data.type, data.details, data.response);

        switch (data.type) {
          case Hls.ErrorTypes.NETWORK_ERROR: {
            const statusCode = data.response?.code;
            if (statusCode === 404 || statusCode === 409 || networkRetryCountRef.current >= 2) {
              console.warn('[HLSPlayer] Network error fatal/404/409 — falling back to direct MP4');
              triggerFallback();
            } else {
              networkRetryCountRef.current += 1;
              console.log(`[HLSPlayer] Retrying network stream load (attempt ${networkRetryCountRef.current})...`);
              hls.startLoad();
            }
            break;
          }
          case Hls.ErrorTypes.MEDIA_ERROR:
            hls.recoverMediaError();
            break;
          default:
            triggerFallback();
            break;
        }
      });
    } else if (video.canPlayType('application/vnd.apple.mpegurl') || !isHlsStream) {
      // Native Safari HLS or direct MP4 stream
      video.src = activeSrc;
      video.load();
      if (autoPlay) {
        const p = video.play();
        if (p !== undefined) {
          p.then(() => {
            setIsPlaying(true);
            setIsBuffering(false);
          }).catch(() => {
            video.muted = true;
            setIsMuted(true);
            video.play().then(() => {
              setIsPlaying(true);
              setIsBuffering(false);
            }).catch(() => {
              setIsPlaying(false);
              setIsBuffering(false);
            });
          });
        }
      } else {
        setIsBuffering(false);
      }
    }

    return () => {
      if (hlsRef.current) {
        hlsRef.current.destroy();
        hlsRef.current = null;
      }
    };
  }, [src, autoPlay]);

  // 2. Video element event listeners
  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    const onPlay = () => {
      setIsPlaying(true);
      setIsBuffering(false);
    };
    const onPause = () => {
      setIsPlaying(false);
      setIsBuffering(false);
    };
    const onWaiting = () => {
      if (!video.paused) {
        setIsBuffering(true);
      }
    };
    const onPlaying = () => {
      setIsPlaying(true);
      setIsBuffering(false);
    };
    const onCanPlay = () => {
      setIsBuffering(false);
    };
    const onLoadedData = () => {
      setIsBuffering(false);
    };
    const onLoadedMetadata = () => {
      setDuration(video.duration);
      setIsBuffering(false);
    };
    const onError = () => {
      setIsBuffering(false);
      setIsPlaying(false);
      const code = video.error?.code;
      const message = video.error?.message || 'Error loading media source.';
      console.warn('[HLSPlayer] Video tag error:', code, message);
      setErrorMsg(`Video playback error (${code || 'unknown'}): ${message}`);
    };

    const onTime = () => {
      setCurrentTime(video.currentTime);
      if (onTimeUpdate) onTimeUpdate(video.currentTime, video.duration);

      // Calculate buffer progress
      if (video.buffered.length > 0 && video.duration > 0) {
        const bufferedEnd = video.buffered.end(video.buffered.length - 1);
        setBufferedPercent(Math.min(100, (bufferedEnd / video.duration) * 100));
      }
    };

    const onVideoEnded = () => {
      setIsPlaying(false);
      setIsBuffering(false);
      if (onEnded) onEnded();
    };

    video.addEventListener('play', onPlay);
    video.addEventListener('pause', onPause);
    video.addEventListener('waiting', onWaiting);
    video.addEventListener('playing', onPlaying);
    video.addEventListener('canplay', onCanPlay);
    video.addEventListener('loadeddata', onLoadedData);
    video.addEventListener('loadedmetadata', onLoadedMetadata);
    video.addEventListener('timeupdate', onTime);
    video.addEventListener('ended', onVideoEnded);
    video.addEventListener('error', onError);

    return () => {
      video.removeEventListener('play', onPlay);
      video.removeEventListener('pause', onPause);
      video.removeEventListener('waiting', onWaiting);
      video.removeEventListener('playing', onPlaying);
      video.removeEventListener('canplay', onCanPlay);
      video.removeEventListener('loadeddata', onLoadedData);
      video.removeEventListener('loadedmetadata', onLoadedMetadata);
      video.removeEventListener('timeupdate', onTime);
      video.removeEventListener('ended', onVideoEnded);
      video.removeEventListener('error', onError);
    };
  }, [onTimeUpdate, onEnded]);

  // Controls Handlers
  const togglePlay = useCallback(() => {
    const video = videoRef.current;
    if (!video) return;
    if (video.paused) {
      setIsBuffering(true);
      const p = video.play();
      if (p !== undefined) {
        p.then(() => {
          setIsPlaying(true);
          setIsBuffering(false);
        }).catch((err) => {
          console.warn('[HLSPlayer] Unmuted play blocked, retrying muted:', err);
          video.muted = true;
          setIsMuted(true);
          video.play().then(() => {
            setIsPlaying(true);
            setIsBuffering(false);
          }).catch((err2) => {
            console.error('[HLSPlayer] Play completely failed:', err2);
            setIsPlaying(false);
            setIsBuffering(false);
          });
        });
      }
    } else {
      video.pause();
      setIsPlaying(false);
      setIsBuffering(false);
    }
  }, []);

  const handleSeek = (e: React.ChangeEvent<HTMLInputElement>) => {
    const video = videoRef.current;
    if (!video || !duration) return;
    const seekTime = (parseFloat(e.target.value) / 100) * duration;
    video.currentTime = seekTime;
    setCurrentTime(seekTime);
  };

  const handleVolumeChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const video = videoRef.current;
    const val = parseFloat(e.target.value);
    setVolume(val);
    if (video) {
      video.volume = val;
      video.muted = val === 0;
      setIsMuted(val === 0);
    }
  };

  const toggleMute = () => {
    const video = videoRef.current;
    if (!video) return;
    if (isMuted) {
      video.muted = false;
      setIsMuted(false);
      video.volume = volume || 0.8;
    } else {
      video.muted = true;
      setIsMuted(true);
    }
  };

  const toggleFullscreen = () => {
    const container = containerRef.current;
    if (!container) return;

    if (!document.fullscreenElement) {
      container.requestFullscreen?.().then(() => setIsFullscreen(true)).catch(() => {});
    } else {
      document.exitFullscreen?.().then(() => setIsFullscreen(false)).catch(() => {});
    }
  };

  const selectQuality = (index: number) => {
    if (!hlsRef.current || !videoRef.current) return;
    
    const video = videoRef.current;
    const curTime = video.currentTime;
    const wasPlaying = !video.paused;

    setCurrentLevelIndex(index);

    const activeLevels = availableQualitiesRef.current.length > 0 
      ? availableQualitiesRef.current 
      : qualityLevels;

    if (index === -1) {
      // Auto (Adaptive): reload master playlist with full ABR ladder
      setActiveHeight(null);
      hlsRef.current.currentLevel = -1;
      if (masterSrcRef.current && masterSrcRef.current !== hlsRef.current.url) {
        hlsRef.current.loadSource(masterSrcRef.current);
      }
    } else {
      const targetLevel = activeLevels[index];
      if (targetLevel) {
        setActiveHeight(targetLevel.height);
        
        // ARMSS-OTT pattern: stream directly from that rendition's variant playlist
        const renditionUrl = (targetLevel.url && targetLevel.url[0]) ? targetLevel.url[0] : '';
        if (renditionUrl) {
          hlsRef.current.loadSource(renditionUrl);
        } else {
          hlsRef.current.currentLevel = index;
        }
      }
    }

    // Seamlessly restore playback time without stutter
    const restoreTime = () => {
      try {
        if (curTime > 0) {
          video.currentTime = curTime;
        }
        if (wasPlaying) {
          video.play().catch(() => {});
        }
      } catch (_) {}
    };

    hlsRef.current.once(Hls.Events.LEVEL_LOADED, restoreTime);

    // Immediate micro-nudge for video decoder if paused
    try {
      if (curTime > 0.01) {
        video.currentTime = curTime - 0.001;
      } else if (video.duration > 0.1) {
        video.currentTime = curTime + 0.005;
      }
    } catch (_) {}

    setTimeout(() => {
      setShowSettings(false);
    }, 200);
  };

  const selectSpeed = (speed: number) => {
    setPlaybackSpeed(speed);
    if (videoRef.current) {
      videoRef.current.playbackRate = speed;
    }
    setTimeout(() => {
      setShowSettings(false);
    }, 200);
  };

  const sortedQualityLevels = qualityLevels
    .map((lvl, originalIndex) => ({ ...lvl, originalIndex }))
    .filter((lvl, idx, arr) => arr.findIndex((x) => x.height === lvl.height) === idx)
    .sort((a, b) => b.height - a.height);

  const formatTime = (secs: number) => {
    if (isNaN(secs)) return '0:00';
    const m = Math.floor(secs / 60);
    const s = Math.floor(secs % 60);
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  const progressPercent = duration > 0 ? (currentTime / duration) * 100 : 0;

  return (
    <div
      ref={containerRef}
      onMouseMove={handleMouseMove}
      className={`relative w-full h-full bg-black group select-none flex items-center justify-center overflow-hidden ${className}`}
    >
      {/* Native Video Element */}
      <video
        ref={videoRef}
        poster={poster}
        playsInline
        onClick={togglePlay}
        className="w-full h-full object-contain cursor-pointer"
      />

      {/* Buffering Spinner: only show when video is actively attempting to play and buffering */}
      {isBuffering && isPlaying && (
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none bg-black/25">
          <div className="w-12 h-12 rounded-full border-3 border-emerald-500/20 border-t-emerald-400 animate-spin" />
        </div>
      )}

      {/* Error Fallback Banner */}
      {errorMsg && (
        <div className="absolute top-4 left-4 right-4 p-3 rounded-xl bg-red-500/20 border border-red-500/30 text-xs text-red-200 flex items-center gap-2">
          <AlertTriangle size={15} />
          <span>{errorMsg}</span>
        </div>
      )}

      {/* Playback Controls Overlay */}
      <div
        className={`absolute inset-0 pointer-events-none flex flex-col justify-between transition-opacity duration-300 ${
          showControls || !isPlaying ? 'opacity-100' : 'opacity-0'
        }`}
      >
        {/* Top Bar (Active Quality Pill) */}
        <div className="p-4 flex items-center justify-between pointer-events-auto bg-gradient-to-b from-black/80 via-black/40 to-transparent">
          <div className="flex items-center gap-2">
            <span className="px-2.5 py-0.5 rounded-full bg-black/60 border border-white/10 text-[10px] font-mono text-emerald-400 font-semibold flex items-center gap-1.5 backdrop-blur-md">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
              {isHls
                ? (activeHeight ? `${activeHeight}p` : 'HLS ABR')
                : (activeHeight ? `${activeHeight}p` : 'Direct MP4')}
            </span>
            {isHls && currentLevelIndex === -1 && (
              <span className="text-[10px] text-slate-400 font-mono">Seamless Auto</span>
            )}
            {isHls && currentLevelIndex !== -1 && (
              <span className="text-[10px] text-blue-400 font-mono font-semibold">Locked</span>
            )}
            {!isHls && (
              <span className="text-[10px] text-amber-400 font-mono">Direct Source</span>
            )}
          </div>
        </div>

        {/* Center Big Play Button (when paused) */}
        {!isPlaying && (
          <div className="self-center pointer-events-auto">
            <button
              onClick={togglePlay}
              className="w-16 h-16 rounded-full bg-white/90 hover:bg-white text-black flex items-center justify-center shadow-2xl transform active:scale-95 transition-all cursor-pointer"
            >
              <Play size={26} className="fill-black ml-1" />
            </button>
          </div>
        )}

        {/* Bottom Controls Bar */}
        <div className="p-4 pt-8 bg-gradient-to-t from-slate-950/95 via-slate-950/60 to-transparent pointer-events-auto space-y-2.5">
          {/* Timeline Scrub Bar */}
          <div className="relative w-full h-1.5 bg-white/20 rounded-full group/timeline cursor-pointer flex items-center">
            {/* Buffered Progress */}
            <div
              className="absolute left-0 top-0 bottom-0 bg-white/30 rounded-full pointer-events-none"
              style={{ width: `${bufferedPercent}%` }}
            />
            {/* Played Progress */}
            <div
              className="absolute left-0 top-0 bottom-0 bg-[#2563EB] rounded-full pointer-events-none shadow-[0_0_8px_rgba(37,99,235,0.6)]"
              style={{ width: `${progressPercent}%` }}
            />
            {/* Interactive Seek Input */}
            <input
              type="range"
              min="0"
              max="100"
              step="0.1"
              value={progressPercent || 0}
              onChange={handleSeek}
              className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
            />
          </div>

          <div className="flex items-center justify-between text-xs text-white">
            <div className="flex items-center gap-3">
              {/* Play / Pause Toggle */}
              <button
                onClick={togglePlay}
                className="p-1.5 rounded-lg text-white hover:text-[#2563EB] hover:bg-white/10 transition-colors cursor-pointer"
              >
                {isPlaying ? <Pause size={17} /> : <Play size={17} className="fill-white" />}
              </button>

              {/* Volume / Mute */}
              <div className="flex items-center gap-2 group/volume">
                <button
                  onClick={toggleMute}
                  className="p-1.5 rounded-lg text-white hover:text-[#2563EB] hover:bg-white/10 transition-colors cursor-pointer"
                >
                  {isMuted || volume === 0 ? <VolumeX size={17} /> : <Volume2 size={17} />}
                </button>
                <input
                  type="range"
                  min="0"
                  max="1"
                  step="0.05"
                  value={isMuted ? 0 : volume}
                  onChange={handleVolumeChange}
                  className="w-16 h-1 bg-white/20 accent-[#2563EB] rounded-full cursor-pointer hidden sm:block"
                />
              </div>

              {/* Time Display */}
              <span className="font-mono text-[11px] text-slate-300">
                {formatTime(currentTime)} / {formatTime(duration)}
              </span>
            </div>

            <div className="flex items-center gap-2">
              {/* Settings & Quality Selector */}
              <div className="relative" ref={settingsMenuRef}>
                <button
                  onClick={() => setShowSettings(!showSettings)}
                  className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-white/10 hover:bg-white/20 text-[11px] font-mono text-white transition-colors cursor-pointer"
                  title="Player Settings & Quality"
                >
                  <Settings size={13} className={showSettings ? 'rotate-45 transition-transform' : 'transition-transform'} />
                  <span>
                    {isHls
                      ? (qualityLevels.length > 0
                          ? (currentLevelIndex === -1 ? 'Auto' : `${qualityLevels[currentLevelIndex]?.height}p`)
                          : (activeHeight ? `${activeHeight}p` : 'Auto'))
                      : 'Source'}
                    {playbackSpeed !== 1 && ` • ${playbackSpeed}x`}
                  </span>
                </button>

                {/* Settings Popup */}
                {showSettings && (
                  <div className="absolute right-0 bottom-10 w-56 max-h-[calc(100%-3rem)] flex flex-col p-2.5 rounded-2xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-2xl z-50 animate-fade-in text-[#0F172A] overflow-hidden">
                    {/* Header Tabs: Quality & Speed */}
                    <div className="flex items-center gap-1 p-0.5 bg-slate-100 rounded-xl mb-2 shrink-0">
                      <button
                        type="button"
                        onClick={() => setSettingsTab('quality')}
                        className={`flex-1 py-1 text-[11px] font-semibold rounded-lg transition-colors cursor-pointer text-center ${
                          settingsTab === 'quality'
                            ? 'bg-white text-[#2563EB] shadow-xs'
                            : 'text-[#64748B] hover:text-[#0F172A]'
                        }`}
                      >
                        Quality {currentLevelIndex === -1 ? '(Auto)' : `(${qualityLevels[currentLevelIndex]?.height}p)`}
                      </button>
                      <button
                        type="button"
                        onClick={() => setSettingsTab('speed')}
                        className={`flex-1 py-1 text-[11px] font-semibold rounded-lg transition-colors cursor-pointer text-center ${
                          settingsTab === 'speed'
                            ? 'bg-white text-[#2563EB] shadow-xs'
                            : 'text-[#64748B] hover:text-[#0F172A]'
                        }`}
                      >
                        Speed ({playbackSpeed}x)
                      </button>
                    </div>

                    {/* Scrollable Tab Content */}
                    <div className="overflow-y-auto overscroll-contain space-y-1 pr-0.5">
                      {settingsTab === 'quality' && (
                        <div>
                          <div className="px-1.5 py-0.5 text-[10px] font-mono uppercase tracking-wider text-[#64748B] flex items-center justify-between mb-1">
                            <span>Resolution</span>
                            <span className={`text-[9px] font-bold ${isHls ? 'text-emerald-600' : 'text-amber-600'}`}>
                              {isHls ? (currentLevelIndex === -1 ? 'Adaptive Auto' : 'Manual Lock') : 'Single Stream'}
                            </span>
                          </div>

                          {isHls && qualityLevels.length > 0 ? (
                            <div className="space-y-1">
                              <button
                                type="button"
                                onClick={() => selectQuality(-1)}
                                className={`w-full flex items-center justify-between px-2.5 py-1.5 rounded-xl text-xs transition-colors cursor-pointer ${
                                  currentLevelIndex === -1 ? 'bg-[#E0EDFF] text-[#1D4ED8] font-bold' : 'text-[#0F172A] hover:bg-[#F0F6FF]'
                                }`}
                              >
                                <div className="flex items-center gap-1.5">
                                  <Sparkles size={12} className="text-[#2563EB]" />
                                  <span>Auto (Adaptive)</span>
                                </div>
                                {currentLevelIndex === -1 && <Check size={13} className="text-[#2563EB]" />}
                              </button>

                              {sortedQualityLevels.map((lvl) => (
                                <button
                                  type="button"
                                  key={lvl.originalIndex}
                                  onClick={() => selectQuality(lvl.originalIndex)}
                                  className={`w-full flex items-center justify-between px-2.5 py-1.5 rounded-xl text-xs font-mono transition-colors cursor-pointer ${
                                    currentLevelIndex === lvl.originalIndex ? 'bg-[#E0EDFF] text-[#1D4ED8] font-bold' : 'text-[#0F172A] hover:bg-[#F0F6FF]'
                                  }`}
                                >
                                  <span>{lvl.height}p ({Math.round(lvl.bitrate / 1000)} kbps)</span>
                                  {currentLevelIndex === lvl.originalIndex && <Check size={13} className="text-[#2563EB]" />}
                                </button>
                              ))}
                            </div>
                          ) : (
                            <div className="px-2.5 py-2 text-[11px] text-[#475569] bg-[#F8FAFC] border border-[#E2E8F0] rounded-xl space-y-1">
                              <div className="flex items-center justify-between font-semibold text-[#1E293B]">
                                <span>Original Source (Direct MP4)</span>
                                <Check size={13} className="text-[#2563EB]" />
                              </div>
                              <p className="text-[10px] text-[#64748B] leading-tight">
                                Multi-bitrate ladders are active on HLS transcoded videos.
                              </p>
                            </div>
                          )}
                        </div>
                      )}

                      {settingsTab === 'speed' && (
                        <div>
                          <div className="px-1.5 py-0.5 text-[10px] font-mono uppercase tracking-wider text-[#64748B] mb-1">
                            Playback Speed
                          </div>
                          <div className="grid grid-cols-3 gap-1">
                            {[0.5, 0.75, 1, 1.25, 1.5, 2].map((spd) => (
                              <button
                                type="button"
                                key={spd}
                                onClick={() => selectSpeed(spd)}
                                className={`px-2 py-1.5 rounded-lg text-xs font-mono transition-colors cursor-pointer text-center ${
                                  playbackSpeed === spd
                                    ? 'bg-[#E0EDFF] text-[#1D4ED8] font-bold'
                                    : 'text-[#0F172A] hover:bg-[#F0F6FF]'
                                }`}
                              >
                                {spd === 1 ? '1x Normal' : `${spd}x`}
                              </button>
                            ))}
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                )}
              </div>

              {/* Fullscreen Toggle */}
              <button
                onClick={toggleFullscreen}
                className="p-1.5 rounded-lg text-white hover:text-[#2563EB] hover:bg-white/10 transition-colors cursor-pointer"
              >
                {isFullscreen ? <Minimize size={17} /> : <Maximize size={17} />}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
