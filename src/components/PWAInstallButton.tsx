import { useState } from 'react';
import { useOnlineStatus, usePWAInstall } from '../hooks/usePWA';

export function PWAInstallButton() {
  const { isInstallable, isInstalled, isIOS, install } = usePWAInstall();
  const [showIOSGuide, setShowIOSGuide] = useState(false);

  if (isInstalled) {
    return null;
  }

  if (isInstallable) {
    return (
      <button
        type="button"
        onClick={install}
        title="Install Offline App"
        aria-label="Install Offline App"
        className="h-11 px-3.5 rounded-xl bg-white/95 border border-[#1E3A5F]/20 shadow-[0_3px_0_rgba(15,39,68,0.14)] flex items-center gap-1.5 text-[#15325B] text-xs font-extrabold hover:bg-white transition-transform duration-150 active:scale-95 active:translate-y-0.5 cursor-pointer"
      >
        <svg
          className="w-4 h-4 text-[#0EA5E9]"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth="2.4"
            d="M4 16v2a2 2 0 002 2h12a2 2 0 002-2v-2m-4-4l-4 4m0 0l-4-4m4 4V4"
          />
        </svg>
        <span>Install</span>
      </button>
    );
  }

  if (isIOS) {
    return (
      <>
        <button
          type="button"
          onClick={() => setShowIOSGuide(true)}
          title="Install on iOS"
          aria-label="Install on iOS"
          className="h-11 px-3 rounded-xl bg-white/95 border border-[#1E3A5F]/20 shadow-[0_3px_0_rgba(15,39,68,0.14)] flex items-center gap-1.5 text-[#15325B] text-xs font-extrabold hover:bg-white cursor-pointer"
        >
          <span>Install</span>
        </button>

        {showIOSGuide && (
          <div
            className="fixed inset-0 z-50 flex items-center justify-center bg-[#15325B]/45 p-4"
            onClick={() => setShowIOSGuide(false)}
          >
            <div
              className="w-full max-w-xs rounded-[20px] bg-[#FCFDFF] border-2 border-[#1E3A5F]/20 p-5 shadow-[0_8px_0_rgba(15,39,68,0.22)] text-center"
              onClick={(e) => e.stopPropagation()}
            >
              <h3 className="text-base font-black text-[#15325B]">
                Install on iPhone / iPad
              </h3>
              <p className="mt-2 text-xs font-semibold text-[#475569] leading-relaxed">
                1. Tap the <strong>Share</strong> button in Safari.
                <br />
                2. Tap <strong>Add to Home Screen</strong> to play offline
                anytime.
              </p>
              <button
                type="button"
                onClick={() => setShowIOSGuide(false)}
                className="mt-4 w-full h-10 rounded-xl bg-[#0EA5E9] text-white text-xs font-black shadow-[0_3px_0_#0369A1] cursor-pointer"
              >
                Got It
              </button>
            </div>
          </div>
        )}
      </>
    );
  }

  return null;
}

export function OfflineIndicator() {
  const isOnline = useOnlineStatus();

  if (isOnline) return null;

  return (
    <div className="pointer-events-none fixed bottom-3 left-3 z-30 flex items-center gap-2 rounded-xl bg-[#15325B]/90 px-3 py-1.5 text-[11px] font-extrabold text-white shadow-md">
      <span className="h-2 w-2 rounded-full bg-[#22C55E]" />
      <span>Offline Mode · Ready to Play</span>
    </div>
  );
}
