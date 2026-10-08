-- EventPulse Phase 1b - Initial Schema

CREATE TYPE org_plan AS ENUM ('free', 'pro');
CREATE TYPE membership_role AS ENUM ('owner', 'staff');
CREATE TYPE event_status AS ENUM ('draft', 'published', 'done');
CREATE TYPE guest_status AS ENUM ('pending', 'checked_in', 'no_show');

CREATE TABLE orgs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  plan org_plan NOT NULL DEFAULT 'free',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE venues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES orgs ON DELETE CASCADE,
  name text NOT NULL,
  city text,
  capacity int
);

CREATE TABLE memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  org_id uuid NOT NULL REFERENCES orgs ON DELETE CASCADE,
  role membership_role NOT NULL,
  venue_id uuid REFERENCES venues ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES orgs ON DELETE CASCADE,
  venue_id uuid NOT NULL REFERENCES venues ON DELETE CASCADE,
  name text NOT NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  status event_status NOT NULL DEFAULT 'draft',
  poster_path text
);

CREATE TABLE guests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events ON DELETE CASCADE,
  org_id uuid NOT NULL REFERENCES orgs ON DELETE CASCADE,
  venue_id uuid NOT NULL REFERENCES venues ON DELETE CASCADE,
  full_name text NOT NULL,
  email text,
  status guest_status NOT NULL DEFAULT 'pending',
  checked_in_at timestamptz,
  checked_in_by uuid REFERENCES auth.users
);

CREATE OR REPLACE FUNCTION set_guest_org_venue()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  SELECT org_id, venue_id
  INTO NEW.org_id, NEW.venue_id
  FROM events
  WHERE id = NEW.event_id;

  IF NEW.org_id IS NULL OR NEW.venue_id IS NULL THEN
    RAISE EXCEPTION 'Event % not found for guest denormalization', NEW.event_id;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_set_guest_org_venue
  BEFORE INSERT OR UPDATE OF event_id ON guests
  FOR EACH ROW
  EXECUTE FUNCTION set_guest_org_venue();

CREATE OR REPLACE FUNCTION my_org_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT org_id FROM memberships WHERE user_id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION is_org_owner(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM memberships
    WHERE user_id = auth.uid()
      AND org_id = p_org_id
      AND role = 'owner'
  )
$$;

CREATE OR REPLACE FUNCTION my_staff_venue_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT venue_id
  FROM memberships
  WHERE user_id = auth.uid()
    AND role = 'staff'
    AND venue_id IS NOT NULL
$$;

ALTER TABLE orgs ENABLE ROW LEVEL SECURITY;
ALTER TABLE venues ENABLE ROW LEVEL SECURITY;
ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE guests ENABLE ROW LEVEL SECURITY;

CREATE POLICY orgs_select ON orgs
  FOR SELECT TO authenticated
  USING (id IN (SELECT my_org_ids()));

CREATE POLICY venues_select ON venues
  FOR SELECT TO authenticated
  USING (
    org_id IN (SELECT my_org_ids())
    AND (
      is_org_owner(org_id)
      OR id IN (SELECT my_staff_venue_ids())
    )
  );

CREATE POLICY venues_insert ON venues
  FOR INSERT TO authenticated
  WITH CHECK (is_org_owner(org_id));

CREATE POLICY venues_update ON venues
  FOR UPDATE TO authenticated
  USING (is_org_owner(org_id))
  WITH CHECK (is_org_owner(org_id));

CREATE POLICY venues_delete ON venues
  FOR DELETE TO authenticated
  USING (is_org_owner(org_id));

CREATE POLICY memberships_select ON memberships
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR is_org_owner(org_id));

CREATE POLICY memberships_insert ON memberships
  FOR INSERT TO authenticated
  WITH CHECK (is_org_owner(org_id));

CREATE POLICY memberships_update ON memberships
  FOR UPDATE TO authenticated
  USING (is_org_owner(org_id))
  WITH CHECK (is_org_owner(org_id));

