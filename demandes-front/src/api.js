import keycloak from './keycloak.js'

const API = 'http://localhost:8081'

export async function appelerApi(path, options = {}) {
  await keycloak.updateToken(30)

  const response = await fetch(API + path, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${keycloak.token}`,
      ...options.headers,
    },
  })

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`)
  }

  return response.json()
}
