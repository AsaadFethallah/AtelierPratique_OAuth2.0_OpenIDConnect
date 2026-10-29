package ma.formation.demandesapi;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.authentication.AuthenticationServiceException;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class DemandesApiApplicationTests {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private JwtDecoder jwtDecoder;

	@Test
    void apiPubliqueEstAccessibleSansToken() throws Exception {
        mockMvc.perform(get("/api/public"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("API publique accessible"));
    }

    @Test
    void apiProtegeeRefuseeSansToken() throws Exception {
        mockMvc.perform(get("/api/demandes"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void userNePeutPasAccederAuxDemandesAdmin() throws Exception {
        mockMvc.perform(get("/api/admin/demandes").with(jwtUtilisateur("USER")))
                .andExpect(status().isForbidden());
    }

    @Test
    void adminPeutAccederAuxDemandesAdmin() throws Exception {
        mockMvc.perform(get("/api/admin/demandes").with(jwtUtilisateur("ADMIN")))
                .andExpect(status().isOk());
    }

    @Test
    void userPeutCreerUneDemandeEtLeOwnerVientDuJwt() throws Exception {
        mockMvc.perform(post("/api/demandes")
                        .with(jwtUtilisateur("USER"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"objet\":\"Accès au laboratoire\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.owner").value("sujet-user"))
                .andExpect(jsonPath("$.objet").value("Accès au laboratoire"))
                .andExpect(jsonPath("$.statut").value("EN_ATTENTE"));
    }

    @Test
    void profilRetourneLesClaimsDuJwt() throws Exception {
        mockMvc.perform(get("/api/profil").with(jwtUtilisateur("USER")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.identifiant").value("sujet-user"))
                .andExpect(jsonPath("$.nomUtilisateur").value("alice"));
    }

    @Test
    void tokenInvalideEstRefuse() throws Exception {
        when(jwtDecoder.decode("token-invalide"))
                .thenThrow(new JwtException("JWT invalide"));

        assertThrows(AuthenticationServiceException.class, () -> mockMvc.perform(get("/api/demandes")
                .header("Authorization", "Bearer token-invalide")));
    }

    @Test
    void userNePeutPasModifierViaApiAdmin() throws Exception {
        mockMvc.perform(patch("/api/admin/demandes/999")
                        .with(jwtUtilisateur("USER"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"statut\":\"VALIDEE\"}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void adminPeutModifierLeStatut() throws Exception {
        String demande = mockMvc.perform(post("/api/demandes")
                        .with(jwtUtilisateur("USER"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"objet\":\"Demande à traiter\"}"))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        long id = Long.parseLong(demande.replaceAll(".*\"id\":(\\d+).*", "$1"));
        mockMvc.perform(patch("/api/admin/demandes/{id}", id)
                        .with(jwtUtilisateur("ADMIN"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"statut\":\"REFUSEE\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.statut").value("REFUSEE"));
    }

    private RequestPostProcessor jwtUtilisateur(String role) {
        return jwt()
                .jwt(jwt -> jwt.subject("sujet-user")
                        .claim("preferred_username", "alice")
                        .claim("realm_access", Map.of("roles", List.of(role))))
                .authorities(new SimpleGrantedAuthority("ROLE_" + role));
	}

}
