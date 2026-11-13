import React, { useState } from 'react';
import { X, ShieldCheck, FileText, CheckCircle2, Lock, Scale, AlertCircle } from 'lucide-react';

interface LegalModalProps {
  isOpen: boolean;
  onClose: () => void;
  initialTab?: 'terms' | 'privacy';
}

export const LegalModal: React.FC<LegalModalProps> = ({
  isOpen,
  onClose,
  initialTab = 'terms',
}) => {
  const [activeTab, setActiveTab] = useState<'terms' | 'privacy'>(initialTab);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
      <div className="relative w-full max-w-3xl max-h-[90vh] bg-[#FFFFFF] border border-[#DCE7F6] rounded-3xl shadow-2xl flex flex-col overflow-hidden animate-scale-up">
        {/* Header */}
        <div className="px-6 py-5 border-b border-[#DCE7F6] flex items-center justify-between bg-[#F8FAFC]">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-[#E0EDFF] border border-[#BFDBFE] flex items-center justify-center text-[#2563EB]">
              {activeTab === 'terms' ? <Scale size={20} /> : <Lock size={20} />}
            </div>
            <div>
              <h2 className="text-base sm:text-lg font-bold text-[#0F172A] tracking-tight">
                {activeTab === 'terms' ? 'Terms & Conditions' : 'Privacy Policy'}
              </h2>
              <p className="text-xs text-[#64748B]">
                Aura Entertainment Creator Monetization Platform • Last updated November 2026
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-2 text-[#64748B] hover:text-[#0F172A] hover:bg-[#E2E8F0] rounded-full transition-colors cursor-pointer"
            aria-label="Close"
          >
            <X size={18} />
          </button>
        </div>

        {/* Tab Switcher */}
        <div className="px-6 pt-3 pb-0 border-b border-[#DCE7F6] flex gap-2 bg-[#FFFFFF]">
          <button
            onClick={() => setActiveTab('terms')}
            className={`flex items-center gap-2 px-4 py-2.5 text-xs font-semibold rounded-t-xl border-b-2 transition-all cursor-pointer ${
              activeTab === 'terms'
                ? 'border-[#2563EB] text-[#2563EB] bg-[#F0F6FF]'
                : 'border-transparent text-[#64748B] hover:text-[#0F172A]'
            }`}
          >
            <FileText size={15} />
            <span>Terms of Service & Creator Agreement</span>
          </button>

          <button
            onClick={() => setActiveTab('privacy')}
            className={`flex items-center gap-2 px-4 py-2.5 text-xs font-semibold rounded-t-xl border-b-2 transition-all cursor-pointer ${
              activeTab === 'privacy'
                ? 'border-[#2563EB] text-[#2563EB] bg-[#F0F6FF]'
                : 'border-transparent text-[#64748B] hover:text-[#0F172A]'
            }`}
          >
            <ShieldCheck size={15} />
            <span>Privacy Policy</span>
          </button>
        </div>

        {/* Content Body */}
        <div className="flex-1 overflow-y-auto px-6 py-6 text-xs text-[#334155] leading-relaxed space-y-6">
          {activeTab === 'terms' ? (
            <div className="space-y-6">
              <div className="p-4 rounded-2xl bg-[#EFF6FF] border border-[#BFDBFE] flex items-start gap-3">
                <AlertCircle size={18} className="text-[#2563EB] shrink-0 mt-0.5" />
                <p className="text-[#1E40AF]">
                  Welcome to Aura Entertainment. By registering an account, watching videos, or uploading content as a Creator, you legally agree to these terms, our Monetization Rules, and Anti-AI Policies.
                </p>
              </div>

              <section className="space-y-2">
                <h3 className="text-sm font-bold text-[#0F172A]">1. Eligibility & Human-Authored Content Policy</h3>
                <p>
                  Aura is dedicated exclusively to human creators. All uploaded videos, whether landscape (16:9) or vertical shorts (9:16), must be 100% human-recorded, edited, and authored.
                </p>
                <ul className="list-disc pl-5 space-y-1 text-[#475569]">
                  <li>Synthetic AI-generated video, automated voice cloning, and mass scrapers are strictly prohibited.</li>
                  <li>Violations result in instant video rejection, forfeiture of pending royalties, and permanent account suspension.</li>
                </ul>
              </section>

              <section className="space-y-2">
                <h3 className="text-sm font-bold text-[#0F172A]">2. Creator Monetization & Duration Quotas</h3>
                <p>
                  Creators earn payouts according to the platform's active monetization model (duration-weighted rate, fixed per-video rate, or tier milestone grants).
                </p>
                <ul className="list-disc pl-5 space-y-1 text-[#475569]">
                  <li>Duration bucket quotas (e.g. 30m, 20m, 10m, 5m, 2m) track qualified videos meeting length and quality criteria.</li>
                  <li>Milestone rewards (Silver ₹2,500, Gold ₹10,000, Diamond ₹25,000) are disbursed upon completion of designated video targets and admin audit verification.</li>
                  <li>Views generated through bots, click farms, or artificial manipulation will be purged and can disqualify the creator.</li>
                </ul>
              </section>

              <section className="space-y-2">
                <h3 className="text-sm font-bold text-[#0F172A]">3. Bank KYC & Payout Transfers</h3>
                <p>
                  To request withdrawals from your platform wallet to your domestic bank account, creators must successfully submit Aadhaar and PAN verification.
                </p>
                <ul className="list-disc pl-5 space-y-1 text-[#475569]">
                  <li>Bank account holder name must match the identity documentation provided in KYC.</li>
                  <li>Payments are processed via authorized settlement gateways (Cashfree / NEFT / IMPS). Processing times typically range from 24 to 48 business hours.</li>
                </ul>
              </section>

              <section className="space-y-2">
                <h3 className="text-sm font-bold text-[#0F172A]">4. Copyright & Intellectual Property</h3>
                <p>
                  You retain ownership of the original content you produce. By uploading to Aura, you grant the platform a non-exclusive, worldwide license to stream, transcode into adaptive CMAF HLS bitrate tracks, and display your video to audience members.
                </p>
              </section>

              <section className="space-y-2">
                <h3 className="text-sm font-bold text-[#0F172A]">5. Community Conduct & Content Moderation</h3>
                <p>
                  Comments, video titles, thumbnails, and support interactions must remain respectful. Content containing harassment, hate speech, illegal activities, or explicit material will be removed immediately.
                </p>
              </section>
            </div>
          ) : (
            <div className="space-y-6">
              <div className="p-4 rounded-2xl bg-[#ECFDF5] border border-[#A7F3D0] flex items-start gap-3">
                <CheckCircle2 size={18} className="text-[#059669] shrink-0 mt-0.5" />
                <p className="text-[#065F46]">
                  Your privacy is paramount. Aura Entertainment protects your personal data, KYC documents, and earnings records using enterprise-grade encryption.
                </p>
              </div>

              <section className="space-y-2">
                <h3 className="text-sm font-bold text-[#0F172A]">1. Information We Collect</h3>
                <p>We collect information necessary to provide video streaming, authenticate users, and disburse creator royalties:</p>
                <ul className="list-disc pl-5 space-y-1 text-[#475569]">
                  <li><strong>Account Data:</strong> Name, email address, password hash, channel name, bio, and profile avatar.</li>
                  <li><strong>Google Authentication:</strong> When signing in with Google OAuth, we receive verified name, email, and Google ID token.</li>
                  <li><strong>KYC & Payout Details:</strong> 12-digit Aadhaar number, PAN card number, bank account number, and IFSC code (collected exclusively for statutory tax compliance and payout disbursement).</li>
                  <li><strong>Usage & Telemetry:</strong> Video playback watch duration, comments, likes, shares, and browser/device metadata to protect against fraud.</li>
                </ul>
              </section>

              <section className="space-y-2">
                <h3 className="text-sm font-bold text-[#0F172A]">2. How We Use Your Data</h3>
                <ul className="list-disc pl-5 space-y-1 text-[#475569]">
                  <li>Operating the video playback engine (HLS fMP4 delivery, playlist selection).</li>
                  <li>Calculating watch minutes, monetization milestones, and creator wallet earnings.</li>
                  <li>Conducting KYC checks and facilitating direct bank transfers.</li>
                  <li>Ensuring community safety, moderating flagged videos, and preventing automated bot fraud.</li>
                </ul>
              </section>

              <section className="space-y-2">
                <h3 className="text-sm font-bold text-[#0F172A]">3. Data Security & Encryption</h3>
                <p>
                  All sensitive data in transit is encrypted via HTTPS/TLS. Passwords are cryptographically salted and hashed with bcrypt. Financial KYC documents are accessible only to authorized administrators for verification purposes.
                </p>
              </section>

              <section className="space-y-2">
                <h3 className="text-sm font-bold text-[#0F172A]">4. Third-Party Sharing</h3>
                <p>
                  We never sell your personal data to advertisers. We share information solely with verified service providers necessary for platform operations (e.g., payment gateways for creator withdrawals).
                </p>
              </section>

              <section className="space-y-2">
                <h3 className="text-sm font-bold text-[#0F172A]">5. Your Rights & Data Deletion</h3>
                <p>
                  You have the right to inspect, update, or request the deletion of your account and associated personal data by contacting our Support Desk or emailing support@aura.com.
                </p>
              </section>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-[#DCE7F6] bg-[#F8FAFC] flex items-center justify-between">
          <span className="text-[11px] text-[#64748B]">
            Questions? Contact <a href="mailto:legal@aura.com" className="text-[#2563EB] underline">legal@aura.com</a>
          </span>
          <button
            onClick={onClose}
            className="px-5 py-2 text-xs font-semibold rounded-full bg-[#2563EB] hover:bg-[#1D4ED8] text-white shadow-sm transition-all active:scale-95 cursor-pointer"
          >
            I Understand
          </button>
        </div>
      </div>
    </div>
  );
};

