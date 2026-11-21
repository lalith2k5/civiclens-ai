"use client";
import { createContext, useContext, useEffect } from "react";

const ThemeContext = createContext({ theme: "dark", toggleTheme: () => {} });

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    document.documentElement.classList.add("dark");
    document.documentElement.style.colorScheme = "dark";
    localStorage.setItem("civiclens-theme", "dark");
  }, []);

  return <ThemeContext.Provider value={{ theme: "dark", toggleTheme: () => {} }}>{children}</ThemeContext.Provider>;
}
export const useTheme = () => useContext(ThemeContext);
