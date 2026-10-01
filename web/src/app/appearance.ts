export type Appearance = 'system' | 'light' | 'dark'

const KEY = 'leftovers.appearance'

export function resolveDark(setting: Appearance, systemPrefersDark: boolean): boolean {
  if (setting === 'dark') return true
  if (setting === 'light') return false
  return systemPrefersDark
}

export function parseAppearance(value: string | null): Appearance {
  return value === 'light' || value === 'dark' ? value : 'system'
}

export function getAppearance(): Appearance {
  try {
    return parseAppearance(localStorage.getItem(KEY))
  } catch {
    return 'system'
  }
}

export function applyAppearance(setting: Appearance): void {
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
  document.documentElement.classList.toggle('dark', resolveDark(setting, prefersDark))
}

export function setAppearance(setting: Appearance): void {
  try {
    if (setting === 'system') localStorage.removeItem(KEY)
    else localStorage.setItem(KEY, setting)
  } catch {
    // Storage can be blocked (private windows); the setting then lasts for this visit only.
  }
  applyAppearance(setting)
}

export function watchSystemAppearance(): void {
  applyAppearance(getAppearance())
  window
    .matchMedia('(prefers-color-scheme: dark)')
    .addEventListener('change', () => applyAppearance(getAppearance()))
}
