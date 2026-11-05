import { Suspense } from "react";
import AppShell from "@/components/layout/app-shell";

export default function IntelligenceLayout({ children }: { children: React.ReactNode }) {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center">Loading...</div>}>
      <AppShell>{children}</AppShell>
    </Suspense>
  );
}
