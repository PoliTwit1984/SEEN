import { useState, useEffect } from 'react';
import { Users, Target, Camera, Shield, ArrowRight, CheckCircle2, Zap, Eye, Share2, Trophy } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import axios from 'axios';

// GetWaitlist Configuration - Get your Waitlist ID from the GetWaitlist dashboard
const GETWAITLIST_ID = 'YOUR_WAITLIST_ID'; 

function IPhoneMockup() {
  return (
    <div className="relative mx-auto w-[280px] h-[580px] md:w-[320px] md:h-[650px] bg-[#1a1a1a] rounded-[3.5rem] border-[8px] border-[#333] shadow-2xl overflow-hidden group">
      {/* Notch / Dynamic Island */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-24 h-6 bg-black rounded-b-2xl z-20" />
      
      {/* App Content */}
      <div className="h-full bg-black flex flex-col pt-10 px-4">
        {/* Header */}
        <div className="flex justify-between items-center mb-6 px-2">
          <div className="text-xl font-black tracking-tight">Morning Crew</div>
          <div className="w-8 h-8 glass rounded-full flex items-center justify-center">
            <Users className="w-4 h-4 text-white/40" />
          </div>
        </div>

        {/* Today's Status */}
        <div className="flex space-x-4 overflow-x-auto pb-4 scrollbar-hide mb-4 px-2">
          {[
            { name: "Joe", progress: 100 },
            { name: "Sarah", progress: 60 },
            { name: "Mike", progress: 0 },
            { name: "Alex", progress: 0 }
          ].map((member, i) => (
            <div key={i} className="flex flex-col items-center space-y-2 shrink-0">
              <div className="relative w-12 h-12">
                <svg className="absolute inset-0 w-full h-full -rotate-90">
                  <circle 
                    cx="24" cy="24" r="21" 
                    fill="none" stroke="currentColor" strokeWidth="3"
                    className="text-white/10"
                  />
                  <circle 
                    cx="24" cy="24" r="21" 
                    fill="none" stroke="currentColor" strokeWidth="3"
                    strokeDasharray={`${2 * Math.PI * 21}`}
                    strokeDashoffset={`${2 * Math.PI * 21 * (1 - member.progress / 100)}`}
                    className={`${member.progress === 100 ? 'text-green-400' : 'text-purple-400'}`}
                  />
                </svg>
                <div className="absolute inset-1 rounded-full bg-white/10" />
              </div>
              <span className="text-[10px] font-bold text-white/40">{member.name}</span>
            </div>
          ))}
        </div>

        {/* Feed */}
        <div className="flex-1 space-y-4 overflow-y-auto pb-20 scrollbar-hide">
          <div className="glass rounded-3xl p-4 border-white/10">
            <div className="flex items-center space-x-3 mb-3">
              <div className="w-8 h-8 rounded-full bg-blue-500/20 border border-blue-500/30" />
              <div>
                <div className="text-[11px] font-bold">Joe Wilson</div>
                <div className="text-[9px] text-white/40 font-medium">Checked in • 2m ago</div>
              </div>
            </div>
            <div className="aspect-square bg-white/5 rounded-2xl mb-3 flex items-center justify-center relative overflow-hidden">
              <Camera className="w-8 h-8 text-white/10" />
              <div className="absolute inset-0 bg-linear-to-tr from-purple-500/10 to-transparent" />
            </div>
            <div className="text-[12px] font-bold mb-1 italic">"5k done. ❄️"</div>
            <div className="flex space-x-2">
              <div className="px-2 py-1 bg-white/5 rounded-full text-[9px] font-bold text-white/40">🔥 12</div>
              <div className="px-2 py-1 bg-white/5 rounded-full text-[9px] font-bold text-white/40">💪 4</div>
            </div>
          </div>

          <div className="glass rounded-3xl p-4 border-white/10 opacity-60 scale-95 origin-top">
            <div className="flex items-center space-x-3 mb-3">
              <div className="w-8 h-8 rounded-full bg-pink-500/20 border border-pink-500/30" />
              <div>
                <div className="text-[11px] font-bold">Sarah Lane</div>
                <div className="text-[9px] text-white/40 font-medium">Checked in • 1h ago</div>
              </div>
            </div>
            <div className="h-20 bg-white/5 rounded-2xl flex items-center justify-center">
               <div className="text-[10px] font-bold text-white/20 uppercase tracking-widest italic">Reading Proof</div>
            </div>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="absolute bottom-4 left-4 right-4 h-16 glass rounded-2xl border-white/20 flex items-center justify-center">
          <button className="bg-white text-black px-8 py-2.5 rounded-xl text-[13px] font-black hover:scale-105 active:scale-95 transition-all shadow-xl">
            Check-In
          </button>
        </div>
      </div>

      {/* Glossy Overlay */}
      <div className="absolute inset-0 pointer-events-none bg-linear-to-tr from-white/5 via-transparent to-transparent z-30" />
    </div>
  );
}

function App() {
  const [email, setEmail] = useState('');
  const [name, setName] = useState('');
  const [status, setStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle');
  const [message, setMessage] = useState('');
  const [scrolled, setScrolled] = useState(false);
  const [userData, setUserData] = useState<{ referral_link?: string, priority?: number } | null>(null);

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatus('loading');
    
    // Extract referral from URL
    const urlParams = new URLSearchParams(window.location.search);
    const referrer = urlParams.get('ref') || '';

    try {
      const response = await axios.post('https://getwaitlist.com/api/v1/signup', {
        waitlist_id: GETWAITLIST_ID,
        email: email,
        first_name: name, // Using first_name as per API docs
        referrer: referrer,
        referral_link: window.location.origin,
      });

      if (response.data) {
        setStatus('success');
        setUserData({
          referral_link: response.data.referral_link,
          priority: response.data.priority,
        });
      }
    } catch (error: any) {
      console.error('Waitlist Error:', error);
      setStatus('error');
      setMessage(error.response?.data?.message || 'Something went wrong. Please try again.');
    }
  };

  const copyReferralLink = () => {
    if (userData?.referral_link) {
      navigator.clipboard.writeText(userData.referral_link);
      alert('Referral link copied!');
    }
  };

  return (
    <div className="min-h-screen bg-black text-white font-sans selection:bg-purple-500/30 selection:text-white">
      {/* Liquid Background Blobs */}
      <div className="liquid-bg">
        <div className="blob" />
        <div className="blob blob-2" />
        <div className="blob blob-3" />
      </div>

      {/* Navigation */}
      <nav className={`fixed top-0 w-full z-50 transition-all duration-500 ${scrolled ? 'py-4' : 'py-8'}`}>
        <div className="max-w-5xl mx-auto px-6">
          <div className={`glass rounded-full px-8 py-3 flex items-center justify-between transition-all duration-500 ${scrolled ? 'mx-0' : 'mx-4'}`}>
            <div className="flex items-center space-x-2">
              <div className="w-8 h-8 bg-white rounded-lg flex items-center justify-center">
                <Eye className="w-5 h-5 text-black" />
              </div>
              <span className="text-xl font-bold tracking-tight">SEEN</span>
            </div>
            <div className="hidden md:flex space-x-8 text-[13px] font-semibold text-white/50 uppercase tracking-widest">
              <a href="#how-it-works" className="hover:text-white transition-colors">How it works</a>
              <a href="#features" className="hover:text-white transition-colors">Features</a>
            </div>
            <a 
              href="#waitlist" 
              className="bg-white text-black px-6 py-2 rounded-full text-sm font-bold hover:scale-105 active:scale-95 transition-all shadow-[0_0_20px_rgba(255,255,255,0.3)]"
            >
              Join
            </a>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="relative pt-48 pb-32 px-6 overflow-hidden">
        <div className="max-w-7xl mx-auto flex flex-col lg:flex-row items-center justify-between relative z-10 gap-20">
          <motion.div
            initial={{ opacity: 0, x: -30 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 1, ease: [0.22, 1, 0.36, 1] }}
            className="flex-1 text-center lg:text-left"
          >
            <div className="inline-flex items-center space-x-2 bg-white/5 border border-white/10 rounded-full px-4 py-1.5 mb-8 backdrop-blur-md">
              <Zap className="w-4 h-4 text-purple-400" />
              <span className="text-[11px] font-bold uppercase tracking-[0.2em] text-white/60">Beta Access Now Open</span>
            </div>
            <h1 className="text-6xl md:text-[90px] xl:text-[110px] font-black tracking-tightest mb-10 leading-[0.85] liquid-text">
              WILLPOWER<br />IS A <span className="text-white/20 italic">LIE.</span>
            </h1>
            <p className="max-w-xl mx-auto lg:mx-0 text-lg md:text-xl text-white/40 mb-14 font-medium leading-relaxed">
              You don't need another habit tracker. You need a crew that knows when you're slacking. SEEN turns social friction into your greatest asset.
            </p>

            <div className="flex flex-col sm:flex-row items-center justify-center lg:justify-start space-y-4 sm:space-y-0 sm:space-x-6">
              <a href="#waitlist" className="w-full sm:w-auto bg-white text-black px-10 py-5 rounded-2xl text-lg font-bold hover:scale-105 active:scale-95 transition-all shadow-[0_20px_40px_rgba(255,255,255,0.15)] flex items-center justify-center space-x-2">
                <span>Join the Waitlist</span>
                <ArrowRight className="w-5 h-5" />
              </a>
              <a href="#how-it-works" className="w-full sm:w-auto glass-dark px-10 py-5 rounded-2xl text-lg font-bold hover:bg-white/5 transition-all flex items-center justify-center">
                How it works
              </a>
            </div>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, x: 30, rotate: 5 }}
            animate={{ opacity: 1, x: 0, rotate: 0 }}
            transition={{ delay: 0.2, duration: 1, ease: [0.22, 1, 0.36, 1] }}
            className="flex-1 flex justify-center lg:justify-end"
          >
            <IPhoneMockup />
          </motion.div>
        </div>

        {/* Floating Glass Elements */}
        <motion.div 
          animate={{ y: [0, -20, 0] }}
          transition={{ duration: 6, repeat: Infinity, ease: "easeInOut" }}
          className="absolute top-1/2 left-0 w-64 h-80 glass rounded-[3rem] -rotate-12 opacity-20 hidden lg:block"
        />
      </section>

      {/* Stats Section */}
      <section className="py-20 px-6">
        <div className="max-w-5xl mx-auto grid grid-cols-2 md:grid-cols-4 gap-4">
          <StatCard label="Pods Created" value="1.2k" />
          <StatCard label="Success Rate" value="94%" />
          <StatCard label="Proof Uploads" value="45k" />
          <StatCard label="Stakes Paid" value="$12k" />
        </div>
      </section>

      {/* Steps Section */}
      <section id="how-it-works" className="py-32 px-6 relative">
        <div className="max-w-6xl mx-auto glass rounded-[4rem] p-12 md:p-24 overflow-hidden relative">
          <div className="absolute top-0 right-0 w-96 h-96 bg-purple-600/20 blur-[120px] rounded-full -mr-48 -mt-48" />
          
          <div className="relative z-10 grid md:grid-cols-2 gap-20 items-center">
            <div>
              <div className="w-12 h-12 bg-white/10 rounded-2xl flex items-center justify-center mb-8 border border-white/20">
                <Shield className="w-6 h-6 text-white" />
              </div>
              <h2 className="text-4xl md:text-6xl font-black mb-8 leading-tight tracking-tight">
                The Protocol of<br />Witness.
              </h2>
              <div className="space-y-8">
                <div>
                  <h3 className="text-2xl font-bold mb-3 text-white">1. Form Your Pod</h3>
                  <p className="text-lg text-white/50 leading-relaxed font-medium">
                    Invite 2-8 people you trust—or people you're afraid to let down. Small groups mean nowhere to hide.
                  </p>
                </div>
                <div>
                  <h3 className="text-2xl font-bold mb-3 text-white">2. Set Your Stakes</h3>
                  <p className="text-lg text-white/50 leading-relaxed font-medium">
                    Define the penalty for a missed day. Loser buys dinner, pays $20 to the group pot, or completes a forfeit. The friction makes it real.
                  </p>
                </div>
                <div>
                  <h3 className="text-2xl font-bold mb-3 text-white">3. Upload the Proof</h3>
                  <p className="text-lg text-white/50 leading-relaxed font-medium">
                    A check-in isn't a tap—it's a photo or video. If the group doesn't see it, it didn't happen.
                  </p>
                </div>
              </div>
            </div>
            
            <div className="relative">
              <div className="aspect-square glass rounded-[3rem] border border-white/20 p-8 flex flex-col justify-center">
                <div className="space-y-6">
                  {[1, 2, 3].map((i) => (
                    <motion.div 
                      key={i}
                      initial={{ opacity: 0, x: 20 }}
                      whileInView={{ opacity: 1, x: 0 }}
                      transition={{ delay: i * 0.1 }}
                      className="bg-white/5 border border-white/10 p-5 rounded-2xl flex items-center justify-between"
                    >
                      <div className="flex items-center space-x-4">
                        <div className="w-10 h-10 rounded-full bg-white/10 animate-pulse" />
                        <div>
                          <div className="w-24 h-3 bg-white/20 rounded-full mb-2" />
                          <div className="w-16 h-2 bg-white/10 rounded-full" />
                        </div>
                      </div>
                      <CheckCircle2 className={`w-6 h-6 ${i === 1 ? 'text-green-400' : 'text-white/20'}`} />
                    </motion.div>
                  ))}
                </div>
              </div>
              {/* Glossy Overlay */}
              <div className="absolute inset-0 bg-linear-to-tr from-white/10 to-transparent pointer-events-none rounded-[3rem]" />
            </div>
          </div>
        </div>
      </section>

      {/* Feature Grid */}
      <section id="features" className="py-32 px-6">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-24">
            <h2 className="text-5xl md:text-7xl font-black mb-6 tracking-tight">Built to last.</h2>
            <p className="text-xl text-white/40 max-w-2xl mx-auto font-medium">Simple tools, deep psychological impact.</p>
          </div>
          
          <div className="grid md:grid-cols-3 gap-8">
            <GlassCard 
              icon={<Users className="w-7 h-7" />}
              title="Social Friction"
              description="Most apps fail because they're too nice. We leverage the healthy pressure of your peer group to keep you moving."
              color="blue"
            />
            <GlassCard 
              icon={<Target className="text-purple-400" />}
              title="Stakes that Sting"
              description="Financial or social consequences for every missed day. Integrity is free; failure has a price tag."
              color="purple"
            />
            <GlassCard 
              icon={<Camera className="w-7 h-7" />}
              title="Visual Truth"
              description="Every check-in requires photo or video proof. No honor system, just high-definition accountability."
              color="pink"
            />
          </div>
        </div>
      </section>

      {/* Waitlist Section */}
      <section id="waitlist" className="py-32 px-6 relative overflow-hidden">
        {/* Glowing Background */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-purple-600/30 blur-[150px] rounded-full" />

        <div className="max-w-3xl mx-auto relative z-10">
          <div className="glass rounded-[4rem] p-12 md:p-20 text-center border-white/20">
            <h2 className="text-5xl md:text-7xl font-black mb-8 tracking-tight">The list is<br />growing.</h2>
            <p className="text-xl md:text-2xl font-medium mb-12 text-white/50 leading-relaxed">
              We're letting in users in batches to maintain pod quality. Secure your spot and move up the line.
            </p>

            <AnimatePresence mode="wait">
              {status === 'success' ? (
                <motion.div 
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 1.1 }}
                  className="space-y-8"
                >
                  <div className="w-20 h-20 bg-green-500/20 rounded-3xl flex items-center justify-center mx-auto mb-8 border border-green-500/30">
                    <CheckCircle2 className="w-10 h-10 text-green-400" />
                  </div>
                  
                  <div>
                    <div className="text-3xl font-black mb-2 tracking-tight">You're on the list!</div>
                    <p className="text-white/40 font-medium italic">We'll text you when your pod is ready.</p>
                  </div>

                  {/* Leaderboard/Referral Section */}
                  <div className="bg-white/5 border border-white/10 rounded-3xl p-8 space-y-6">
                    <div className="flex justify-between items-center">
                      <div className="text-left">
                        <div className="text-[11px] font-bold uppercase tracking-widest text-white/40 mb-1">Current Position</div>
                        <div className="text-4xl font-black tracking-tight">#{userData?.priority || '---'}</div>
                      </div>
                      <Trophy className="w-10 h-10 text-yellow-400 opacity-50" />
                    </div>

                    <div className="h-px bg-white/10 w-full" />

                    <div className="text-left">
                      <div className="text-sm font-bold mb-4">Move up the line by inviting others:</div>
                      <div className="flex space-x-2">
                        <div className="flex-1 bg-black/40 border border-white/10 rounded-2xl px-4 py-3 text-sm font-mono text-white/60 truncate">
                          {userData?.referral_link}
                        </div>
                        <button 
                          onClick={copyReferralLink}
                          className="bg-white text-black p-3 rounded-2xl hover:scale-105 active:scale-95 transition-all"
                        >
                          <Share2 className="w-5 h-5" />
                        </button>
                      </div>
                    </div>
                  </div>
                </motion.div>
              ) : (
                <motion.form 
                  onSubmit={handleSubmit}
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  className="space-y-6"
                >
                  <div className="grid md:grid-cols-2 gap-4">
                    <input 
                      type="text" 
                      placeholder="Name" 
                      required
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      className="w-full bg-white/5 border border-white/10 focus:border-white/30 px-8 py-5 rounded-3xl outline-none text-lg font-semibold transition-all backdrop-blur-md"
                    />
                    <input 
                      type="email" 
                      placeholder="Email" 
                      required
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      className="w-full bg-white/5 border border-white/10 focus:border-white/30 px-8 py-5 rounded-3xl outline-none text-lg font-semibold transition-all backdrop-blur-md"
                    />
                  </div>
                  <button 
                    type="submit" 
                    disabled={status === 'loading'}
                    className="w-full bg-white text-black px-8 py-6 rounded-3xl text-xl font-black hover:scale-[1.02] active:scale-[0.98] transition-all flex items-center justify-center space-x-3 disabled:opacity-50 shadow-[0_20px_40px_rgba(255,255,255,0.1)]"
                  >
                    <span>{status === 'loading' ? 'Joining...' : 'Get Early Access'}</span>
                    {status !== 'loading' && <ArrowRight className="w-6 h-6" />}
                  </button>
                  {status === 'error' && (
                    <motion.div 
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      className="text-red-400 font-bold"
                    >
                      {message}
                    </motion.div>
                  )}
                </motion.form>
              )}
            </AnimatePresence>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-20 px-6 border-t border-white/5 relative z-10">
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-10">
          <div className="flex items-center space-x-2">
            <div className="w-8 h-8 bg-white/10 rounded-lg flex items-center justify-center border border-white/20">
              <Eye className="w-5 h-5 text-white" />
            </div>
            <span className="text-2xl font-black tracking-tight">SEEN</span>
          </div>
          <div className="flex space-x-12 text-sm font-semibold text-white/30 uppercase tracking-widest">
            <a href="#" className="hover:text-white transition-colors">Twitter</a>
            <a href="#" className="hover:text-white transition-colors">Instagram</a>
            <a href="#" className="hover:text-white transition-colors">Privacy</a>
          </div>
          <div className="text-[11px] font-black uppercase tracking-[0.3em] text-white/20">
            © {new Date().getFullYear()} SEEN. BE WATCHED.
          </div>
        </div>
      </footer>
    </div>
  );
}

