import type { Metadata } from "next";
import "./globals.css";
import QueryProvider from "@/components/providers/query-provider";

export const metadata: Metadata = {
  title: "CIVICLENS AI",
  description: "Intelligent Urban Problem Detection",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <QueryProvider>{children}</QueryProvider>
      </body>
    </html>
  );
}
