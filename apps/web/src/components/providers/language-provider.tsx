"use client";
import { createContext, useContext, useState, useEffect } from "react";
import { translations, Language } from "@/lib/i18n";

const LanguageContext = createContext<any>(null);

export default function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [lang, setLang] = useState<Language>('en');

  useEffect(() => {
    const saved = localStorage.getItem('civiclens_lang') as Language;
    if (saved) setLang(saved);
  }, []);

  const changeLang = (newLang: Language) => {
    setLang(newLang);
    localStorage.setItem('civiclens_lang', newLang);
  };

  const t = (key: keyof typeof translations['en']) => translations[lang][key] || translations['en'][key];

  return <LanguageContext.Provider value={{ lang, changeLang, t }}>{children}</LanguageContext.Provider>;
}

export const useLanguage = () => useContext(LanguageContext);
