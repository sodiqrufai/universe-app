'use client';

import { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import Link from 'next/link';

const NAV_ITEMS = [
  { href: '/dashboard', label: 'Overview', icon: '📊' },
  { href: '/dashboard/verifications', label: 'Verifications', icon: '✅' },
  { href: '/dashboard/students', label: 'Students', icon: '👥' },
  { href: '/dashboard/reports', label: 'Reports & Moderation', icon: '🚩' },
  { href: '/dashboard/universities', label: 'Universities', icon: '🏫' },
  { href: '/dashboard/announcements', label: 'Announcements', icon: '📢' },
  { href: '/dashboard/analytics', label: 'Analytics', icon: '📈' },
  { href: '/dashboard/admins', label: 'Admins', icon: '🔑' },
];

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [checked, setChecked] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem('admin_token');
    if (!token) {
      router.push('/login');
      return;
    }
    setChecked(true);
  }, [router]);

  const handleLogout = () => {
    localStorage.removeItem('admin_token');
    router.push('/login');
  };

  if (!checked) return null;

  return (
    <div className="min-h-screen flex bg-background">
      <aside className="w-64 shrink-0 bg-surface border-r border-border flex flex-col">
        <div className="px-6 py-5 border-b border-border">
          <p className="font-bold text-lg text-foreground">UniVerse</p>
          <p className="text-xs text-text-secondary">Admin Platform</p>
        </div>
        <nav className="flex-1 py-4 px-3 space-y-1">
          {NAV_ITEMS.map((item) => {
            const active =
              item.href === '/dashboard'
                ? pathname === '/dashboard'
                : pathname?.startsWith(item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`block px-3 py-2 rounded-lg text-sm font-medium transition ${
                  active
                    ? 'bg-primary text-white'
                    : 'text-text-secondary hover:bg-light-purple hover:text-primary'
                }`}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>
        <div className="p-3 border-t border-border">
          <button
            onClick={handleLogout}
            className="w-full text-left px-3 py-2 rounded-lg text-sm font-medium text-error hover:bg-error/10 transition"
          >
            Log Out
          </button>
        </div>
      </aside>
      <main className="flex-1 overflow-y-auto">{children}</main>
    </div>
  );
}
