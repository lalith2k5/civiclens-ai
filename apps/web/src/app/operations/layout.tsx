import { Suspense } from "react";
import AppShell from "@/components/layout/app-shell";

export const instant = false;

export default function OpsLayout({ children }: { children: React.ReactNode }) {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center bg-slate-50 text-slate-500">Loading Workspace...</div>}>
      <AppShell>{children}</AppShell>
    </Suspense>
  );
}
