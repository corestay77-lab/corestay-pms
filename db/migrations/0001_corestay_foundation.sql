-- CoreStay PMS — Database Foundation
-- Migration: 0001_corestay_foundation
-- PostgreSQL 15+ recommended. This migration creates metadata/security foundations only.
-- It does NOT import, modify, or delete existing browser localStorage data.

BEGIN;

CREATE TABLE IF NOT EXISTS schema_migrations (
  version text PRIMARY KEY,
  applied_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended','closed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  display_name text NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','disabled')),
  identity_provider text NOT NULL DEFAULT 'corestay',
  identity_subject text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT users_email_lowercase CHECK (email = lower(email)),
  CONSTRAINT users_identity_subject_unique UNIQUE (identity_provider, identity_subject)
);
CREATE UNIQUE INDEX users_email_unique_idx ON users (lower(email));

CREATE TABLE hotels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  code text NOT NULL,
  name text NOT NULL,
  legal_name text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','suspended')),
  timezone text NOT NULL DEFAULT 'Asia/Makassar',
  currency char(3) NOT NULL DEFAULT 'IDR',
  country_code char(2) NOT NULL DEFAULT 'ID',
  business_date date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, code)
);

CREATE TABLE tenant_memberships (
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  user_id uuid NOT NULL REFERENCES users(id),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('invited','active','suspended','removed')),
  joined_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, user_id)
);

CREATE TABLE hotel_memberships (
  tenant_id uuid NOT NULL,
  hotel_id uuid NOT NULL,
  user_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('invited','active','suspended','removed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, hotel_id, user_id),
  FOREIGN KEY (tenant_id, hotel_id) REFERENCES hotels(tenant_id, id),
  FOREIGN KEY (tenant_id, user_id) REFERENCES tenant_memberships(tenant_id, user_id)
);

CREATE TABLE permissions (
  key text PRIMARY KEY,
  module text NOT NULL,
  description text NOT NULL
);

CREATE TABLE roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  role_key text NOT NULL,
  name text NOT NULL,
  description text,
  is_system boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, role_key)
);

CREATE TABLE role_permissions (
  tenant_id uuid NOT NULL,
  role_id uuid NOT NULL,
  permission_key text NOT NULL REFERENCES permissions(key),
  PRIMARY KEY (tenant_id, role_id, permission_key),
  FOREIGN KEY (tenant_id, role_id) REFERENCES roles(tenant_id, id)
);

CREATE TABLE hotel_membership_roles (
  tenant_id uuid NOT NULL,
  hotel_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role_id uuid NOT NULL,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  assigned_by uuid REFERENCES users(id),
  PRIMARY KEY (tenant_id, hotel_id, user_id, role_id),
  FOREIGN KEY (tenant_id, hotel_id, user_id)
    REFERENCES hotel_memberships(tenant_id, hotel_id, user_id),
  FOREIGN KEY (tenant_id, role_id) REFERENCES roles(tenant_id, id)
);

CREATE TABLE hotel_settings (
  tenant_id uuid NOT NULL,
  hotel_id uuid NOT NULL,
  setting_key text NOT NULL,
  setting_value jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_by uuid REFERENCES users(id),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, hotel_id, setting_key),
  FOREIGN KEY (tenant_id, hotel_id) REFERENCES hotels(tenant_id, id)
);

CREATE TABLE audit_logs (
  id bigserial PRIMARY KEY,
  tenant_id uuid NOT NULL,
  hotel_id uuid,
  actor_user_id uuid REFERENCES users(id),
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id text,
  request_id text,
  source text NOT NULL DEFAULT 'web',
  before_data jsonb,
  after_data jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (tenant_id) REFERENCES tenants(id),
  FOREIGN KEY (tenant_id, hotel_id) REFERENCES hotels(tenant_id, id)
);

CREATE INDEX hotels_tenant_status_idx ON hotels(tenant_id, status);
CREATE INDEX tenant_memberships_user_idx ON tenant_memberships(user_id, status);
CREATE INDEX hotel_memberships_user_idx ON hotel_memberships(tenant_id, user_id, status);
CREATE INDEX roles_tenant_idx ON roles(tenant_id);
CREATE INDEX audit_logs_tenant_time_idx ON audit_logs(tenant_id, occurred_at DESC);
CREATE INDEX audit_logs_hotel_time_idx ON audit_logs(tenant_id, hotel_id, occurred_at DESC);

