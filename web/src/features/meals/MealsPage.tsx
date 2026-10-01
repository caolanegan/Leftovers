import { Link } from 'react-router'
import { Carrot } from 'lucide-react'
import { Screen } from '../../components/Screen'

export function MealsPage() {
  return (
    <Screen title="Meals">
      <Link
        to="/ingredients"
        className="inline-flex items-center gap-2 font-medium text-accent underline dark:text-accent-dark"
      >
        <Carrot aria-hidden="true" className="size-5" />
        Ingredients
      </Link>
    </Screen>
  )
}
