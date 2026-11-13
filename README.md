# Amicale — Adhésions

Application web de gestion des adhésions de l'Amicale de la Musique des Gardiens de la Paix :
adhérents, cotisations (espèces, SumUp, HelloAsso, chèque, virement, prélèvement SEPA),
accusés de réception, relances, caisses, événements et export comptable.

- **Affichage** : GitHub Pages (ce dépôt, sans aucune donnée).
- **Données et comptes** : Supabase (base privée, accès réservé au bureau).

## Rôles

| | Administrateur | Caissier |
|---|---|---|
| Encaisser, créer un adhérent, accusé de réception | ✓ | ✓ |
| Signaler une erreur sur ses encaissements | ✓ | ✓ |
| Annuler / modifier un encaissement | ✓ | |
| Prélèvements, RIB, relances, compta, réglages, événements | ✓ | |

Les droits sont appliqués par la base de données elle-même (fichier `supabase/schema.sql`).

## Mise en place

1. Supabase : créer un projet (région Europe), exécuter `supabase/schema.sql` dans *SQL Editor*.
2. *Authentication > Sign In / Providers* : désactiver « Allow new users to sign up ».
3. *Authentication > URL Configuration* : mettre l'adresse GitHub Pages dans *Site URL*.
4. Créer les comptes (*Authentication > Users > Add user*), puis exécuter `supabase/acces.sql`.
5. Compléter `config.js` avec l'URL du projet et la clé publique (*Project Settings > API*).
6. GitHub : *Settings > Pages* → déployer depuis la branche `main`, dossier racine.

La tâche `.github/workflows/reveil.yml` interroge la base deux fois par semaine pour éviter
sa mise en veille.