INSERT INTO permissions (key, module, description) VALUES
  ('platform.tenants.read','platform','View tenant records'),
  ('platform.tenants.manage','platform','Create and manage tenants'),
  ('hotel.settings.read','hotel','View hotel settings'),
  ('hotel.settings.manage','hotel','Manage hotel settings'),
  ('users.read','users','View hotel users'),
  ('users.manage','users','Invite and manage hotel users'),
  ('roles.read','security','View roles and permissions'),
  ('roles.manage','security','Manage roles and permissions'),
  ('audit.read','security','View audit history'),
  ('front_office.read','front_office','View Front Office records'),
  ('front_office.write','front_office','Create and update Front Office records'),
  ('housekeeping.read','housekeeping','View housekeeping records'),
  ('housekeeping.write','housekeeping','Update housekeeping records'),
  ('back_office.read','back_office','View Back Office records'),
  ('back_office.write','back_office','Create and update Back Office records'),
  ('finance.read','finance','View finance and accounting records'),
  ('finance.post','finance','Post finance and accounting transactions'),
  ('reports.read','reports','View operational and financial reports')
ON CONFLICT (key) DO NOTHING;

-- Tenant context is set by trusted server code inside each transaction using SET LOCAL.
-- Never accept tenant_id directly from an untrusted browser request.
CREATE OR REPLACE FUNCTION app_current_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('app.tenant_id', true), '')::uuid
$$;

CREATE OR REPLACE FUNCTION app_current_hotel_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('app.hotel_id', true), '')::uuid
$$;

ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE hotels ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE hotel_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE hotel_membership_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE hotel_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Apply RLS even to table owners; superusers/BYPASSRLS roles still bypass by design.
ALTER TABLE tenants FORCE ROW LEVEL SECURITY;
ALTER TABLE hotels FORCE ROW LEVEL SECURITY;
ALTER TABLE tenant_memberships FORCE ROW LEVEL SECURITY;
ALTER TABLE hotel_memberships FORCE ROW LEVEL SECURITY;
ALTER TABLE roles FORCE ROW LEVEL SECURITY;
ALTER TABLE role_permissions FORCE ROW LEVEL SECURITY;
ALTER TABLE hotel_membership_roles FORCE ROW LEVEL SECURITY;
ALTER TABLE hotel_settings FORCE ROW LEVEL SECURITY;
ALTER TABLE audit_logs FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenants
  USING (id = app_current_tenant_id())
  WITH CHECK (id = app_current_tenant_id());

CREATE POLICY hotel_tenant_isolation ON hotels
  USING (tenant_id = app_current_tenant_id())
  WITH CHECK (tenant_id = app_current_tenant_id());

CREATE POLICY tenant_membership_isolation ON tenant_memberships
  USING (tenant_id = app_current_tenant_id())
  WITH CHECK (tenant_id = app_current_tenant_id());

CREATE POLICY hotel_membership_isolation ON hotel_memberships
  USING (tenant_id = app_current_tenant_id()
    AND (app_current_hotel_id() IS NULL OR hotel_id = app_current_hotel_id()))
  WITH CHECK (tenant_id = app_current_tenant_id()
    AND (app_current_hotel_id() IS NULL OR hotel_id = app_current_hotel_id()));

CREATE POLICY role_isolation ON roles
  USING (tenant_id = app_current_tenant_id())
  WITH CHECK (tenant_id = app_current_tenant_id());

CREATE POLICY role_permission_isolation ON role_permissions
  USING (tenant_id = app_current_tenant_id())
  WITH CHECK (tenant_id = app_current_tenant_id());

CREATE POLICY membership_role_isolation ON hotel_membership_roles
  USING (tenant_id = app_current_tenant_id()
    AND (app_current_hotel_id() IS NULL OR hotel_id = app_current_hotel_id()))
  WITH CHECK (tenant_id = app_current_tenant_id()
    AND (app_current_hotel_id() IS NULL OR hotel_id = app_current_hotel_id()));

CREATE POLICY hotel_settings_isolation ON hotel_settings
  USING (tenant_id = app_current_tenant_id()
    AND (app_current_hotel_id() IS NULL OR hotel_id = app_current_hotel_id()))
  WITH CHECK (tenant_id = app_current_tenant_id()
    AND (app_current_hotel_id() IS NULL OR hotel_id = app_current_hotel_id()));

CREATE POLICY audit_log_isolation ON audit_logs
  USING (tenant_id = app_current_tenant_id()
    AND (app_current_hotel_id() IS NULL OR hotel_id = app_current_hotel_id()))
  WITH CHECK (tenant_id = app_current_tenant_id()
    AND (app_current_hotel_id() IS NULL OR hotel_id = app_current_hotel_id()));

-- Audit history is append-only for application roles.
CREATE OR REPLACE FUNCTION prevent_audit_log_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'audit_logs is append-only';
END;
$$;

CREATE TRIGGER audit_logs_no_update
  BEFORE UPDATE OR DELETE ON audit_logs
  FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_mutation();

INSERT INTO schema_migrations(version) VALUES ('0001_corestay_foundation')
ON CONFLICT (version) DO NOTHING;

COMMIT;
