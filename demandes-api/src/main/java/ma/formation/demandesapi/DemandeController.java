package ma.formation.demandesapi;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
public class DemandeController {

    public record Demande(Long id, String owner, String objet, String statut) {
    }

    public record NouvelleDemande(String objet) {
    }

    public record StatutDemande(String statut) {
    }

    public record Profil(String identifiant, String nomUtilisateur) {
    }

    private final AtomicLong sequence = new AtomicLong(0);
    private final List<Demande> demandes = new CopyOnWriteArrayList<>();

    @GetMapping("/api/public")
    public Map<String, String> publicApi() {
        return Map.of("message", "API publique accessible");
    }

    @GetMapping("/api/profil")
    public Profil profil(@AuthenticationPrincipal Jwt jwt) {
        return new Profil(jwt.getSubject(), jwt.getClaimAsString("preferred_username"));
    }

    @GetMapping("/api/demandes")
    public List<Demande> mesDemandes(@AuthenticationPrincipal Jwt jwt) {
        return demandes.stream()
                .filter(demande -> demande.owner().equals(jwt.getSubject()))
                .toList();
    }

    @PostMapping("/api/demandes")
    public Demande creer(@AuthenticationPrincipal Jwt jwt,
            @RequestBody(required = false) NouvelleDemande nouvelle) {
        if (nouvelle == null || nouvelle.objet() == null || nouvelle.objet().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Objet obligatoire");
        }

        Demande demande = new Demande(
                sequence.incrementAndGet(),
                jwt.getSubject(),
                nouvelle.objet().trim(),
                "EN_ATTENTE");
        demandes.add(demande);
        return demande;
    }

    @GetMapping("/api/admin/demandes")
    public List<Demande> toutesLesDemandes() {
        return List.copyOf(demandes);
    }

    @PatchMapping("/api/admin/demandes/{id}")
    public Demande changerStatut(@PathVariable Long id,
            @RequestBody(required = false) StatutDemande body) {
        if (body == null || !List.of("EN_ATTENTE", "VALIDEE", "REFUSEE").contains(body.statut())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Statut invalide");
        }

        for (Demande demande : new ArrayList<>(demandes)) {
            if (demande.id().equals(id)) {
                Demande modifiee = new Demande(demande.id(), demande.owner(), demande.objet(), body.statut());
                demandes.remove(demande);
                demandes.add(modifiee);
                return modifiee;
            }
        }

        throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Demande introuvable");
    }
}
