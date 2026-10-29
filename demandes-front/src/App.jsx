import { useCallback, useEffect, useMemo, useState } from 'react'
import keycloak from './keycloak.js'
import { appelerApi } from './api.js'
import './App.css'

function App() {
  const [objet, setObjet] = useState('')
  const [mesDemandes, setMesDemandes] = useState([])
  const [toutes, setToutes] = useState([])
  const [profil, setProfil] = useState(null)
  const [message, setMessage] = useState('')
  const [chargement, setChargement] = useState(true)

  const roles = useMemo(
    () => keycloak.tokenParsed?.realm_access?.roles || [],
    [],
  )
  const isAdmin = roles.includes('ADMIN')
  const username = profil?.nomUtilisateur
    || keycloak.tokenParsed?.preferred_username
    || 'Utilisateur'

  const charger = useCallback(async () => {
    setChargement(true)
    try {
      const [profilCourant, demandesUtilisateur] = await Promise.all([
        appelerApi('/api/profil'),
        appelerApi('/api/demandes'),
      ])
      setProfil(profilCourant)
      setMesDemandes(demandesUtilisateur)

      if (isAdmin) {
        setToutes(await appelerApi('/api/admin/demandes'))
      } else {
        setToutes([])
      }
    } catch (error) {
      setMessage(`Erreur : ${error.message}`)
    } finally {
      setChargement(false)
    }
  }, [isAdmin])

  useEffect(() => {
    charger()
  }, [charger])

  async function creer(e) {
    e.preventDefault()
    try {
      await appelerApi('/api/demandes', {
        method: 'POST',
        body: JSON.stringify({ objet }),
      })
      setObjet('')
      setMessage('Demande créée.')
      await charger()
    } catch (error) {
      setMessage(`Erreur : ${error.message}`)
    }
  }

  async function changerStatut(id, statut, confirmation) {
    try {
      await appelerApi(`/api/admin/demandes/${id}`, {
        method: 'PATCH',
        body: JSON.stringify({ statut }),
      })
      setMessage(confirmation)
      await charger()
    } catch (error) {
      setMessage(`Erreur : ${error.message}`)
    }
  }

  function deconnecter() {
    keycloak.logout({ redirectUri: 'http://localhost:5173/' })
  }

  return (
    <main className="app-shell">
      <header className="app-header">
        <div>
          <p className="eyebrow">Atelier OAuth 2.0 / OpenID Connect</p>
          <h1>Gestion des demandes</h1>
          <p className="subtitle">Une API Spring Boot protégée par Keycloak.</p>
        </div>
        <button className="button button-secondary" onClick={deconnecter}>
          Se déconnecter
        </button>
      </header>

      <section className="identity-card" aria-label="Identité connectée">
        <div className="avatar">{username.charAt(0).toUpperCase()}</div>
        <div>
          <p className="muted">Connecté en tant que</p>
          <strong>{username}</strong>
          <p className="roles">Rôles : {roles.join(', ') || 'aucun'}</p>
        </div>
        {profil?.identifiant && (
          <span className="subject">sub : {profil.identifiant}</span>
        )}
      </section>

      <section className="panel">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Nouvelle demande</p>
            <h2>Créer une demande</h2>
          </div>
        </div>
        <form className="request-form" onSubmit={creer}>
          <label htmlFor="objet">Objet de la demande</label>
          <div className="form-row">
            <input
              id="objet"
              value={objet}
              onChange={(e) => setObjet(e.target.value)}
              placeholder="Ex. Accès au laboratoire"
              required
            />
            <button className="button button-primary" type="submit">
              Envoyer
            </button>
          </div>
        </form>
      </section>

      <section className="panel">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Espace personnel</p>
            <h2>Mes demandes</h2>
          </div>
          <span className="count-badge">{mesDemandes.length}</span>
        </div>
        {chargement ? (
          <p className="muted">Chargement des demandes…</p>
        ) : mesDemandes.length === 0 ? (
          <p className="empty-state">Aucune demande pour le moment.</p>
        ) : (
          <ul className="request-list">
            {mesDemandes.map((demande) => (
              <li className="request-item" key={demande.id}>
                <div>
                  <strong>#{demande.id} · {demande.objet}</strong>
                  <span className={`status status-${demande.statut.toLowerCase()}`}>
                    {demande.statut}
                  </span>
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>

      {isAdmin && (
        <section className="panel admin-panel">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Rôle ADMIN</p>
              <h2>Administration · toutes les demandes</h2>
            </div>
            <span className="admin-badge">ADMIN</span>
          </div>
          {toutes.length === 0 ? (
            <p className="empty-state">Aucune demande à traiter.</p>
          ) : (
            <ul className="request-list">
              {toutes.map((demande) => (
                <li className="request-item admin-request" key={demande.id}>
                  <div className="request-details">
                    <strong>#{demande.id} · {demande.objet}</strong>
                    <span className="muted">Propriétaire : {demande.owner}</span>
                    <span className={`status status-${demande.statut.toLowerCase()}`}>
                      {demande.statut}
                    </span>
                  </div>
                  <div className="action-buttons">
                    {demande.statut !== 'VALIDEE' && (
                      <button
                        className="button button-success"
                        onClick={() => changerStatut(demande.id, 'VALIDEE', 'Demande validée.')}
                      >
                        Valider
                      </button>
                    )}
                    {demande.statut !== 'REFUSEE' && (
                      <button
                        className="button button-danger"
                        onClick={() => changerStatut(demande.id, 'REFUSEE', 'Demande refusée.')}
                      >
                        Refuser
                      </button>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>
      )}

      <p className="message" role="status">{message}</p>
    </main>
  )
}

export default App
