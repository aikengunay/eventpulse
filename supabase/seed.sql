-- EventPulse seed — local dev only. Demo password: EventPulseDemo1!

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
  owner_id uuid := '10000000-0000-0000-0000-000000000001';
  staff_id uuid := '10000000-0000-0000-0000-000000000002';
  demo_password text := 'EventPulseDemo1!';
BEGIN
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change,
    email_change_token_current,
    reauthentication_token,
    phone_change,
    phone_change_token,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    owner_id,
    'authenticated',
    'authenticated',
    'owner@eventpulse.demo',
    crypt(demo_password, gen_salt('bf')),
    now(),
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '{"provider":"email","providers":["email"]}',
    '{"name":"Owner"}',
    now(),
    now()
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change,
    email_change_token_current,
    reauthentication_token,
    phone_change,
    phone_change_token,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    staff_id,
    'authenticated',
    'authenticated',
    'staff@eventpulse.demo',
    crypt(demo_password, gen_salt('bf')),
    now(),
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '{"provider":"email","providers":["email"]}',
    '{"name":"Staff"}',
    now(),
    now()
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  )
  VALUES
    (
      owner_id,
      owner_id,
      jsonb_build_object('sub', owner_id::text, 'email', 'owner@eventpulse.demo'),
      'email',
      'owner@eventpulse.demo',
      now(),
      now(),
      now()
    ),
    (
      staff_id,
      staff_id,
      jsonb_build_object('sub', staff_id::text, 'email', 'staff@eventpulse.demo'),
      'email',
      'staff@eventpulse.demo',
      now(),
      now(),
      now()
    )
  ON CONFLICT DO NOTHING;
END $$;

INSERT INTO orgs (id, name, plan)
VALUES ('20000000-0000-0000-0000-000000000001', 'EventPulse Demo Org', 'pro')
ON CONFLICT (id) DO NOTHING;

