import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.jsx'
import keycloak from './keycloak.js'
import './index.css'

const root = document.getElementById('root')

keycloak.init({
  onLoad: 'login-required',
  pkceMethod: 'S256',
  checkLoginIframe: false,
}).then(() => {
  createRoot(root).render(
    <StrictMode>
      <App />
    </StrictMode>,
  )
}).catch((error) => {
  console.error('Erreur de connexion Keycloak', error)
  root.textContent = 'Impossible de se connecter au serveur Keycloak.'
})
