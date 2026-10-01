import { beforeAll, describe, expect, it } from 'vitest'
import { admin, createUser, must, seedHousehold, type Seed } from './testkit'

let a: Seed
let b: Seed

beforeAll(async () => {
  a = await seedHousehold(await createUser())
  b = await seedHousehold(await createUser())
})

const FK_VIOLATION = '23503'
const UNIQUE_VIOLATION = '23505'

describe('composite keys keep rows inside one household', () => {
  it('stops a recipe line pointing at another household’s meal or ingredient', async () => {
    const r1 = await admin.from('recipe_ingredient').insert({ household_id: a.householdId, meal_id: b.ids.meal, ingredient_id: a.ids.ingredient })
    expect(r1.error?.code).toBe(FK_VIOLATION)
    const r2 = await admin.from('recipe_ingredient').insert({ household_id: a.householdId, meal_id: a.ids.meal, ingredient_id: b.ids.ingredient })
    expect(r2.error?.code).toBe(FK_VIOLATION)
  })

  it('stops a slot pointing at another household’s week, meal or source slot', async () => {
    const base = { household_id: a.householdId, day_index: 3, meal_type: 'lunch' }
    expect((await admin.from('meal_slot').insert({ ...base, week_plan_id: b.ids.week_plan })).error?.code).toBe(FK_VIOLATION)
    expect((await admin.from('meal_slot').insert({ ...base, week_plan_id: a.ids.week_plan, meal_id: b.ids.meal })).error?.code).toBe(FK_VIOLATION)
    expect((await admin.from('meal_slot').insert({ ...base, week_plan_id: a.ids.week_plan, leftover_of_slot_id: b.ids.slot })).error?.code).toBe(FK_VIOLATION)
  })

  it('stops steps, manual items and item states pointing into another household', async () => {
    expect((await admin.from('instruction_step').insert({ household_id: a.householdId, meal_id: b.ids.meal })).error?.code).toBe(FK_VIOLATION)
    expect((await admin.from('manual_shopping_item').insert({ household_id: a.householdId, week_plan_id: a.ids.week_plan, ingredient_id: b.ids.ingredient })).error?.code).toBe(FK_VIOLATION)
    expect((await admin.from('manual_shopping_item').insert({ household_id: a.householdId, week_plan_id: b.ids.week_plan, ingredient_id: a.ids.ingredient })).error?.code).toBe(FK_VIOLATION)
    expect((await admin.from('shopping_item_state').insert({ household_id: a.householdId, week_plan_id: b.ids.week_plan, item_key: 'z' })).error?.code).toBe(FK_VIOLATION)
  })
})

describe('uniqueness constraints', () => {
  it('rejects duplicates', async () => {
    expect((await admin.from('week_plan').insert({ household_id: a.householdId, week_id: '2026-W38' })).error?.code).toBe(UNIQUE_VIOLATION)
    const ing = must(await admin.from('ingredient').select('normalized_name').eq('id', a.ids.ingredient).single())
    expect((await admin.from('ingredient').insert({ household_id: a.householdId, name: 'dup', normalized_name: ing.normalized_name })).error?.code).toBe(UNIQUE_VIOLATION)
    expect((await admin.from('meal_slot').insert({ household_id: a.householdId, week_plan_id: a.ids.week_plan, day_index: 0, meal_type: 'dinner' })).error?.code).toBe(UNIQUE_VIOLATION)
    expect((await admin.from('shopping_item_state').insert({ household_id: a.householdId, week_plan_id: a.ids.week_plan, item_key: a.ids.ingredient })).error?.code).toBe(UNIQUE_VIOLATION)
    expect((await admin.from('household_settings').insert({ household_id: a.householdId })).error?.code).toBe(UNIQUE_VIOLATION)
  })

  it('allows the same normalised name in different households', async () => {
    const name = `shared-${crypto.randomUUID()}`
    must(await admin.from('ingredient').insert({ household_id: a.householdId, name, normalized_name: name }).select())
    must(await admin.from('ingredient').insert({ household_id: b.householdId, name, normalized_name: name }).select())
  })

  it('rejects values outside the enums', async () => {
    expect((await admin.from('meal_slot').insert({ household_id: a.householdId, week_plan_id: a.ids.week_plan, day_index: 5, meal_type: 'brunch' })).error?.code).toBe('23514')
    expect((await admin.from('meal_slot').insert({ household_id: a.householdId, week_plan_id: a.ids.week_plan, day_index: 7, meal_type: 'dinner' })).error?.code).toBe('23514')
    expect((await admin.from('ingredient').insert({ household_id: a.householdId, normalized_name: 'q', category: 'fruit' })).error?.code).toBe('23514')
    expect((await admin.from('recipe_ingredient').insert({ household_id: a.householdId, meal_id: a.ids.meal, ingredient_id: a.ids.ingredient, unit: 'oz' })).error?.code).toBe('23514')
  })
})

describe('delete rules (SPEC 6.6)', () => {
  it('restricts deleting an ingredient that a recipe uses', async () => {
    expect((await admin.from('ingredient').delete().eq('id', b.ids.ingredient)).error?.code).toBe(FK_VIOLATION)
  })

  it('nulls slot references when a meal or source slot is deleted, keeping the household', async () => {
    const c = await seedHousehold(await createUser())
    must(await admin.from('meal').delete().eq('id', c.ids.meal).select())
    const slots = must(await admin.from('meal_slot').select('*').eq('household_id', c.householdId))
    expect(slots).toHaveLength(2)
    for (const s of slots) {
      expect(s.meal_id).toBeNull()
      expect(s.household_id).toBe(c.householdId)
    }
    expect(must(await admin.from('recipe_ingredient').select('id').eq('household_id', c.householdId))).toHaveLength(0)
    expect(must(await admin.from('instruction_step').select('id').eq('household_id', c.householdId))).toHaveLength(0)
    must(await admin.from('meal_slot').delete().eq('id', c.ids.slot).select())
    const rest = must(await admin.from('meal_slot').select('leftover_of_slot_id').eq('household_id', c.householdId))
    expect(rest).toEqual([{ leftover_of_slot_id: null }])
  })

  it('cascades from a week plan to its slots, manual items and item states', async () => {
    const d = await seedHousehold(await createUser())
    // Manual items hold an ingredient reference (restrict); deleting the week is fine.
    must(await admin.from('week_plan').delete().eq('id', d.ids.week_plan).select())
    for (const t of ['meal_slot', 'manual_shopping_item', 'shopping_item_state']) {
      expect(must(await admin.from(t).select('id').eq('household_id', d.householdId))).toHaveLength(0)
    }
  })
})
