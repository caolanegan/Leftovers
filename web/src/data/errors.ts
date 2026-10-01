/** Errors the UI can show, mapped from the codes the SQL functions raise. */
export type HouseholdErrorCode = 'invite_invalid' | 'already_in_household' | 'not_signed_in' | 'unknown'

export class HouseholdError extends Error {
  readonly code: HouseholdErrorCode
  constructor(code: HouseholdErrorCode, message: string) {
    super(message)
    this.name = 'HouseholdError'
    this.code = code
  }
}

export function toHouseholdError(error: { message: string }): HouseholdError {
  const message = error.message
  if (message.includes('invite_invalid')) {
    return new HouseholdError('invite_invalid', 'This invite link has already been used or isn’t valid.')
  }
  if (message.includes('already_in_household')) {
    return new HouseholdError('already_in_household', 'You’re already in a household.')
  }
  if (message.includes('not_signed_in')) {
    return new HouseholdError('not_signed_in', 'Please sign in first.')
  }
  return new HouseholdError('unknown', 'Something went wrong. Please try again.')
}
