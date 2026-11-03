import React, { useState, useEffect, useRef } from 'react';
import {
  X,
  Mail,
  Lock,
  User,
  ArrowRight,
  ShieldCheck,
  Sparkles,
  RefreshCw,
  CheckCircle2,
  ChevronLeft,
  Eye,
  EyeOff,
  Flame,
  AlertCircle,
} from 'lucide-react';
import { authService } from '../../services/authService';
import type { User as UserType } from '../../types';

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
  onAuthSuccess: (token: string, user: UserType) => void;
}

type AuthView = 'welcome' | 'email_otp' | 'register' | 'register_otp' | 'password_login';

export const AuthModal: React.FC<AuthModalProps> = ({
  isOpen,
  onClose,
  onAuthSuccess,
}) => {
  const [view, setView] = useState<AuthView>('welcome');

  // Input States
  const [email, setEmail] = useState('');
  const [name, setName] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  // Password Login Input States
  const [loginIdentifier, setLoginIdentifier] = useState('');
  const [loginPassword, setLoginPassword] = useState('');
  const [showLoginPassword, setShowLoginPassword] = useState(false);

  // OTP States
  const [otpDigits, setOtpDigits] = useState<string[]>(['', '', '', '', '', '']);
  const [demoOTP, setDemoOTP] = useState<string | null>(null);
  const [timer, setTimer] = useState<number>(0);

  // UI States
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const digitInputRefs = useRef<(HTMLInputElement | null)[]>([]);

  // OTP Timer countdown
  useEffect(() => {
    if (timer > 0) {
      const interval = setInterval(() => setTimer((t) => t - 1), 1000);
      return () => clearInterval(interval);
    }
  }, [timer]);

  if (!isOpen) return null;

  const resetAll = () => {
    setView('welcome');
    setEmail('');
    setName('');
    setPassword('');
    setConfirmPassword('');
    setLoginIdentifier('');
    setLoginPassword('');
    setOtpDigits(['', '', '', '', '', '']);
    setDemoOTP(null);
    setErrorMessage(null);
    setLoading(false);
  };

  const handleClose = () => {
    resetAll();
    onClose();
  };

  // Google OAuth Handler
  const handleGoogleLogin = async () => {
    try {
      setLoading(true);
      setErrorMessage(null);
      const res = await authService.loginWithGoogle();
      onAuthSuccess(res.token, res.user);
      handleClose();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Google authentication failed.';
      setErrorMessage(msg);
    } finally {
      setLoading(false);
    }
  };

  // Continue with Email (Dispatches OTP)
  const handleContinueWithEmail = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanEmail = email.trim().toLowerCase();
    if (!cleanEmail || !cleanEmail.includes('@') || !cleanEmail.includes('.')) {
      setErrorMessage('Please enter a valid email address.');
      return;
    }

    try {
      setLoading(true);
      setErrorMessage(null);
      const res = await authService.sendOTP(cleanEmail);
      if (cleanEmail === 'admin@armss.com' && res.demo_otp) {
        setDemoOTP(res.demo_otp);
      } else {
        setDemoOTP(null);
      }
      setTimer(60);
      setOtpDigits(['', '', '', '', '', '']);
      setView('email_otp');
      setTimeout(() => {
        digitInputRefs.current[0]?.focus();
      }, 150);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to send verification code.';
      setErrorMessage(msg);
    } finally {
      setLoading(false);
    }
  };

  // Register Form Submit (Validates & Dispatches OTP)
  const handleRegisterSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);

    const cleanName = name.trim();
    const cleanEmail = email.trim().toLowerCase();

    if (cleanName.length < 2) {
      setErrorMessage('Full name must be at least 2 characters.');
      return;
    }
    if (!cleanEmail || !cleanEmail.includes('@') || !cleanEmail.includes('.')) {
      setErrorMessage('Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setErrorMessage('Password must be at least 6 characters.');
      return;
    }
    if (password !== confirmPassword) {
      setErrorMessage('Passwords do not match. Please re-enter.');
      return;
    }

    try {
      setLoading(true);
      const res = await authService.sendOTP(cleanEmail);
      if (cleanEmail === 'admin@armss.com' && res.demo_otp) {
        setDemoOTP(res.demo_otp);
      } else {
        setDemoOTP(null);
      }
      setTimer(60);
      setOtpDigits(['', '', '', '', '', '']);
      setView('register_otp');
      setTimeout(() => {
        digitInputRefs.current[0]?.focus();
      }, 150);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to send verification code.';
      setErrorMessage(msg);
    } finally {
      setLoading(false);
    }
  };

  // Password Login Submit
  const handlePasswordLoginSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanId = loginIdentifier.trim();
    if (!cleanId) {
      setErrorMessage('Please enter your email or username.');
      return;
    }
    if (!loginPassword) {
      setErrorMessage('Please enter your password.');
      return;
    }

    try {
      setLoading(true);
      setErrorMessage(null);
      const res = await authService.loginWithPassword(cleanId, loginPassword);
      onAuthSuccess(res.token, res.user);
      handleClose();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Invalid credentials. Please verify your email & password.';
      setErrorMessage(msg);
    } finally {
      setLoading(false);
    }
  };

  // OTP Digit change
  const handleDigitChange = (index: number, val: string) => {
    const clean = val.replace(/\D/g, '').slice(-1);
    const updated = [...otpDigits];
    updated[index] = clean;
    setOtpDigits(updated);
    setErrorMessage(null);

    if (clean && index < 5) {
      digitInputRefs.current[index + 1]?.focus();
    }

    const fullCode = updated.join('');
    if (fullCode.length === 6 && clean) {
      if (view === 'email_otp') {
        handleVerifyEmailOTP(fullCode);
      } else if (view === 'register_otp') {
        handleVerifyAndRegister(fullCode);
      }
    }
  };

  const handleDigitKeyDown = (index: number, e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Backspace' && !otpDigits[index] && index > 0) {
      digitInputRefs.current[index - 1]?.focus();
    }
  };

  const handlePasteDigits = (e: React.ClipboardEvent<HTMLInputElement>) => {
    e.preventDefault();
    const pasted = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
    if (!pasted) return;
    const updated = ['', '', '', '', '', ''];
    for (let i = 0; i < pasted.length; i++) {
      updated[i] = pasted[i];
    }
    setOtpDigits(updated);
    if (pasted.length === 6) {
      if (view === 'email_otp') {
        handleVerifyEmailOTP(pasted);
      } else if (view === 'register_otp') {
        handleVerifyAndRegister(pasted);
      }
    }
  };

  // Verify Email OTP (for standard email flow)
  const handleVerifyEmailOTP = async (codeToSubmit?: string) => {
    const code = codeToSubmit || otpDigits.join('');
    if (code.length < 6) {
      setErrorMessage('Please enter the complete 6-digit verification code.');
      return;
    }

    try {
      setLoading(true);
      setErrorMessage(null);
      const res = await authService.verifyOTP(email.trim().toLowerCase(), code);

      if (res.is_new_user) {
        // Automatically create account with email prefix
        const autoName = email.split('@')[0] || 'Creator';
        const regRes = await authService.registerWithOTP(autoName, email, `ARMSS_${Date.now()}`);
        onAuthSuccess(regRes.token, regRes.user);
        handleClose();
      } else if (res.token && res.user) {
        onAuthSuccess(res.token, res.user);
        handleClose();
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Invalid or expired code. Please try again.';
      setErrorMessage(msg);
    } finally {
      setLoading(false);
    }
  };

  // Verify and Register (for registration flow)
  const handleVerifyAndRegister = async (codeToSubmit?: string) => {
    const code = codeToSubmit || otpDigits.join('');
    if (code.length < 6) {
      setErrorMessage('Please enter the complete 6-digit verification code.');
      return;
    }

    try {
      setLoading(true);
      setErrorMessage(null);
      // 1. Verify OTP
      await authService.verifyOTP(email.trim().toLowerCase(), code);
      // 2. Register with Name, Email & Password
      const regRes = await authService.registerWithOTP(name.trim(), email.trim().toLowerCase(), password);
      onAuthSuccess(regRes.token, regRes.user);
      handleClose();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Registration failed. Please check code or try again.';
      setErrorMessage(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-md animate-fade-in">
      <div
        className="relative w-full max-w-md rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-[0_25px_60px_rgba(220,231,246,0.95)] overflow-hidden transition-all duration-300"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Top Header Bar */}
        <div className="flex items-center justify-between p-5 pb-3 border-b border-[#DCE7F6]">
          {view !== 'welcome' ? (
            <button
              onClick={() => {
                setErrorMessage(null);
                if (view === 'register_otp') setView('register');
                else setView('welcome');
              }}
              className="flex items-center gap-1.5 text-xs text-[#64748B] hover:text-[#0F172A] transition-colors cursor-pointer"
            >
              <ChevronLeft size={16} />
              <span>Back</span>
            </button>
          ) : (
            <div className="flex items-center gap-2">
              <div className="w-6 h-6 rounded-lg bg-[#2563EB] flex items-center justify-center text-white shadow-sm">
                <Flame size={14} className="fill-white" />
              </div>
              <span className="text-xs font-bold tracking-tight text-[#0F172A] uppercase font-mono">
                ARMSS ENTERTAINMENT
              </span>
            </div>
          )}

          <button
            onClick={handleClose}
            className="p-1.5 rounded-full text-[#64748B] hover:text-[#0F172A] hover:bg-[#F0F6FF] transition-colors cursor-pointer"
            aria-label="Close"
          >
            <X size={18} />
          </button>
        </div>

        {/* Modal Body Container */}
        <div className="p-6 sm:p-7 space-y-6">
          {/* Error Banner */}
          {errorMessage && (
            <div className="p-3 rounded-xl bg-red-50 border border-red-200 flex items-start gap-2.5 text-xs text-red-700 animate-shake">
              <AlertCircle size={15} className="shrink-0 mt-0.5" />
              <div className="flex-1 leading-snug">{errorMessage}</div>
            </div>
          )}

          {/* ═══════════════════════════════════════════════════════════
              VIEW 1: WELCOME & PRIMARY OPTIONS
             ═══════════════════════════════════════════════════════════ */}
          {view === 'welcome' && (
            <div className="space-y-6">
              <div className="space-y-1.5 text-center">
                <h2 className="text-2xl font-extrabold tracking-tight text-[#0F172A]">
                  Welcome to ARMSS
                </h2>
                <p className="text-xs text-[#64748B] leading-relaxed max-w-xs mx-auto">
                  Sign in to explore exclusive channels or publish verified videos as a creator partner.
                </p>
              </div>

              {/* Google OAuth Option */}
              <div className="space-y-3">
                <button
                  type="button"
                  onClick={handleGoogleLogin}
                  disabled={loading}
                  className="w-full flex items-center justify-center gap-3 py-3 px-4 rounded-2xl bg-[#FFFFFF] hover:bg-[#F8FAFC] text-[#0F172A] border border-[#DCE7F6] text-xs font-bold tracking-tight transition-all active:scale-[0.98] shadow-sm cursor-pointer disabled:opacity-60"
                >
                  {/* Official Google 4-Color Icon */}
                  <svg className="w-4 h-4 shrink-0" viewBox="0 0 24 24">
                    <path
                      fill="#4285F4"
                      d="M23.745 12.27c0-.7-.06-1.4-.19-2.07H12v4.51h6.6c-.29 1.52-1.14 2.8-2.4 3.65v3h3.88c2.27-2.09 3.665-5.17 3.665-9.09z"
                    />
                    <path
                      fill="#34A853"
                      d="M12 24c3.24 0 5.95-1.08 7.93-2.91l-3.88-3c-1.08.72-2.45 1.16-4.05 1.16-3.12 0-5.77-2.1-6.72-4.93H1.25v3.1C3.27 21.43 7.37 24 12 24z"
                    />
                    <path
                      fill="#FBBC05"
                      d="M5.28 14.32c-.25-.72-.38-1.49-.38-2.32 0-.83.13-1.6.38-2.32V6.58H1.25C.45 8.17 0 9.99 0 12s.45 3.83 1.25 5.42l4.03-3.1z"
                    />
                    <path
                      fill="#EA4335"
                      d="M12 4.75c1.77 0 3.35.61 4.6 1.8l3.42-3.42C17.95 1.19 15.24 0 12 0 7.37 0 3.27 2.57 1.25 6.58l4.03 3.1c.95-2.83 3.6-4.93 6.72-4.93z"
                    />
                  </svg>
                  <span>Continue with Google</span>
                </button>

                {/* Divider */}
                <div className="relative py-3 my-1 flex items-center justify-center">
                  <div className="absolute inset-x-0 h-px bg-[#DCE7F6]" />
                  <span className="relative px-3 bg-[#FFFFFF] text-[10px] font-mono uppercase tracking-widest text-[#64748B]">
                    or continue with email
                  </span>
                </div>

                {/* Continue with Email Input Form */}
                <form onSubmit={handleContinueWithEmail} className="space-y-3">
                  <div className="relative">
                    <Mail size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#64748B] pointer-events-none" />
                    <input
                      type="email"
                      required
                      placeholder="name@example.com"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      style={{ paddingLeft: '2.75rem' }}
                      className="w-full pr-4 py-2.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs text-[#0F172A] placeholder-[#94A3B8] focus:outline-none focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] focus:bg-[#FFFFFF] transition-all"
                    />
                  </div>

                  <button
                    type="submit"
                    disabled={loading}
                    className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl bg-[#2563EB] hover:bg-[#1D4ED8] text-white text-xs font-bold tracking-tight transition-all active:scale-[0.98] shadow-md cursor-pointer disabled:opacity-60"
                  >
                    {loading ? (
                      <RefreshCw size={14} className="animate-spin" />
                    ) : (
                      <>
                        <span>Continue with Email</span>
                        <ArrowRight size={14} />
                      </>
                    )}
                  </button>
                </form>
              </div>

              {/* Bottom Alternatives */}
              <div className="pt-2 border-t border-[#DCE7F6] space-y-2 text-center">
                <button
                  type="button"
                  onClick={() => {
                    setErrorMessage(null);
                    setView('register');
                  }}
                  className="w-full py-2.5 rounded-xl bg-[#F8FAFC] hover:bg-[#F0F6FF] text-[#0F172A] border border-[#DCE7F6] text-xs font-semibold tracking-tight transition-all cursor-pointer"
                >
                  Create an account with password
                </button>

                <div className="text-[11px] text-[#64748B]">
                  Already have a password?{' '}
                  <button
                    type="button"
                    onClick={() => {
                      setErrorMessage(null);
                      setView('password_login');
                    }}
                    className="text-[#2563EB] font-semibold underline hover:text-[#1D4ED8] cursor-pointer ml-1"
                  >
                    Sign in here
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* ═══════════════════════════════════════════════════════════
              VIEW 2: EMAIL OTP VERIFICATION STEP
             ═══════════════════════════════════════════════════════════ */}
          {view === 'email_otp' && (
            <div className="space-y-6">
              <div className="flex flex-col items-center justify-center space-y-2 text-center">
                <div className="w-12 h-12 rounded-2xl bg-[#E0EDFF] border border-[#BFDBFE] flex items-center justify-center text-[#1D4ED8] shadow-sm">
                  <Mail size={22} />
                </div>
                <h2 className="text-xl font-bold tracking-tight text-[#0F172A]">
                  Check your email
                </h2>
                <p className="text-xs text-[#64748B] max-w-xs mx-auto font-normal">
                  We sent a 6-digit verification code to <span className="text-[#0F172A] font-mono font-semibold">{email}</span>.
                </p>
              </div>

              {/* Admin Quick Access OTP Helper (Only visible for admin@armss.com) */}
              {email.trim().toLowerCase() === 'admin@armss.com' && demoOTP && (
                <div
                  onClick={() => {
                    const digits = demoOTP.split('').slice(0, 6);
                    setOtpDigits(digits);
                    handleVerifyEmailOTP(demoOTP);
                  }}
                  className="p-2.5 rounded-xl bg-[#E0EDFF] border border-[#BFDBFE] text-[11px] text-[#1D4ED8] font-mono flex items-center justify-between cursor-pointer hover:bg-[#BFDBFE]/30 transition-colors"
                >
                  <div className="flex items-center gap-1.5">
                    <Sparkles size={13} />
                    <span>Admin Quick Access OTP: <strong>{demoOTP}</strong></span>
                  </div>
                  <span className="text-[10px] underline font-sans">Tap to autofill</span>
                </div>
              )}

              {/* 6 Digit Input Boxes */}
              <div className="flex items-center justify-center gap-2">
                {otpDigits.map((digit, idx) => (
                  <input
                    key={idx}
                    ref={(el) => {
                      digitInputRefs.current[idx] = el;
                    }}
                    type="text"
                    inputMode="numeric"
                    maxLength={1}
                    value={digit}
                    onChange={(e) => handleDigitChange(idx, e.target.value)}
                    onKeyDown={(e) => handleDigitKeyDown(idx, e)}
                    onPaste={handlePasteDigits}
                    className="w-11 h-13 text-center text-lg font-mono font-bold text-[#0F172A] bg-[#F8FAFC] border border-[#DCE7F6] rounded-xl focus:outline-none focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] focus:bg-[#FFFFFF] transition-all"
                  />
                ))}
              </div>

              {/* Verify Action Button */}
              <button
                type="button"
                onClick={() => handleVerifyEmailOTP()}
                disabled={loading || otpDigits.join('').length < 6}
                className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl bg-[#2563EB] hover:bg-[#1D4ED8] disabled:bg-[#F8FAFC] text-white disabled:text-[#94A3B8] disabled:cursor-not-allowed text-xs font-bold tracking-tight transition-all active:scale-[0.98] cursor-pointer shadow-sm"
              >
                {loading ? (
                  <RefreshCw size={14} className="animate-spin" />
                ) : (
                  <>
                    <CheckCircle2 size={14} />
                    <span>Verify Code & Sign In</span>
                  </>
                )}
              </button>

              {/* Resend Timer */}
              <div className="text-center text-xs text-[#64748B]">
                {timer > 0 ? (
                  <span className="font-mono text-[#64748B]">Resend code in {timer}s</span>
                ) : (
                  <button
                    type="button"
                    onClick={() => handleContinueWithEmail({ preventDefault: () => {} } as React.FormEvent)}
                    className="text-[#2563EB] hover:underline font-medium cursor-pointer"
                  >
                    Resend verification code
                  </button>
                )}
              </div>
            </div>
          )}

          {/* ═══════════════════════════════════════════════════════════
              VIEW 3: CREATE ACCOUNT (NAME, EMAIL, PASSWORD, CONFIRM)
             ═══════════════════════════════════════════════════════════ */}
          {view === 'register' && (
            <div className="space-y-5">
              <div className="space-y-1">
                <h2 className="text-xl font-extrabold tracking-tight text-[#0F172A]">
                  Create Creator Account
                </h2>
                <p className="text-xs text-[#64748B]">
                  Register your channel to start publishing and monetizing.
                </p>
              </div>

              <form onSubmit={handleRegisterSubmit} className="space-y-3.5">
                {/* Full Name */}
                <div className="space-y-1">
                  <label className="text-[11px] font-semibold text-[#0F172A] font-mono uppercase tracking-wider">
                    Full Name / Channel
                  </label>
                  <div className="relative">
                    <User size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#64748B] pointer-events-none" />
                    <input
                      type="text"
                      required
                      placeholder="e.g. Alex Rivera"
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      style={{ paddingLeft: '2.75rem' }}
                      className="w-full pr-4 py-2.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs text-[#0F172A] placeholder-[#94A3B8] focus:outline-none focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] focus:bg-[#FFFFFF] transition-all"
                    />
                  </div>
                </div>

                {/* Email Address */}
                <div className="space-y-1">
                  <label className="text-[11px] font-semibold text-[#0F172A] font-mono uppercase tracking-wider">
                    Email Address
                  </label>
                  <div className="relative">
                    <Mail size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#64748B] pointer-events-none" />
                    <input
                      type="email"
                      required
                      placeholder="alex@domain.com"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      style={{ paddingLeft: '2.75rem' }}
                      className="w-full pr-4 py-2.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs text-[#0F172A] placeholder-[#94A3B8] focus:outline-none focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] focus:bg-[#FFFFFF] transition-all"
                    />
                  </div>
                </div>

                {/* Password */}
                <div className="space-y-1">
                  <label className="text-[11px] font-semibold text-[#0F172A] font-mono uppercase tracking-wider">
                    Password (min 6 characters)
                  </label>
                  <div className="relative">
                    <Lock size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#64748B] pointer-events-none" />
                    <input
                      type={showPassword ? 'text' : 'password'}
                      required
                      placeholder="••••••••"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      style={{ paddingLeft: '2.75rem', paddingRight: '2.5rem' }}
                      className="w-full py-2.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs text-[#0F172A] placeholder-[#94A3B8] focus:outline-none focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] focus:bg-[#FFFFFF] transition-all"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword((p) => !p)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-[#64748B] hover:text-[#0F172A] cursor-pointer"
                    >
                      {showPassword ? <EyeOff size={15} /> : <Eye size={15} />}
                    </button>
                  </div>
                </div>

                {/* Confirm Password */}
                <div className="space-y-1">
                  <label className="text-[11px] font-semibold text-[#0F172A] font-mono uppercase tracking-wider">
                    Confirm Password
                  </label>
                  <div className="relative">
                    <Lock size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#64748B] pointer-events-none" />
                    <input
                      type={showConfirmPassword ? 'text' : 'password'}
                      required
                      placeholder="••••••••"
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                      style={{ paddingLeft: '2.75rem', paddingRight: '2.5rem' }}
                      className="w-full py-2.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs text-[#0F172A] placeholder-[#94A3B8] focus:outline-none focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] focus:bg-[#FFFFFF] transition-all"
                    />
                    <button
                      type="button"
                      onClick={() => setShowConfirmPassword((p) => !p)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-[#64748B] hover:text-[#0F172A] cursor-pointer"
                    >
                      {showConfirmPassword ? <EyeOff size={15} /> : <Eye size={15} />}
                    </button>
                  </div>
                  {confirmPassword && password !== confirmPassword && (
                    <p className="text-[10px] text-red-600 font-mono pt-0.5">Passwords do not match</p>
                  )}
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full mt-2 flex items-center justify-center gap-2 py-3 rounded-xl bg-[#2563EB] hover:bg-[#1D4ED8] text-white text-xs font-bold tracking-tight transition-all active:scale-[0.98] shadow-md cursor-pointer disabled:opacity-60"
                >
                  {loading ? (
                    <RefreshCw size={14} className="animate-spin" />
                  ) : (
                    <>
                      <span>Continue to Verification</span>
                      <ArrowRight size={14} />
                    </>
                  )}
                </button>
              </form>

              <div className="text-center text-xs text-[#64748B] pt-1">
                Already registered?{' '}
                <button
                  type="button"
                  onClick={() => {
                    setErrorMessage(null);
                    setView('password_login');
                  }}
                  className="text-[#2563EB] font-semibold underline hover:text-[#1D4ED8] cursor-pointer"
                >
                  Sign in with password
                </button>
              </div>
            </div>
          )}

          {/* ═══════════════════════════════════════════════════════════
              VIEW 4: REGISTER EMAIL OTP VERIFICATION
             ═══════════════════════════════════════════════════════════ */}
          {view === 'register_otp' && (
            <div className="space-y-6">
              <div className="space-y-1.5 text-center">
                <div className="w-12 h-12 rounded-2xl bg-[#E0EDFF] border border-[#BFDBFE] mx-auto flex items-center justify-center text-[#1D4ED8]">
                  <ShieldCheck size={24} />
                </div>
                <h2 className="text-xl font-bold tracking-tight text-[#0F172A]">
                  Verify your email
                </h2>
                <p className="text-xs text-[#64748B] max-w-xs mx-auto font-normal">
                  Enter the 6-digit code sent to <strong className="text-[#0F172A]">{email}</strong> to activate your channel.
                </p>
              </div>

              {/* Admin Quick Access OTP Helper (Only visible for admin@armss.com) */}
              {email.trim().toLowerCase() === 'admin@armss.com' && demoOTP && (
                <div
                  onClick={() => {
                    const digits = demoOTP.split('').slice(0, 6);
                    setOtpDigits(digits);
                    handleVerifyAndRegister(demoOTP);
                  }}
                  className="p-2.5 rounded-xl bg-[#E0EDFF] border border-[#BFDBFE] text-[11px] text-[#1D4ED8] font-mono flex items-center justify-between cursor-pointer hover:bg-[#BFDBFE]/30 transition-colors"
                >
                  <div className="flex items-center gap-1.5">
                    <Sparkles size={13} />
                    <span>Admin Quick Access OTP: <strong>{demoOTP}</strong></span>
                  </div>
                  <span className="text-[10px] underline font-sans">Tap to autofill</span>
                </div>
              )}

              <div className="flex items-center justify-center gap-2">
                {otpDigits.map((digit, idx) => (
                  <input
                    key={idx}
                    ref={(el) => {
                      digitInputRefs.current[idx] = el;
                    }}
                    type="text"
                    inputMode="numeric"
                    maxLength={1}
                    value={digit}
                    onChange={(e) => handleDigitChange(idx, e.target.value)}
                    onKeyDown={(e) => handleDigitKeyDown(idx, e)}
                    onPaste={handlePasteDigits}
                    className="w-11 h-13 text-center text-lg font-mono font-bold text-[#0F172A] bg-[#F8FAFC] border border-[#DCE7F6] rounded-xl focus:outline-none focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] focus:bg-[#FFFFFF] transition-all"
                  />
                ))}
              </div>

              <button
                type="button"
                onClick={() => handleVerifyAndRegister()}
                disabled={loading || otpDigits.join('').length < 6}
                className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl bg-[#2563EB] hover:bg-[#1D4ED8] text-white text-xs font-bold tracking-tight transition-all active:scale-[0.98] cursor-pointer disabled:opacity-40 shadow-sm"
              >
                {loading ? (
                  <RefreshCw size={14} className="animate-spin" />
                ) : (
                  <>
                    <CheckCircle2 size={14} />
                    <span>Complete Account Registration</span>
                  </>
                )}
              </button>

              <div className="text-center text-xs text-[#64748B]">
                {timer > 0 ? (
                  <span className="font-mono text-[#64748B]">Resend code in {timer}s</span>
                ) : (
                  <button
                    type="button"
                    onClick={() => handleRegisterSubmit({ preventDefault: () => {} } as React.FormEvent)}
                    className="text-[#2563EB] hover:underline font-medium cursor-pointer"
                  >
                    Resend verification code
                  </button>
                )}
              </div>
            </div>
          )}

          {/* ═══════════════════════════════════════════════════════════
              VIEW 5: SIGN IN WITH PASSWORD
             ═══════════════════════════════════════════════════════════ */}
          {view === 'password_login' && (
            <div className="space-y-5">
              <div className="space-y-1">
                <h2 className="text-xl font-extrabold tracking-tight text-[#0F172A]">
                  Sign in with password
                </h2>
                <p className="text-xs text-[#64748B]">
                  Enter your registered channel email or username.
                </p>
              </div>

              <form onSubmit={handlePasswordLoginSubmit} className="space-y-3.5">
                <div className="space-y-1">
                  <label className="text-[11px] font-semibold text-[#0F172A] font-mono uppercase tracking-wider">
                    Email or Username
                  </label>
                  <div className="relative">
                    <User size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#64748B] pointer-events-none" />
                    <input
                      type="text"
                      required
                      placeholder="alex@domain.com"
                      value={loginIdentifier}
                      onChange={(e) => setLoginIdentifier(e.target.value)}
                      style={{ paddingLeft: '2.75rem' }}
                      className="w-full pr-4 py-2.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs text-[#0F172A] placeholder-[#94A3B8] focus:outline-none focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] focus:bg-[#FFFFFF] transition-all"
                    />
                  </div>
                </div>

                <div className="space-y-1">
                  <label className="text-[11px] font-semibold text-[#0F172A] font-mono uppercase tracking-wider">
                    Password
                  </label>
                  <div className="relative">
                    <Lock size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#64748B] pointer-events-none" />
                    <input
                      type={showLoginPassword ? 'text' : 'password'}
                      required
                      placeholder="••••••••"
                      value={loginPassword}
                      onChange={(e) => setLoginPassword(e.target.value)}
                      style={{ paddingLeft: '2.75rem', paddingRight: '2.5rem' }}
                      className="w-full py-2.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs text-[#0F172A] placeholder-[#94A3B8] focus:outline-none focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] focus:bg-[#FFFFFF] transition-all"
                    />
                    <button
                      type="button"
                      onClick={() => setShowLoginPassword((p) => !p)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-[#64748B] hover:text-[#0F172A] cursor-pointer"
                    >
                      {showLoginPassword ? <EyeOff size={15} /> : <Eye size={15} />}
                    </button>
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full mt-2 flex items-center justify-center gap-2 py-3 rounded-xl bg-[#2563EB] hover:bg-[#1D4ED8] text-white text-xs font-bold tracking-tight transition-all active:scale-[0.98] shadow-md cursor-pointer disabled:opacity-60"
                >
                  {loading ? (
                    <RefreshCw size={14} className="animate-spin" />
                  ) : (
                    <>
                      <span>Sign In</span>
                      <ArrowRight size={14} />
                    </>
                  )}
                </button>
              </form>

              <div className="pt-2 border-t border-[#DCE7F6] flex items-center justify-between text-xs">
                <button
                  type="button"
                  onClick={() => {
                    setErrorMessage(null);
                    setView('welcome');
                  }}
                  className="text-[#64748B] hover:text-[#0F172A] cursor-pointer"
                >
                  Use Email OTP instead
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setErrorMessage(null);
                    setView('register');
                  }}
                  className="text-[#2563EB] font-semibold underline hover:text-[#1D4ED8] cursor-pointer"
                >
                  Create account
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
