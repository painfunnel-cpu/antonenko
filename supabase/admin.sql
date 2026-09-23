update public.profiles
set role = 'admin', updated_at = now()
where id = (
  select id
  from auth.users
  where lower(email) = lower('antonenko@example.com')
);

-- Проверка назначения роли:
select p.id, u.email, p.full_name, p.role
from public.profiles p
join auth.users u on u.id = p.id
where lower(u.email) = lower('antonenko@example.com');

