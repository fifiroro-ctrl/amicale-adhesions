-- =====================================================================
-- Amicale de la Musique des Gardiens de la Paix — base de données
-- À exécuter une seule fois dans Supabase : SQL Editor > New query > Run
-- =====================================================================

-- ---------- Profils (rôles) ----------
create table if not exists public.profils (
  id uuid primary key references auth.users(id) on delete cascade,
  nom text not null,
  initiales text not null check (initiales ~ '^[A-Z]{2,4}$'),
  role text not null check (role in ('admin','caissier'))
);

create or replace function public.mon_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.profils where id = auth.uid()
$$;
create or replace function public.est_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'admin' from public.profils where id = auth.uid()), false)
$$;
create or replace function public.est_equipe() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profils where id = auth.uid())
$$;

-- ---------- Réglages ----------
create table if not exists public.config (
  id int primary key default 1 check (id = 1),
  data jsonb not null default '{}'::jsonb
);

-- ---------- Adhérents ----------
create table if not exists public.membres (
  id text primary key,
  nom text not null,
  prenom text not null,
  categorie text default '',
  service text default '',
  instrument text default '',
  email text default '',
  tel text default '',
  actif boolean not null default true,
  potentiel boolean not null default false,
  "montantPerso" numeric,
  source text,
  "derniereRelance" date,
  cree timestamptz not null default now(),
  modifie timestamptz,
  "creePar" uuid default auth.uid()
);

-- ---------- Mandats de prélèvement (IBAN) : réservé à l'administrateur ----------
create table if not exists public.mandats (
  "membreId" text primary key references public.membres(id) on delete cascade,
  actif boolean not null default false,
  titulaire text,
  iban text,
  bic text,
  rum text,
  "dateSignature" date,
  sequence text default 'FRST' check (sequence in ('FRST','RCUR')),
  "ribPath" text,
  "ribNom" text
);

-- ---------- Encaissements ----------
create table if not exists public.paiements (
  id text primary key,
  "membreId" text references public.membres(id) on delete set null,
  "nomAffiche" text,
  saison text not null check (saison ~ '^\d{4}$' and saison::int >= 2026),
  montant numeric not null check (montant > 0),
  cotis numeric,
  mode text not null check (mode in ('especes','sumup','helloasso','cheque','virement','prelevement')),
  date date not null check (date >= date '2026-01-01'),
  ref text default '',
  note text default '',
  "recuNum" text unique,
  compta date,
  "encaissePar" uuid default auth.uid() references auth.users(id),
  annule boolean not null default false,
  "annulePar" uuid references auth.users(id),
  "annuleLe" timestamptz,
  "annuleMotif" text,
  signalement text,
  "signalementLe" timestamptz,
  "signalementTraite" boolean not null default false,
  "remisLe" date,
  cree timestamptz not null default now()
);

-- Numéro d'accusé de réception (espèces) propre à chaque personne : R2026-PR-0001
create or replace function public.numero_recu() returns trigger
language plpgsql security definer set search_path = public as $$
declare ini text; n int;
begin
  if new.mode = 'especes' and new."recuNum" is null then
    select initiales into ini from public.profils where id = coalesce(new."encaissePar", auth.uid());
    ini := coalesce(ini, 'XX');
    perform pg_advisory_xact_lock(hashtext('recu' || ini || extract(year from new.date)::text));
    select coalesce(max(split_part("recuNum", '-', 3)::int), 0) + 1 into n
      from public.paiements
      where "recuNum" like 'R' || extract(year from new.date)::text || '-' || ini || '-%';
    new."recuNum" := 'R' || extract(year from new.date)::text || '-' || ini || '-' || lpad(n::text, 4, '0');
  end if;
  return new;
end $$;
drop trigger if exists t_numero_recu on public.paiements;
create trigger t_numero_recu before insert on public.paiements
  for each row execute function public.numero_recu();

-- Un adhérent potentiel qui paie devient membre
create or replace function public.potentiel_devient_membre() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new."membreId" is not null and not new.annule then
    update public.membres set potentiel = false where id = new."membreId" and potentiel;
  end if;
  return new;
end $$;
drop trigger if exists t_potentiel on public.paiements;
create trigger t_potentiel after insert on public.paiements
  for each row execute function public.potentiel_devient_membre();

