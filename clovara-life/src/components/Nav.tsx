export type Surface = 'home' | 'care' | 'rewards' | 'shop' | 'coverage' | 'life'

export const SURFACES: { id: Surface; label: string; icon: JSX.Element }[] = [
  {
    id: 'home',
    label: 'Home',
    icon: (
      <>
        <path d="M3 11l9-8 9 8" />
        <path d="M5 10v10h14V10" />
      </>
    ),
  },
  {
    id: 'care',
    label: 'Care',
    icon: <path d="M21 12a8 8 0 0 1-8 8H4l2-3a8 8 0 1 1 15-5z" />,
  },
  {
    id: 'rewards',
    label: 'Rewards',
    icon: (
      <>
        <circle cx="12" cy="9" r="6" />
        <path d="M8.5 14L7 22l5-3 5 3-1.5-8" />
      </>
    ),
  },
  {
    id: 'shop',
    label: 'Shop',
    icon: (
      <>
        <path d="M6 7h12l1 14H5L6 7z" />
        <path d="M9 10V6a3 3 0 0 1 6 0v4" />
      </>
    ),
  },
  {
    id: 'coverage',
    label: 'Coverage',
    icon: (
      <>
        <path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6l8-3z" />
        <path d="M9 12l2 2 4-4" />
      </>
    ),
  },
  {
    id: 'life',
    label: 'Life',
    icon: <path d="M12 21C7 16.5 3 13 3 9a5 5 0 0 1 9-3 5 5 0 0 1 9 3c0 4-4 7.5-9 12z" />,
  },
]

function Icon({ children }: { children: React.ReactNode }) {
  return (
    <svg
      viewBox="0 0 24 24"
      aria-hidden="true"
      className="h-[21px] w-[21px] stroke-current"
      fill="none"
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {children}
    </svg>
  )
}

/** Desktop: a horizontal rail under the brand. Hidden on small screens. */
export function TopNav({
  active,
  onChange,
}: {
  active: Surface
  onChange: (s: Surface) => void
}) {
  return (
    <nav aria-label="Sections" className="hidden md:block">
      <ul className="flex items-center gap-1">
        {SURFACES.map((s) => {
          const on = s.id === active
          return (
            <li key={s.id}>
              <button
                type="button"
                onClick={() => onChange(s.id)}
                aria-current={on ? 'page' : undefined}
                className={`rounded-full px-3.5 py-2 text-[14px] font-medium transition ${
                  on ? 'bg-ink text-cream' : 'text-muted hover:bg-white hover:text-ink'
                }`}
              >
                {s.label}
              </button>
            </li>
          )
        })}
      </ul>
    </nav>
  )
}

/** Mobile: a bottom tab bar, as in the platform concept. */
export function TabBar({
  active,
  onChange,
}: {
  active: Surface
  onChange: (s: Surface) => void
}) {
  return (
    <nav
      aria-label="Sections"
      className="fixed bottom-0 left-0 right-0 z-30 border-t border-line bg-white/95 backdrop-blur-md md:hidden"
      style={{ paddingBottom: 'env(safe-area-inset-bottom)' }}
    >
      <ul className="flex">
        {SURFACES.map((s) => {
          const on = s.id === active
          return (
            <li key={s.id} className="flex-1">
              <button
                type="button"
                onClick={() => onChange(s.id)}
                aria-current={on ? 'page' : undefined}
                className={`flex w-full flex-col items-center justify-center gap-1 py-2.5 text-[9.5px] font-medium transition ${
                  on ? 'text-forest' : 'text-muted'
                }`}
              >
                <Icon>{s.icon}</Icon>
                <span>{s.label}</span>
              </button>
            </li>
          )
        })}
      </ul>
    </nav>
  )
}
