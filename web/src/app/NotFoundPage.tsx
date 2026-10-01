import { Link } from 'react-router'
import { Screen } from '../components/Screen'

export function NotFoundPage() {
  return (
    <Screen title="Page not found">
      <Link to="/plan" className="font-medium text-accent underline dark:text-accent-dark">
        Back to the plan
      </Link>
    </Screen>
  )
}
