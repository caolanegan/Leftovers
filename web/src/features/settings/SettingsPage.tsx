import { useState } from 'react'
import { Link } from 'react-router'
import { Screen } from '../../components/Screen'
import { getAppearance, setAppearance, type Appearance } from '../../app/appearance'

const options: { value: Appearance; label: string }[] = [
  { value: 'system', label: 'System' },
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
]

export function SettingsPage() {
  const [appearance, setCurrent] = useState<Appearance>(getAppearance)

  return (
    <Screen title="Settings">
      <fieldset className="mb-6">
        <legend className="mb-2 font-semibold">Appearance</legend>
        <div className="flex gap-2">
          {options.map(({ value, label }) => (
            <label
              key={value}
              className="flex cursor-pointer items-center gap-2 rounded-lg border border-neutral-300 px-3 py-2 has-[:checked]:border-accent has-[:checked]:bg-accent/10 has-[:focus-visible]:outline-3 dark:border-neutral-700"
            >
              <input
                type="radio"
                name="appearance"
                value={value}
                checked={appearance === value}
                onChange={() => {
                  setCurrent(value)
                  setAppearance(value)
                }}
                className="accent-accent"
              />
              {label}
            </label>
          ))}
        </div>
      </fieldset>
      <Link to="/settings/sharing" className="font-medium text-accent underline dark:text-accent-dark">
        Sharing
      </Link>
    </Screen>
  )
}
