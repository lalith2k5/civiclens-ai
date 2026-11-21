import type { Metadata } from "next";
import "./globals.css";
import QueryProvider from "@/components/providers/query-provider";
import LanguageProvider from "@/components/providers/language-provider";
import { ThemeProvider } from "@/components/providers/theme-provider";

export const metadata: Metadata = { title: "CIVICLENS AI", description: "Intelligent Urban Problem Detection" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body suppressHydrationWarning className="transition-colors duration-300">
        <ThemeProvider>
          <QueryProvider>
            <LanguageProvider>{children}</LanguageProvider>
          </QueryProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
