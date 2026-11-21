"use client";
import { motion } from "framer-motion";

export default function AnimatedBackground() {
  return (
    <div className="fixed inset-0 z-0 pointer-events-none overflow-hidden bg-[#050505]">
      {/* Neon Grid */}
      <div className="absolute inset-0 bg-[linear-gradient(to_right,#ffffff03_1px,transparent_1px),linear-gradient(to_bottom,#ffffff03_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_0%,#000_70%,transparent_100%)]"></div>
      
      {/* Neon Orbs */}
      <motion.div 
        animate={{ x: [0, 100, 0], y: [0, 50, 0], scale: [1, 1.2, 1] }} 
        transition={{ repeat: Infinity, duration: 20, ease: "easeInOut" }} 
        className="absolute top-0 left-1/4 w-[600px] h-[600px] bg-sky-500/10 rounded-full blur-[100px] mix-blend-screen"
      />
      <motion.div 
        animate={{ x: [0, -100, 0], y: [0, -50, 0], scale: [1, 1.3, 1] }} 
        transition={{ repeat: Infinity, duration: 25, ease: "easeInOut" }} 
        className="absolute bottom-0 right-1/4 w-[500px] h-[500px] bg-cyan-500/10 rounded-full blur-[100px] mix-blend-screen"
      />
      <motion.div 
        animate={{ x: [0, 80, 0], y: [0, -80, 0], scale: [1, 1.1, 1] }} 
        transition={{ repeat: Infinity, duration: 30, ease: "easeInOut" }} 
        className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[400px] h-[400px] bg-purple-500/10 rounded-full blur-[100px] mix-blend-screen"
      />
    </div>
  );
}