CREATE POLICY memberships_delete ON memberships
  FOR DELETE TO authenticated
  USING (is_org_owner(org_id));

CREATE POLICY events_select ON events
  FOR SELECT TO authenticated
  USING (
    org_id IN (SELECT my_org_ids())
    AND (
      is_org_owner(org_id)
      OR venue_id IN (SELECT my_staff_venue_ids())
    )
  );

CREATE POLICY events_insert ON events
  FOR INSERT TO authenticated
  WITH CHECK (is_org_owner(org_id));

CREATE POLICY events_update ON events
  FOR UPDATE TO authenticated
  USING (is_org_owner(org_id))
  WITH CHECK (is_org_owner(org_id));

CREATE POLICY events_delete ON events
  FOR DELETE TO authenticated
  USING (is_org_owner(org_id));

CREATE POLICY guests_select ON guests
  FOR SELECT TO authenticated
  USING (
    org_id IN (SELECT my_org_ids())
    AND (
      is_org_owner(org_id)
      OR venue_id IN (SELECT my_staff_venue_ids())
    )
  );

CREATE POLICY guests_insert ON guests
  FOR INSERT TO authenticated
  WITH CHECK (is_org_owner(org_id));

CREATE POLICY guests_update ON guests
  FOR UPDATE TO authenticated
  USING (
    is_org_owner(org_id)
    OR venue_id IN (SELECT my_staff_venue_ids())
  )
  WITH CHECK (
    is_org_owner(org_id)
    OR venue_id IN (SELECT my_staff_venue_ids())
  );

CREATE POLICY guests_delete ON guests
  FOR DELETE TO authenticated
  USING (is_org_owner(org_id));

CREATE OR REPLACE FUNCTION dashboard_stats(
  p_from timestamptz,
  p_to timestamptz,
  p_venue_id uuid DEFAULT NULL,
  p_status guest_status DEFAULT NULL
)
RETURNS json
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  WITH filtered_guests AS (
    SELECT g.*
    FROM guests g
    JOIN events e ON e.id = g.event_id
    WHERE e.starts_at >= p_from
      AND e.starts_at <= p_to
      AND (p_venue_id IS NULL OR g.venue_id = p_venue_id)
      AND (p_status IS NULL OR g.status = p_status)
  ),
  counts AS (
    SELECT
      COUNT(*) FILTER (WHERE status = 'checked_in') AS total_checked_in,
      COUNT(*) FILTER (WHERE status = 'pending') AS total_pending,
      COUNT(*) FILTER (WHERE status = 'no_show') AS total_no_show,
      COUNT(*) AS filtered_count
    FROM filtered_guests
  ),
  series AS (
    SELECT
      to_char(date_trunc('day', checked_in_at), 'YYYY-MM-DD') AS day,
      COUNT(*)::int AS count
    FROM filtered_guests
    WHERE status = 'checked_in'
      AND checked_in_at IS NOT NULL
    GROUP BY date_trunc('day', checked_in_at)
    ORDER BY date_trunc('day', checked_in_at)
  )
  SELECT json_build_object(
    'total_checked_in', COALESCE((SELECT total_checked_in FROM counts), 0),
    'total_pending', COALESCE((SELECT total_pending FROM counts), 0),
    'total_no_show', COALESCE((SELECT total_no_show FROM counts), 0),
    'filtered_count', COALESCE((SELECT filtered_count FROM counts), 0),
    'series', COALESCE((SELECT json_agg(row_to_json(series)) FROM series), '[]'::json)
  )
$$;

CREATE OR REPLACE FUNCTION reset_demo()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  TRUNCATE guests, events, venues, memberships, orgs CASCADE;
END;
$$;

GRANT EXECUTE ON FUNCTION my_org_ids() TO authenticated;
GRANT EXECUTE ON FUNCTION is_org_owner(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION my_staff_venue_ids() TO authenticated;
GRANT EXECUTE ON FUNCTION dashboard_stats(timestamptz, timestamptz, uuid, guest_status) TO authenticated;
GRANT EXECUTE ON FUNCTION reset_demo() TO authenticated;
