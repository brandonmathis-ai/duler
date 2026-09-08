import { useQuery } from '@tanstack/react-query'
import './App.css'

interface HelloData {
  hello: string
}

interface ApiResponse {
  data: HelloData
}

async function fetchHello(): Promise<ApiResponse> {
  const res = await fetch('/api/hello')
  if (!res.ok) {
    throw new Error(`HTTP error! status: ${res.status}`)
  }
  const data: HelloData | { data: HelloData } = await res.json()
  const helloData = 'data' in data && data.data ? data.data : (data as HelloData)
  return { data: helloData }
}

function App() {
  const { data: response, error } = useQuery({
    queryKey: ['hello'],
    queryFn: fetchHello,
  })

  return (
    <main className="hello-container">
      {error && <p className="error-message">{error.message}</p>}
      {response && <h1>Hello {response.data.hello}</h1>}
    </main>
  )
}

export default App