-- Un caissier peut signaler une erreur sur ses propres encaissements, rien de plus
create or replace function public.signaler_erreur(p_id text, p_texte text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.est_equipe() then raise exception 'non autorisé'; end if;
  update public.paiements
     set signalement = left(p_texte, 500), "signalementLe" = now(), "signalementTraite" = false
   where id = p_id and ("encaissePar" = auth.uid() or public.est_admin()) and not annule;
  if not found then raise exception 'encaissement introuvable'; end if;
end $$;

-- ---------- Événements ----------
create table if not exists public.evenements (
  id text primary key,
  titre text not null,
  date date not null,
  heure text,
  lieu text,
  places numeric,
  description text
);
create table if not exists public.inscriptions (
  "evenementId" text references public.evenements(id) on delete cascade,
  "membreId" text references public.membres(id) on delete cascade,
  primary key ("evenementId", "membreId")
);

-- ---------- Activité (réveil automatique) ----------
create or replace function public.reveil() returns text
language sql stable as $$ select 'ok'::text $$;
grant execute on function public.reveil() to anon, authenticated;

-- =====================================================================
-- Droits (Row Level Security)
-- =====================================================================
alter table public.profils     enable row level security;
alter table public.config      enable row level security;
alter table public.membres     enable row level security;
alter table public.mandats     enable row level security;
alter table public.paiements   enable row level security;
alter table public.evenements  enable row level security;
alter table public.inscriptions enable row level security;

-- Profils : l'équipe voit les noms (pour « encaissé par »), seul l'admin modifie
drop policy if exists p_profils_lire on public.profils;
create policy p_profils_lire on public.profils for select to authenticated using (public.est_equipe());
drop policy if exists p_profils_admin on public.profils;
create policy p_profils_admin on public.profils for all to authenticated using (public.est_admin()) with check (public.est_admin());

-- Réglages : l'équipe lit (montant, en-tête des reçus), l'admin modifie
drop policy if exists p_config_lire on public.config;
create policy p_config_lire on public.config for select to authenticated using (public.est_equipe());
drop policy if exists p_config_admin on public.config;
create policy p_config_admin on public.config for all to authenticated using (public.est_admin()) with check (public.est_admin());

-- Adhérents : l'équipe lit et crée ; seul l'admin modifie et supprime
drop policy if exists p_membres_lire on public.membres;
create policy p_membres_lire on public.membres for select to authenticated using (public.est_equipe());
drop policy if exists p_membres_creer on public.membres;
create policy p_membres_creer on public.membres for insert to authenticated with check (public.est_equipe());
drop policy if exists p_membres_modif on public.membres;
create policy p_membres_modif on public.membres for update to authenticated using (public.est_admin()) with check (public.est_admin());
drop policy if exists p_membres_suppr on public.membres;
create policy p_membres_suppr on public.membres for delete to authenticated using (public.est_admin());

-- Mandats / IBAN : administrateur uniquement
drop policy if exists p_mandats_admin on public.mandats;
create policy p_mandats_admin on public.mandats for all to authenticated using (public.est_admin()) with check (public.est_admin());

-- Encaissements : l'équipe lit ; un caissier crée uniquement à son nom, jamais annulé ni basculé ;
-- seul l'admin modifie (annulation, bascule compta, espèces remises) ; personne ne supprime
drop policy if exists p_paiements_lire on public.paiements;
create policy p_paiements_lire on public.paiements for select to authenticated using (public.est_equipe());
drop policy if exists p_paiements_creer on public.paiements;
create policy p_paiements_creer on public.paiements for insert to authenticated with check (
  public.est_admin()
  or (public.est_equipe() and "encaissePar" = auth.uid() and not annule and compta is null
      and "remisLe" is null and mode in ('especes','sumup','helloasso','cheque','virement'))
);
drop policy if exists p_paiements_modif on public.paiements;
create policy p_paiements_modif on public.paiements for update to authenticated using (public.est_admin()) with check (public.est_admin());

-- Événements et inscriptions : administrateur uniquement
drop policy if exists p_evt_admin on public.evenements;
create policy p_evt_admin on public.evenements for all to authenticated using (public.est_admin()) with check (public.est_admin());
drop policy if exists p_insc_admin on public.inscriptions;
create policy p_insc_admin on public.inscriptions for all to authenticated using (public.est_admin()) with check (public.est_admin());

-- ---------- Stockage privé des RIB ----------
insert into storage.buckets (id, name, public) values ('rib', 'rib', false) on conflict (id) do nothing;
drop policy if exists p_rib_admin on storage.objects;
create policy p_rib_admin on storage.objects for all to authenticated
  using (bucket_id = 'rib' and public.est_admin()) with check (bucket_id = 'rib' and public.est_admin());

-- ---------- Mises à jour en direct entre les appareils ----------
do $$ begin
  begin alter publication supabase_realtime add table public.membres;    exception when others then null; end;
  begin alter publication supabase_realtime add table public.paiements;  exception when others then null; end;
  begin alter publication supabase_realtime add table public.evenements; exception when others then null; end;
  begin alter publication supabase_realtime add table public.inscriptions; exception when others then null; end;
end $$;

insert into public.config (id, data) values (1, '{"montant":10,"sigle":"AMGP"}'::jsonb) on conflict (id) do nothing;
