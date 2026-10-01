import type { ReactNode } from 'react'

export function Screen({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <section>
      <h1 className="mb-4 text-3xl font-bold">{title}</h1>
      {children ?? <p className="text-neutral-600 dark:text-neutral-400">Nothing here yet.</p>}
    </section>
  )
}
