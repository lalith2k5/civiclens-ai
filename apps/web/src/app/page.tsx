"use client";
import { useRef } from "react";
import { motion, useScroll, useTransform } from "framer-motion";
import { Button } from "@/components/ui/button";
import { Map, ShieldCheck, Activity } from "lucide-react";
import Link from "next/link";

export default function Home() {
  const containerRef = useRef(null);
  
  // Track scroll progress from 0 to 1
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end end"]
  });

  // Section 1 Animations
  const s1Opacity = useTransform(scrollYProgress, [0, 0.2], [1, 0]);
  const s1Scale = useTransform(scrollYProgress, [0, 0.2], [1, 1.1]);
  
  // Section 2 Animations
  const s2Opacity = useTransform(scrollYProgress, [0.2, 0.35, 0.5], [0, 1, 0]);
  const s2Scale = useTransform(scrollYProgress, [0.2, 0.35, 0.5], [0.8, 1, 1.1]);
  
  // Section 3 Animations
  const s3Opacity = useTransform(scrollYProgress, [0.5, 0.65, 0.8], [0, 1, 0]);
  const s3Scale = useTransform(scrollYProgress, [0.5, 0.65, 0.8], [0.8, 1, 1.1]);

  // Section 4 (CTA) Animations
  const s4Opacity = useTransform(scrollYProgress, [0.8, 0.95], [0, 1]);
  const s4Scale = useTransform(scrollYProgress, [0.8, 0.95], [0.9, 1]);

  return (
    <div className="bg-[#050505] text-white selection:bg-sky-500/30">
      
      {/* Clean Fixed Navbar */}
      <header className="fixed top-0 w-full px-6 py-4 flex items-center justify-between z-50 bg-black/60 backdrop-blur-2xl border-b border-white/[0.05]">
        <div className="flex items-center gap-2">
          <div className="h-8 w-8 rounded-lg bg-sky-600 flex items-center justify-center text-white font-bold">C</div>
          <span className="font-semibold text-lg tracking-tight">CIVICLENS AI</span>
        </div>
        <div className="flex gap-4">
          <Link href="/login"><Button variant="ghost" className="text-slate-300 hover:text-white">Sign In</Button></Link>
          <Link href="/register"><Button className="bg-sky-600 hover:bg-sky-500 text-white rounded-full px-6">Get Started</Button></Link>
        </div>
      </header>

      {/* The scroll container that holds the "video" frames */}
      <div ref={containerRef} className="h-[400vh] relative">
        
        {/* Sticky viewport container */}
        <div className="sticky top-0 h-screen w-full overflow-hidden flex items-center justify-center">
          
          {/* FRAME 1: Hero */}
          <motion.div style={{ opacity: s1Opacity, scale: s1Scale }} className="absolute inset-0 flex flex-col items-center justify-center text-center px-6">
            <motion.h1 
              initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 1, delay: 0.2 }}
              className="text-5xl md:text-8xl font-semibold tracking-tighter mb-6 text-white"
            >
              Municipal operations.<br />
              <span className="text-sky-500">Reimagined.</span>
            </motion.h1>
            <motion.p 
              initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 1, delay: 0.4 }}
              className="text-xl md:text-2xl text-slate-400 max-w-2xl font-normal"
            >
              Empowering city administrators with AI-driven issue resolution and real-time analytics.
            </motion.p>
            <motion.div 
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 1, delay: 0.8 }}
              className="absolute bottom-10 animate-bounce text-slate-500 text-sm flex flex-col items-center"
            >
              <span>Scroll to explore</span>
              <div className="w-[1px] h-8 bg-sky-500 mt-2"></div>
            </motion.div>
          </motion.div>

          {/* FRAME 2: Automated Triage */}
          <motion.div style={{ opacity: s2Opacity, scale: s2Scale }} className="absolute inset-0 flex flex-col items-center justify-center text-center px-6">
            <div className="mb-8 p-4 bg-sky-500/10 rounded-full">
              <Map className="h-16 w-16 text-sky-500" />
            </div>
            <h2 className="text-4xl md:text-6xl font-semibold tracking-tight mb-6">
              It starts with a <span className="text-sky-500">photo</span>.
            </h2>
            <p className="text-lg md:text-xl text-slate-400 max-w-2xl">
              Deep learning instantly classifies potholes, waste, and infrastructure issues with 98% accuracy, routing them to the correct department.
            </p>
          </motion.div>

          {/* FRAME 3: Actionable Intelligence */}
          <motion.div style={{ opacity: s3Opacity, scale: s3Scale }} className="absolute inset-0 flex flex-col items-center justify-center text-center px-6">
            <div className="mb-8 p-4 bg-sky-500/10 rounded-full">
              <Activity className="h-16 w-16 text-sky-500" />
            </div>
            <h2 className="text-4xl md:text-6xl font-semibold tracking-tight mb-6">
              Data-driven <span className="text-sky-500">insights</span>.
            </h2>
            <p className="text-lg md:text-xl text-slate-400 max-w-2xl">
              Identify high-density issue zones with DBSCAN clustering. Forecast future complaint volumes and optimize city resources.
            </p>
          </motion.div>

          {/* FRAME 4: CTA */}
          <motion.div style={{ opacity: s4Opacity, scale: s4Scale }} className="absolute inset-0 flex flex-col items-center justify-center text-center px-6">
            <div className="mb-8 p-4 bg-sky-500/10 rounded-full">
              <ShieldCheck className="h-16 w-16 text-sky-500" />
            </div>
            <h2 className="text-4xl md:text-6xl font-semibold tracking-tight mb-6">
              Transparent resolution.
            </h2>
            <p className="text-lg md:text-xl text-slate-400 max-w-2xl mb-10">
              From submission to field worker dispatch, every status transition is tracked in an immutable audit trail.
            </p>
            <div className="flex gap-4">
              <Link href="/register"><Button size="lg" className="bg-white text-black hover:bg-slate-200 rounded-full px-10 h-14 text-lg">Create Account</Button></Link>
              <Link href="/login"><Button size="lg" variant="outline" className="border-white/20 text-white hover:bg-white/5 rounded-full px-10 h-14 text-lg">Sign In</Button></Link>
            </div>
          </motion.div>

        </div>
      </div>

      <footer className="py-8 text-center text-sm text-slate-600 border-t border-white/5 bg-[#050505] relative z-10">
        © 2026 CIVICLENS AI. Not an emergency service. Call 112 for emergencies.
      </footer>
    </div>
  );
}
