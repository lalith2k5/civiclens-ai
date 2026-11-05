"use client";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { ArrowRight, MapPin, ShieldCheck, Activity, ChevronDown } from "lucide-react";
import Link from "next/link";

const faqs = [
  { q: "What is CIVICLENS AI?", a: "A civic operations platform connecting residents, municipal teams, and data intelligence." },
  { q: "Is this an emergency service?", a: "No. For immediate danger, fire, or medical emergencies, call 112." },
  { q: "How does the AI work?", a: "We use computer vision to classify issues and route them to the right department." }
];

export default function Home() {
  const [openFaq, setOpenFaq] = useState<number | null>(null);

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col">
      <header className="px-6 py-4 flex items-center justify-between border-b bg-white sticky top-0 z-50">
        <div className="flex items-center gap-2">
          <div className="h-8 w-8 rounded bg-primary flex items-center justify-center text-white font-bold">C</div>
          <span className="font-bold text-xl tracking-tight text-slate-900">CIVICLENS AI</span>
        </div>
        <nav className="hidden md:flex gap-6 text-sm font-medium text-slate-600">
          <a href="#how-it-works" className="hover:text-primary">How it works</a>
          <a href="#for-authorities" className="hover:text-primary">For Authorities</a>
          <a href="#faq" className="hover:text-primary">FAQ</a>
        </nav>
        <div className="flex gap-2">
          <Link href="/login"><Button variant="ghost">Sign In</Button></Link>
          <Link href="/register"><Button>Report an Issue</Button></Link>
        </div>
      </header>

      <main className="flex-1">
        <section className="flex flex-col items-center justify-center text-center px-4 py-24">
          <Badge className="mb-4" variant="secondary">Hyderabad Pilot Phase</Badge>
          <h1 className="text-5xl font-extrabold tracking-tight text-slate-900 max-w-3xl mb-6">
            Intelligent Urban Problem Detection & Resolution
          </h1>
          <p className="text-lg text-slate-600 max-w-2xl mb-10">
            Connecting citizens, municipal operations teams, and data intelligence through transparent reporting and evidence-based prediction.
          </p>
          <div className="flex gap-4">
            <Link href="/report"><Button size="lg" className="gap-2">Report an Issue <ArrowRight className="h-4 w-4" /></Button></Link>
            <Link href="/login"><Button size="lg" variant="outline">Operations Login</Button></Link>
          </div>
        </section>

        <section id="how-it-works" className="py-20 bg-white">
          <div className="max-w-5xl mx-auto px-6">
            <h2 className="text-3xl font-bold text-center mb-12">How it works</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="p-6 bg-slate-50 rounded-xl text-center"><MapPin className="h-10 w-10 text-primary mx-auto mb-4" /><h3 className="font-bold text-lg mb-2">1. Report</h3><p className="text-slate-500 text-sm">Pin the location and upload a photo. Our AI auto-categorizes it.</p></div>
              <div className="p-6 bg-slate-50 rounded-xl text-center"><ShieldCheck className="h-10 w-10 text-primary mx-auto mb-4" /><h3 className="font-bold text-lg mb-2">2. Track</h3><p className="text-slate-500 text-sm">Receive a reference code and watch the status update in real-time.</p></div>
              <div className="p-6 bg-slate-50 rounded-xl text-center"><Activity className="h-10 w-10 text-primary mx-auto mb-4" /><h3 className="font-bold text-lg mb-2">3. Resolve</h3><p className="text-slate-500 text-sm">Municipal teams dispatch workers and provide completion evidence.</p></div>
            </div>
          </div>
        </section>

        <section id="for-authorities" className="py-20 bg-slate-900 text-white text-center">
          <div className="max-w-3xl mx-auto px-6">
            <h2 className="text-3xl font-bold mb-4">Built for Municipal Operations</h2>
            <p className="text-slate-400 mb-8">Command dashboard, field worker dispatch, DBSCAN hotspots, and predictive resolution-time estimation.</p>
            <Link href="/login"><Button size="lg" variant="secondary">Access Operations Portal</Button></Link>
          </div>
        </section>

        <section id="faq" className="py-20 bg-white">
          <div className="max-w-2xl mx-auto px-6">
            <h2 className="text-3xl font-bold text-center mb-10">Frequently Asked Questions</h2>
            <div className="space-y-4">
              {faqs.map((f, i) => (
                <div key={i} className="border rounded-xl overflow-hidden">
                  <button onClick={() => setOpenFaq(openFaq === i ? null : i)} className="w-full flex justify-between items-center p-4 font-medium text-left bg-slate-50 hover:bg-slate-100">
                    {f.q}
                    <ChevronDown className={`h-4 w-4 transition-transform ${openFaq === i ? 'rotate-180' : ''}`} />
                  </button>
                  {openFaq === i && <div className="p-4 text-sm text-slate-600 bg-white border-t">{f.a}</div>}
                </div>
              ))}
            </div>
          </div>
        </section>
      </main>
      
      <footer className="py-8 text-center text-sm text-slate-500 border-t bg-white">
        © 2026 CIVICLENS AI. Not an emergency service. Call 112 for emergencies.
      </footer>
    </div>
  );
}