INSERT INTO venues (id, org_id, name, city, capacity)
VALUES
  (
    '30000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'Manila Grand Hall',
    'Manila',
    500
  ),
  (
    '30000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000001',
    'Cebu Convention Center',
    'Cebu',
    350
  ),
  (
    '30000000-0000-0000-0000-000000000003',
    '20000000-0000-0000-0000-000000000001',
    'Davao Event Arena',
    'Davao',
    400
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO memberships (id, user_id, org_id, role, venue_id)
VALUES
  (
    '40000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'owner',
    NULL
  ),
  (
    '40000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000001',
    'staff',
    '30000000-0000-0000-0000-000000000001'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO events (id, org_id, venue_id, name, starts_at, ends_at, status)
VALUES
  (
    '50000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    'Tech Summit Manila',
    now() - interval '55 days',
    now() - interval '55 days' + interval '8 hours',
    'done'
  ),
  (
    '50000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002',
    'Cebu Startup Meetup',
    now() - interval '45 days',
    now() - interval '45 days' + interval '6 hours',
    'done'
  ),
  (
    '50000000-0000-0000-0000-000000000003',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000003',
    'Davao Business Forum',
    now() - interval '35 days',
    now() - interval '35 days' + interval '7 hours',
    'done'
  ),
  (
    '50000000-0000-0000-0000-000000000004',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    'Manila Music Festival',
    now() - interval '25 days',
    now() - interval '25 days' + interval '10 hours',
    'done'
  ),
  (
    '50000000-0000-0000-0000-000000000005',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002',
    'Cebu Food Expo',
    now() - interval '15 days',
    now() - interval '15 days' + interval '5 hours',
    'done'
  ),
  (
    '50000000-0000-0000-0000-000000000006',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000003',
    'Davao Tech Fair',
    now() - interval '5 days',
    now() - interval '5 days' + interval '6 hours',
    'done'
  ),
  (
    '50000000-0000-0000-0000-000000000007',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    'Manila AI Conference',
    now() + interval '3 days',
    now() + interval '3 days' + interval '8 hours',
    'published'
  ),
  (
    '50000000-0000-0000-0000-000000000008',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002',
    'Cebu Marketing Summit',
    now() + interval '5 days',
    now() + interval '5 days' + interval '6 hours',
    'published'
  ),
  (
    '50000000-0000-0000-0000-000000000009',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000003',
    'Davao Wellness Expo',
    now() + interval '7 days',
    now() + interval '7 days' + interval '9 hours',
    'published'
  ),
  (
    '50000000-0000-0000-0000-000000000010',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    'Manila Startup Pitch Night',
    now() + interval '9 days',
    now() + interval '9 days' + interval '4 hours',
    'published'
  ),
  (
    '50000000-0000-0000-0000-000000000011',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002',
    'Cebu Design Conference',
    now() + interval '11 days',
    now() + interval '11 days' + interval '7 hours',
    'draft'
  ),
  (
    '50000000-0000-0000-0000-000000000012',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000003',
    'Davao Real Estate Expo',
    now() + interval '13 days',
    now() + interval '13 days' + interval '8 hours',
    'draft'
  )
ON CONFLICT (id) DO NOTHING;

DO $$
DECLARE
  event_record RECORD;
  guest_index int := 0;
  guest_status_val guest_status;
  guest_email text;
  guest_name text;
  first_names text[] := ARRAY[
    'Juan', 'Maria', 'Jose', 'Ana', 'Carlos', 'Elena', 'Ramon', 'Sofia', 'Miguel', 'Carmen',
    'Antonio', 'Isabel', 'Francisco', 'Lucia', 'Diego', 'Teresa', 'Pablo', 'Rosa', 'Javier', 'Marta',
    'Luis', 'Pilar', 'Andres', 'Gloria', 'Rafael', 'Nina', 'Enrique', 'Lorna', 'Jaime', 'Bianca'
  ];
  last_names text[] := ARRAY[
    'Santos', 'Reyes', 'Cruz', 'Bautista', 'Ocampo', 'Garcia', 'Mendoza', 'Torres', 'Flores', 'Ramos',
    'Aquino', 'Castro', 'Diaz', 'Rivera', 'Santiago', 'Villanueva', 'Navarro', 'Salazar', 'Manalo', 'Dela Rosa',
    'Mercado', 'Padilla', 'Aguilar', 'Soriano', 'Cordero', 'Fernandez', 'Domingo', 'Alonzo', 'Pascual', 'Marquez'
  ];
  domain_names text[] := ARRAY['gmail.com', 'yahoo.com', 'outlook.com', 'proton.me', 'icloud.com'];
BEGIN
  FOR event_record IN
    SELECT id, org_id, venue_id, starts_at FROM events
  LOOP
    FOR i IN 1..25 LOOP
      guest_index := guest_index + 1;
      guest_name :=
        first_names[((guest_index - 1) % 30) + 1] || ' ' ||
        last_names[((guest_index * 7) % 30) + 1];
      guest_email :=
        lower(replace(guest_name, ' ', '.')) || guest_index::text || '@' ||
        domain_names[((guest_index + 2) % 5) + 1];

      IF event_record.starts_at < now() THEN
        IF guest_index % 3 = 0 THEN
          guest_status_val := 'no_show';
        ELSE
          guest_status_val := 'checked_in';
        END IF;
      ELSE
        guest_status_val := 'pending';
      END IF;

      INSERT INTO guests (
        event_id,
        org_id,
        venue_id,
        full_name,
        email,
        status,
        checked_in_at,
        checked_in_by
      )
      VALUES (
        event_record.id,
        event_record.org_id,
        event_record.venue_id,
        guest_name,
        guest_email,
        guest_status_val,
        CASE
          WHEN guest_status_val = 'checked_in'
            THEN event_record.starts_at + (random() * interval '2 hours')
          ELSE NULL
        END,
        CASE
          WHEN guest_status_val = 'checked_in'
            THEN '10000000-0000-0000-0000-000000000001'::uuid
          ELSE NULL
        END
      );
    END LOOP;
  END LOOP;
END $$;
