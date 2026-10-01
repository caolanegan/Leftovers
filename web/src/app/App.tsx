import { Navigate, Route, Routes } from 'react-router'
import { Layout } from './Layout'
import { PlanPage } from '../features/plan/PlanPage'
import { MealsPage } from '../features/meals/MealsPage'
import { IngredientsPage } from '../features/ingredients/IngredientsPage'
import { ShoppingPage } from '../features/shopping/ShoppingPage'
import { SettingsPage } from '../features/settings/SettingsPage'
import { SharingPage } from '../features/settings/SharingPage'
import { NotFoundPage } from './NotFoundPage'

export function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<Navigate to="/plan" replace />} />
        <Route path="plan" element={<PlanPage />} />
        <Route path="meals" element={<MealsPage />} />
        <Route path="ingredients" element={<IngredientsPage />} />
        <Route path="shopping" element={<ShoppingPage />} />
        <Route path="settings" element={<SettingsPage />} />
        <Route path="settings/sharing" element={<SharingPage />} />
        <Route path="*" element={<NotFoundPage />} />
      </Route>
    </Routes>
  )
}
