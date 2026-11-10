import React, { useState, useEffect } from 'react';
import { Header } from './components/layout/Header';
import { Sidebar } from './components/layout/Sidebar';
import { MobileNav } from './components/layout/MobileNav';
import { ExploreView } from './views/ExploreView';
import { SubscriptionsView } from './views/SubscriptionsView';
import { LibraryView } from './views/LibraryView';
import { StudioView } from './views/StudioView';
import { AdminView } from './views/AdminView';
import { ReelsFeed } from './components/feed/ReelsFeed';
import { CommentsDrawer } from './components/feed/CommentsDrawer';
import { AuthModal } from './components/modals/AuthModal';
import { UploadModal } from './components/modals/UploadModal';
import { TheaterModal } from './components/modals/TheaterModal';
import { KYCModal } from './components/modals/KYCModal';
import { WithdrawModal } from './components/modals/WithdrawModal';
import { SupportChatModal } from './components/modals/SupportChatModal';
import { LegalModal } from './components/modals/LegalModal';
import { AuthRequiredModal, type AuthGateAction } from './components/modals/AuthRequiredModal';
import { videoService } from './services/videoService';
import { walletService } from './services/walletService';
import { authService } from './services/authService';
import type {
  User,
  Video,
  WalletBalance,
  QuotaProgress,
  MainNavTab,
  StudioSection,
  ReelComment,
} from './types';
import './App.css';

