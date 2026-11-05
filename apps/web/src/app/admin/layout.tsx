import { Suspense } from "react";
import AppShell from "@/components/layout/app-shell";

export const instant = false;

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center">Loading...</div>}>
      <AppShell>{children}</AppShell>
    </Suspense>
  );
}
