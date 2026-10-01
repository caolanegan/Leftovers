import { NavLink, Outlet } from 'react-router'
import { CalendarDays, Settings, ShoppingCart, UtensilsCrossed } from 'lucide-react'

const tabs = [
  { to: '/plan', label: 'Plan', Icon: CalendarDays },
  { to: '/meals', label: 'Meals', Icon: UtensilsCrossed },
  { to: '/shopping', label: 'Shopping', Icon: ShoppingCart },
  { to: '/settings', label: 'Settings', Icon: Settings },
]

// Ingredients and settings sub-pages belong to a parent tab, so that tab stays highlighted.
export function Layout() {
  return (
    <div className="min-h-dvh md:pl-56">
      <nav
        aria-label="Main"
        className="fixed inset-x-0 bottom-0 z-10 border-t border-neutral-200 bg-white/95 pb-[env(safe-area-inset-bottom)] backdrop-blur dark:border-neutral-800 dark:bg-neutral-900/95 md:inset-y-0 md:right-auto md:w-56 md:border-r md:border-t-0 md:pb-0"
      >
        <p className="hidden px-5 pb-2 pt-6 text-xl font-bold text-accent dark:text-accent-dark md:block">
          Leftovers
        </p>
        <ul className="flex md:flex-col md:gap-1 md:p-3">
          {tabs.map(({ to, label, Icon }) => (
            <li key={to} className="flex-1 md:flex-none">
              <NavLink
                to={to}
                className={({ isActive }) =>
                  `flex flex-col items-center gap-1 px-2 py-2 text-xs font-medium md:flex-row md:gap-3 md:rounded-lg md:px-3 md:py-2.5 md:text-base ${
                    isActive
                      ? 'text-accent dark:text-accent-dark md:bg-accent/10'
                      : 'text-neutral-600 dark:text-neutral-400'
                  }`
                }
              >
                <Icon aria-hidden="true" className="size-6 md:size-5" />
                {label}
              </NavLink>
            </li>
          ))}
        </ul>
      </nav>
      <main className="mx-auto max-w-3xl px-4 pb-28 pt-[max(1.5rem,env(safe-area-inset-top))] md:pb-10">
        <Outlet />
      </main>
    </div>
  )
}