function StatCard({ label, value }: { label: string, value: string }) {
  return (
    <div className="glass rounded-3xl p-8 border-white/10 text-center">
      <div className="text-3xl md:text-4xl font-black mb-2 tracking-tight">{value}</div>
      <div className="text-[11px] font-bold uppercase tracking-widest text-white/30">{label}</div>
    </div>
  );
}

function GlassCard({ icon, title, description, color }: { icon: React.ReactNode, title: string, description: string, color: string }) {
  const colors: Record<string, string> = {
    blue: "text-blue-400 group-hover:bg-blue-400/20",
    purple: "text-purple-400 group-hover:bg-purple-400/20",
    pink: "text-pink-400 group-hover:bg-pink-400/20"
  };

  return (
    <div className="glass rounded-[3rem] p-12 border-white/10 hover:border-white/30 hover:-translate-y-2 transition-all duration-500 group relative overflow-hidden text-left">
      {/* Glossy Reflection */}
      <div className="absolute top-0 left-0 w-full h-1/2 bg-linear-to-b from-white/5 to-transparent pointer-events-none" />
      
      <div className={`mb-8 p-4 glass rounded-2xl w-fit transition-all duration-500 ${colors[color]} border-white/10 group-hover:border-white/40`}>
        {icon}
      </div>
      <h3 className="text-3xl font-black mb-6 tracking-tight">{title}</h3>
      <p className="text-lg text-white/40 leading-relaxed font-medium transition-colors group-hover:text-white/60">{description}</p>
    </div>
  );
}

export default App;
