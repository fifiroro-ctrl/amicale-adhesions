-- =====================================================================
-- Donner l'accès à l'appli (à exécuter APRÈS avoir créé les comptes dans
-- Supabase : Authentication > Users > Add user > Create new user,
-- en cochant « Auto Confirm User »).
-- Remplacez les adresses mail ci-dessous puis cliquez sur Run.
-- =====================================================================
insert into public.profils (id, nom, initiales, role)
select id, 'Philippe Robert', 'PR', 'admin' from auth.users where email = 'MAIL_DE_PHILIPPE'
on conflict (id) do update set nom = excluded.nom, initiales = excluded.initiales, role = excluded.role;

insert into public.profils (id, nom, initiales, role)
select id, 'Patrick Couttet', 'PC', 'caissier' from auth.users where email = 'MAIL_DE_PATRICK'
on conflict (id) do update set nom = excluded.nom, initiales = excluded.initiales, role = excluded.role;

insert into public.profils (id, nom, initiales, role)
select id, 'Cédric Cyprien', 'CC', 'caissier' from auth.users where email = 'MAIL_DE_CEDRIC'
on conflict (id) do update set nom = excluded.nom, initiales = excluded.initiales, role = excluded.role;

-- Vérification : doit afficher les trois personnes
select p.nom, p.role, u.email from public.profils p join auth.users u on u.id = p.id;

-- Retirer un accès : delete from public.profils where id = (select id from auth.users where email = '...');
