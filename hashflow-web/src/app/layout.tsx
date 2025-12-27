import "./globals.css";
import { ReactNode } from "react";

export const metadata = {
  title: "HashFlow Web",
  description: "Balance, withdraw, and solutions marketplace",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-slate-950 text-slate-100 min-h-screen">
        <div className="max-w-5xl mx-auto px-6 py-10 space-y-8">
          <header className="flex items-center justify-between">
            <div>
              <div className="text-xs uppercase tracking-[0.2em] text-slate-400">HashFlow</div>
              <div className="text-2xl font-semibold text-slate-100">Control Center</div>
            </div>
            <div className="text-sm text-slate-400">Testnet preview</div>
          </header>
          {children}
        </div>
      </body>
    </html>
  );
}
