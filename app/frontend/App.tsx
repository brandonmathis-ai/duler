import { useEffect, useState } from 'react'
import './App.css'

interface HelloData {
  hello: string
}

interface ApiResponse {
  data: HelloData
}

function App() {
  const [response, setResponse] = useState<ApiResponse | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    fetch('/api/hello')
      .then((res) => {
        if (!res.ok) {
          throw new Error(`HTTP error! status: ${res.status}`)
        }
        return res.json()
      })
      .then((data: HelloData | { data: HelloData }) => {
        const helloData = 'data' in data && data.data ? data.data : (data as HelloData)
        setResponse({ data: helloData })
        setLoading(false)
      })
      .catch((err) => {
        setError(err instanceof Error ? err.message : 'Unknown error')
        setLoading(false)
      })
  }, [])

  return (
    <main className="hello-container">
      {response && <h1>Hello {response.data.hello}</h1>}
    </main>
  )
}

export default App