export function App() {
  // Navigation & View States
  const [activeTab, setActiveTabState] = useState<MainNavTab>(() => {
    const saved = sessionStorage.getItem('armss_active_tab') as MainNavTab | null;
    return saved || 'discover';
  });

  const setActiveTab = (tab: MainNavTab) => {
    sessionStorage.setItem('armss_active_tab', tab);
    setActiveTabState(tab);
  };

  const [studioSubTab, setStudioSubTab] = useState<StudioSection>('dashboard');
  const [searchQuery, setSearchQuery] = useState('');

  // Authentication State
  const [user, setUser] = useState<User | null>(() => authService.getStoredUser());

  // Data States
  const [videos, setVideos] = useState<Video[]>([]);
  const [wallet, setWallet] = useState<WalletBalance | null>(null);
  const [quota, setQuota] = useState<QuotaProgress | null>(null);
  const [likedVideosMap, setLikedVideosMap] = useState<Record<string, boolean>>({});
  const [bookmarkedVideosMap, setBookmarkedVideosMap] = useState<Record<string, boolean>>({});
  const [subscribedCreatorsMap, setSubscribedCreatorsMap] = useState<Record<string, boolean>>({});
  const [commentsMap, setCommentsMap] = useState<Record<string, ReelComment[]>>({});

  // Modals & Drawers
  const [isAuthOpen, setIsAuthOpen] = useState(false);
  const [isUploadOpen, setIsUploadOpen] = useState(false);
  const [isKYCOpen, setIsKYCOpen] = useState(false);
  const [isWithdrawOpen, setIsWithdrawOpen] = useState(false);
  const [isSupportOpen, setIsSupportOpen] = useState(false);
  const [legalModalState, setLegalModalState] = useState<{
    isOpen: boolean;
    tab: 'terms' | 'privacy';
  }>({
    isOpen: false,
    tab: 'terms',
  });
  const [theaterVideo, setTheaterVideo] = useState<Video | null>(null);

  // Active Comment Drawer
  const [activeCommentVideoId, setActiveCommentVideoId] = useState<string | null>(null);
  const [newCommentText, setNewCommentText] = useState('');

  // Toast Notification State
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3000);
  };

  const [authGateState, setAuthGateState] = useState<{
    isOpen: boolean;
    action: AuthGateAction;
    details?: string;
  }>({
    isOpen: false,
    action: 'like',
  });

  // Load Videos & Wallet
  const loadVideos = async () => {
    try {
      // Public feed strictly contains approved videos only
      const feedData = await videoService.getFeed();
      setVideos(feedData);
    } catch {
      // Fallback
      setVideos(videoService.getFallbackVideos());
    }
  };

  const loadWalletAndQuotas = async () => {
    if (!user) return;
    try {
      const [walletData, quotaData] = await Promise.all([
        walletService.getWallet(),
        walletService.getQuotas(),
      ]);
      setWallet(walletData);
      setQuota(quotaData);
    } catch (e) {
      console.warn('Wallet load warning:', e);
    }
  };

  useEffect(() => {
    loadVideos();
  }, []);

  useEffect(() => {
    if (user) {
      loadVideos();
      loadWalletAndQuotas();
      authService.getProfile().then((freshProfile) => {
        if (freshProfile && freshProfile.id) {
          setUser((prev) => ({ ...prev, ...freshProfile }));
        }
      }).catch(() => {});
    }
  }, [user?.id]);

  // Auth Handlers
  const handleAuthSuccess = (_token: string, authedUser: User) => {
    if (_token && authedUser) {
      authService.setStoredAuth(_token, authedUser);
    }
    setUser(authedUser);
    setIsAuthOpen(false);
    showToast(`Welcome ${authedUser.channelName || authedUser.name}!`);
    loadWalletAndQuotas();
  };

  const handleLogout = () => {
    authService.logout();
    sessionStorage.removeItem('armss_active_tab');
    setUser(null);
    setWallet(null);
    setQuota(null);
    setActiveTab('discover');
    showToast('Logged out successfully');
  };

  // Interaction Handlers
  const handleLike = async (videoId: string) => {
    if (!user) {
      setAuthGateState({ isOpen: true, action: 'like' });
      return;
    }
    const isCurrentlyLiked = !!likedVideosMap[videoId];
    setLikedVideosMap((prev) => ({ ...prev, [videoId]: !isCurrentlyLiked }));

    setVideos((prev) =>
      prev.map((v) =>
        v.id === videoId
          ? { ...v, likes: isCurrentlyLiked ? Math.max(0, (v.likes || 0) - 1) : (v.likes || 0) + 1 }
          : v
      )
    );

    try {
      await videoService.likeVideo(videoId);
    } catch {
      // Optimistic update
    }
  };

  const handleBookmark = (videoId: string) => {
    const isSaved = !!bookmarkedVideosMap[videoId];
    setBookmarkedVideosMap((prev) => ({ ...prev, [videoId]: !isSaved }));
    showToast(isSaved ? 'Removed from saved' : 'Saved to Library bookmarks');
  };

  const handleShare = async (videoOrId: Video | string) => {
    const vid = typeof videoOrId === 'string' ? videos.find((v) => v.id === videoOrId) : videoOrId;
    if (navigator.share && vid) {
      try {
        await navigator.share({
          title: vid.title,
          text: `Watch ${vid.title} on ARMSS Entertainment`,
          url: window.location.href,
        });
      } catch {
        // user dismissed share dialog
      }
    } else {
      navigator.clipboard.writeText(window.location.href);
      showToast('Video link copied to clipboard!');
    }
  };

  const handleSubscribe = (creatorHandle: string) => {
    if (!user) {
      setAuthGateState({ isOpen: true, action: 'subscribe', details: `@${creatorHandle}` });
      return;
    }
    const isSubbed = !!subscribedCreatorsMap[creatorHandle];
    setSubscribedCreatorsMap((prev) => ({ ...prev, [creatorHandle]: !isSubbed }));
    showToast(isSubbed ? `Unsubscribed from @${creatorHandle}` : `Subscribed to @${creatorHandle}!`);
  };

  const handleOpenComments = (videoIdOrVideo: string | Video) => {
    const id = typeof videoIdOrVideo === 'string' ? videoIdOrVideo : videoIdOrVideo.id;
    setActiveCommentVideoId(id);
    if (!commentsMap[id]) {
      videoService.getComments(id).then((cmts) => {
        setCommentsMap((prev) => ({ ...prev, [id]: cmts }));
      });
    }
  };

  const handlePostComment = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) {
      setAuthGateState({ isOpen: true, action: 'comment' });
      return;
    }
    if (!activeCommentVideoId || !newCommentText.trim()) return;

    const newComment: ReelComment = {
      id: `c-${Date.now()}`,
      videoId: activeCommentVideoId,
      userId: user?.id || 'usr-guest',
      userName: user?.name || 'Guest Explorer',
      userHandle: user?.handle || 'guest',
      userAvatar: user?.avatar || 'https://api.dicebear.com/7.x/bottts/svg?seed=guest',
      text: newCommentText.trim(),
      likes: 0,
      createdAt: new Date().toISOString(),
    };

    setCommentsMap((prev) => ({
      ...prev,
      [activeCommentVideoId]: [newComment, ...(prev[activeCommentVideoId] || [])],
    }));

    setVideos((prev) =>
      prev.map((v) =>
        v.id === activeCommentVideoId ? { ...v, commentsCount: (v.commentsCount || 0) + 1 } : v
      )
    );

    setNewCommentText('');
    try {
      await videoService.postComment(activeCommentVideoId, newCommentText);
    } catch {
      // optimistic
    }
  };

  // Studio Navigation Helpers
  const handleNavigateStudio = (section: StudioSection) => {
    setActiveTab('studio');
    setStudioSubTab(section);
  };

  // Derived video lists
  const filteredVideos = searchQuery.trim()
    ? videos.filter(
        (v) =>
          v.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
          v.category.toLowerCase().includes(searchQuery.toLowerCase()) ||
          (v.creatorName || v.creator_name || '').toLowerCase().includes(searchQuery.toLowerCase())
      )
    : videos;

  const savedVideos = videos.filter((v) => bookmarkedVideosMap[v.id]);
  const likedVideosList = videos.filter((v) => likedVideosMap[v.id]);

  return (
    <div className="ott-shell">
      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed top-5 left-1/2 -translate-x-1/2 z-[100] px-4 py-2.5 rounded-full bg-[#12151D]/95 backdrop-blur-2xl border border-white/[0.08] text-xs font-semibold text-[#F5F5F7] shadow-[0_20px_50px_rgba(0,0,0,0.8),inset_0_1px_0_0_rgba(255,255,255,0.08)] animate-fade-in flex items-center gap-2.5">
          <div className="w-2 h-2 rounded-full bg-[#10B981] animate-ping" />
          <span>{toastMessage}</span>
        </div>
      )}

      {/* Desktop Left Sidebar (Fixed) */}
      <Sidebar
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        user={user}
        onOpenUpload={() => (user ? setIsUploadOpen(true) : setIsAuthOpen(true))}
        onOpenAuth={() => setIsAuthOpen(true)}
        onLogout={handleLogout}
        onOpenSupport={() => (user ? setIsSupportOpen(true) : setIsAuthOpen(true))}
        onOpenTerms={() => setLegalModalState({ isOpen: true, tab: 'terms' })}
        onOpenPrivacy={() => setLegalModalState({ isOpen: true, tab: 'privacy' })}
      />

      {/* Main Center Content Column (Header + Dynamic View) */}
      <div className="ott-main-column">
        {/* Sticky Header */}
        <Header
          searchQuery={searchQuery}
          setSearchQuery={setSearchQuery}
          user={user}
          kyc={null}
          onOpenUpload={() => (user ? setIsUploadOpen(true) : setIsAuthOpen(true))}
          onOpenAuth={() => setIsAuthOpen(true)}
          onLogout={handleLogout}
          onNavigateStudio={handleNavigateStudio}
          onOpenKYC={() => (user ? setIsKYCOpen(true) : setIsAuthOpen(true))}
          onNavigateAdmin={() => setActiveTab('admin')}
          onOpenSupport={() => (user ? setIsSupportOpen(true) : setIsAuthOpen(true))}
        />

        {/* Scrollable Main View Container (Sidebar & Header remain fixed) */}
        <main className="ott-scroll-view">
          {activeTab === 'discover' && (
            <ExploreView
              videos={filteredVideos}
              onSelectVideo={(v) => setTheaterVideo(v)}
              onNavigateTab={(tab) => setActiveTab(tab as MainNavTab)}
            />
          )}

          {activeTab === 'feed' && (
            <div className="h-[calc(100vh-120px)] flex justify-center">
              <ReelsFeed
                videos={filteredVideos}
                subscribedCreators={subscribedCreatorsMap}
                bookmarkedVideos={bookmarkedVideosMap}
                likedVideos={likedVideosMap}
                commentsMap={commentsMap}
                onLike={handleLike}
                onBookmark={handleBookmark}
                onShare={handleShare}
                onSubscribe={handleSubscribe}
                onOpenComments={handleOpenComments}
                onOpenUpload={() => (user ? setIsUploadOpen(true) : setIsAuthOpen(true))}
                onWatchTick={() => {}}
              />
            </div>
          )}

          {activeTab === 'subscriptions' && (
            <SubscriptionsView
              videos={filteredVideos}
              onSelectVideo={(v) => setTheaterVideo(v)}
              onNavigateTab={(tab) => setActiveTab(tab as MainNavTab)}
            />
          )}

          {activeTab === 'library' && (
            <LibraryView
              savedVideos={savedVideos}
              likedVideos={likedVideosList}
              onSelectVideo={(v) => setTheaterVideo(v)}
              onNavigateTab={(tab) => setActiveTab(tab as MainNavTab)}
            />
          )}

          {activeTab === 'studio' && (
            <StudioView
              user={
                user || {
                  id: 'usr-guest',
                  name: 'Creator Partner',
                  handle: 'creator',
                  email: 'creator@armss.com',
                  role: 'creator',
                  tier: 'Silver',
                  balance: 250,
                  subscribersCount: 142,
                }
              }
              videos={videos}
              wallet={wallet}
              quota={quota}
              activeSubTab={studioSubTab}
              onSubTabChange={(tab) => setStudioSubTab(tab)}
              onOpenUpload={() => setIsUploadOpen(true)}
              onOpenKYC={() => setIsKYCOpen(true)}
              onOpenWithdraw={() => setIsWithdrawOpen(true)}
              onUserUpdate={(updated) => setUser(updated)}
            />
          )}

          {activeTab === 'admin' && user?.role === 'admin' && (
            <AdminView
              videos={videos}
              onModerateSuccess={loadVideos}
              onSelectVideo={(v) => setTheaterVideo(v)}
            />
          )}
        </main>
      </div>

      {/* Mobile Bottom Navigation Bar (Hidden on Desktop) */}
      <MobileNav activeTab={activeTab} setActiveTab={setActiveTab} user={user} />

      {/* Modals & Slide-overs */}
      <AuthModal
        isOpen={isAuthOpen}
        onClose={() => setIsAuthOpen(false)}
        onAuthSuccess={handleAuthSuccess}
        onOpenTerms={() => setLegalModalState({ isOpen: true, tab: 'terms' })}
        onOpenPrivacy={() => setLegalModalState({ isOpen: true, tab: 'privacy' })}
      />

      <UploadModal
        isOpen={isUploadOpen}
        onClose={() => setIsUploadOpen(false)}
        onUploadSuccess={() => {
          showToast('Video published successfully!');
          loadVideos();
          loadWalletAndQuotas();
        }}
      />

      <TheaterModal
        video={theaterVideo}
        isOpen={!!theaterVideo}
        onClose={() => setTheaterVideo(null)}
        onLike={handleLike}
        onShare={handleShare}
        onOpenComments={handleOpenComments}
        isLiked={theaterVideo ? !!likedVideosMap[theaterVideo.id] : false}
        onSubscribe={handleSubscribe}
        isSubscribed={theaterVideo ? !!subscribedCreatorsMap[theaterVideo.creatorHandle || theaterVideo.creator_name || ''] : false}
      />

      <KYCModal
        isOpen={isKYCOpen}
        onClose={() => setIsKYCOpen(false)}
        onOpenTerms={() => setLegalModalState({ isOpen: true, tab: 'terms' })}
        onSuccess={() => {
          showToast('Bank KYC verified! Direct payouts enabled.');
          loadWalletAndQuotas();
        }}
      />

      <WithdrawModal
        isOpen={isWithdrawOpen}
        availableBalance={(wallet?.availableBalance || 0) + (wallet?.welcomeCredit || 250)}
        onClose={() => setIsWithdrawOpen(false)}
        onSuccess={() => {
          showToast('Payout transfer initiated!');
          loadWalletAndQuotas();
        }}
      />

      <SupportChatModal
        isOpen={isSupportOpen}
        onClose={() => setIsSupportOpen(false)}
        userName={user?.name || user?.email || 'Creator'}
      />

      <CommentsDrawer
        isOpen={!!activeCommentVideoId}
        onClose={() => setActiveCommentVideoId(null)}
        comments={activeCommentVideoId ? commentsMap[activeCommentVideoId] || [] : []}
        newCommentText={newCommentText}
        setNewCommentText={setNewCommentText}
        onPostComment={handlePostComment}
      />

      <AuthRequiredModal
        isOpen={authGateState.isOpen}
        action={authGateState.action}
        details={authGateState.details}
        onClose={() => setAuthGateState((prev) => ({ ...prev, isOpen: false }))}
        onLogin={() => setIsAuthOpen(true)}
      />

      <LegalModal
        isOpen={legalModalState.isOpen}
        onClose={() => setLegalModalState((prev) => ({ ...prev, isOpen: false }))}
        initialTab={legalModalState.tab}
      />
    </div>
  );
}

export default App;
