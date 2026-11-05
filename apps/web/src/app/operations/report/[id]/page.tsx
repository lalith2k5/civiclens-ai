import { Suspense } from "react";
import ReportClient from "./ReportClient";

export default async function ReportPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return (
    <div className="min-h-screen bg-slate-50 p-6">
      <Suspense fallback={<div className="p-10 text-center text-slate-500">Loading workspace...</div>}>
        <ReportClient id={id} />
      </Suspense>
    </div>
  );
}
