BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS projects (
  project_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  owner_subject TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS source_versions (
  source_version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
  version_label TEXT NOT NULL,
  source_uri TEXT,
  source_commit TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(project_id, version_label)
);
CREATE TABLE IF NOT EXISTS package_instances (
  package_instance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_version_id UUID NOT NULL REFERENCES source_versions(source_version_id) ON DELETE CASCADE,
  package_name TEXT NOT NULL,
  package_version TEXT NOT NULL,
  architecture TEXT NOT NULL,
  license_expression TEXT,
  UNIQUE(source_version_id, package_name, package_version, architecture)
);
CREATE TABLE IF NOT EXISTS artifacts (
  artifact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_instance_id UUID REFERENCES package_instances(package_instance_id) ON DELETE SET NULL,
  sha256 CHAR(64) NOT NULL UNIQUE,
  media_type TEXT,
  artifact_uri TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS evidence (
  evidence_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_type TEXT NOT NULL,
  subject_id TEXT NOT NULL,
  claim TEXT NOT NULL,
  source_uri TEXT,
  source_hash CHAR(64),
  collected_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  confidence NUMERIC(4,3) CHECK (confidence BETWEEN 0 AND 1)
);
CREATE TABLE IF NOT EXISTS derivations (
  derivation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  input_evidence UUID[] NOT NULL DEFAULT '{}',
  method TEXT NOT NULL,
  result JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS policies (
  policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_name TEXT NOT NULL,
  policy_version TEXT NOT NULL,
  rules JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(policy_name, policy_version)
);
CREATE TABLE IF NOT EXISTS profiles (
  profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_name TEXT NOT NULL UNIQUE,
  constraints JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS audit_events (
  event_id BIGSERIAL PRIMARY KEY,
  actor TEXT NOT NULL,
  action TEXT NOT NULL,
  object_type TEXT NOT NULL,
  object_id TEXT NOT NULL,
  details JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS evidence_subject_idx ON evidence(subject_type, subject_id);
CREATE INDEX IF NOT EXISTS audit_created_idx ON audit_events(created_at DESC);
COMMIT;
