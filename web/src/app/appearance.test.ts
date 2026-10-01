import { describe, expect, it } from 'vitest'
import { parseAppearance, resolveDark } from './appearance'

describe('appearance', () => {
  it('follows the system when set to system', () => {
    expect(resolveDark('system', true)).toBe(true)
    expect(resolveDark('system', false)).toBe(false)
  })
  it('ignores the system when set explicitly', () => {
    expect(resolveDark('dark', false)).toBe(true)
    expect(resolveDark('light', true)).toBe(false)
  })
  it('falls back to system for unknown stored values', () => {
    expect(parseAppearance(null)).toBe('system')
    expect(parseAppearance('purple')).toBe('system')
    expect(parseAppearance('dark')).toBe('dark')
  })
})
