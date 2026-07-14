-- =============================================================================
-- FEMIC — Schema completo do Supabase
-- =============================================================================
-- Uso:
--   1. Faça backup JSON pelo sistema (aba Backup) antes de qualquer coisa.
--   2. Vá em https://supabase.com/dashboard/project/SEU_PROJETO/sql/new
--   3. Cole este SQL e execute.
--   4. Depois de criar as tabelas, vá no sistema → aba Backup → "Escolher arquivo"
--      e selecione o JSON de backup para restaurar os dados.
--
-- ATENÇÃO: Este SQL faz DROP TABLE CASCADE nas tabelas existentes.
-- Todos os dados serão perdidos. Tenha o backup JSON em mãos.
-- =============================================================================

-- =============================================================================
-- 1. TABELAS DA AGENDA / SISTEMA PRINCIPAL
-- =============================================================================

DROP TABLE IF EXISTS session_movements CASCADE;
DROP TABLE IF EXISTS session_packages CASCADE;
DROP TABLE IF EXISTS appointments CASCADE;
DROP TABLE IF EXISTS clinical_evolutions CASCADE;
DROP TABLE IF EXISTS clinical_anamneses CASCADE;
DROP TABLE IF EXISTS femic_generated_documents CASCADE;
DROP TABLE IF EXISTS clinic_rules CASCADE;
DROP TABLE IF EXISTS assistant_tasks CASCADE;
DROP TABLE IF EXISTS services CASCADE;
DROP TABLE IF EXISTS health_insurances CASCADE;
DROP TABLE IF EXISTS schedule_settings CASCADE;
DROP TABLE IF EXISTS patients CASCADE;
DROP TABLE IF EXISTS patient_form_responses CASCADE;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- PACIENTES
CREATE TABLE patients (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  pathology TEXT,
  whatsapp TEXT,
  archived BOOLEAN DEFAULT FALSE,
  archived_at TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- PAGADORES / CONVÊNIOS
CREATE TABLE health_insurances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- SERVIÇOS
CREATE TABLE services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT DEFAULT 'particular',
  price NUMERIC DEFAULT 0,
  duration_minutes INTEGER DEFAULT 45,
  appointment_mode TEXT DEFAULT 'grupo',
  max_patients INTEGER DEFAULT 4,
  health_insurance_id UUID REFERENCES health_insurances(id) ON DELETE SET NULL,
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- PACOTES DE SESSÕES
CREATE TABLE session_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id TEXT NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  service_id UUID REFERENCES services(id) ON DELETE SET NULL,
  total_sessions INTEGER DEFAULT 0,
  remaining_sessions INTEGER DEFAULT 0,
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- AGENDA
CREATE TABLE appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id TEXT NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  service_id UUID REFERENCES services(id) ON DELETE SET NULL,
  appointment_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  duration_minutes INTEGER DEFAULT 45,
  status TEXT DEFAULT 'agendado',
  package_consumed BOOLEAN DEFAULT FALSE,
  session_package_id UUID REFERENCES session_packages(id) ON DELETE SET NULL,
  appointment_reminder_sent BOOLEAN DEFAULT FALSE,
  appointment_reminder_sent_at TIMESTAMP WITH TIME ZONE,
  form_reminder_sent BOOLEAN DEFAULT FALSE,
  form_reminder_sent_at TIMESTAMP WITH TIME ZONE,
  reminder_sent BOOLEAN DEFAULT FALSE,
  reminder_sent_at TIMESTAMP WITH TIME ZONE,
  service_price_at_time NUMERIC DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- ANAMNESE CLÍNICA
CREATE TABLE clinical_anamneses (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL UNIQUE REFERENCES patients(id) ON DELETE CASCADE,
  chief_complaint TEXT,
  history TEXT,
  diagnosis TEXT,
  limitations TEXT,
  goals TEXT,
  obs TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- EVOLUÇÕES CLÍNICAS
CREATE TABLE clinical_evolutions (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  conduct TEXT,
  guidance TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- HISTÓRICO DE DOCUMENTOS GERADOS
CREATE TABLE femic_generated_documents (
  id TEXT PRIMARY KEY,
  patient_id TEXT REFERENCES patients(id) ON DELETE SET NULL,
  patient_name TEXT,
  document_type TEXT,
  document_title TEXT,
  document_body TEXT,
  document_date DATE,
  rendered_html TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  status TEXT DEFAULT 'active',
  source TEXT DEFAULT 'femic_unified',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- HISTÓRICO DE MOVIMENTOS DE SESSÃO
CREATE TABLE session_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id TEXT NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  appointment_id UUID REFERENCES appointments(id) ON DELETE SET NULL,
  session_package_id UUID REFERENCES session_packages(id) ON DELETE SET NULL,
  type TEXT,
  quantity INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- REGRAS COMPLEMENTARES DA CLÍNICA
CREATE TABLE clinic_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_key TEXT NOT NULL UNIQUE,
  rule_category TEXT DEFAULT 'assistant',
  title TEXT NOT NULL,
  description TEXT,
  rule_value_json JSONB DEFAULT '{}'::jsonb,
  active BOOLEAN DEFAULT TRUE,
  priority INTEGER DEFAULT 100,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- PENDÊNCIAS OPERACIONAIS DO ASSISTENTE
CREATE TABLE assistant_tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  type TEXT DEFAULT 'outro',
  status TEXT DEFAULT 'aberta',
  priority TEXT DEFAULT 'normal',
  patient_id TEXT REFERENCES patients(id) ON DELETE SET NULL,
  patient_name TEXT,
  service_id UUID REFERENCES services(id) ON DELETE SET NULL,
  service_name TEXT,
  suggestion_reason TEXT,
  phone TEXT,
  origin TEXT DEFAULT 'manual',
  requested_action TEXT,
  notes TEXT,
  suggested_slots JSONB DEFAULT '[]'::jsonb,
  candidates JSONB DEFAULT '[]'::jsonb,
  parsed_shift TEXT,
  parsed_dates JSONB DEFAULT '[]'::jsonb,
  extension_fingerprint TEXT,
  needs_review BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  completed_at TIMESTAMP WITH TIME ZONE
);

-- CONFIGURAÇÕES DA AGENDA
CREATE TABLE schedule_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  start_time TEXT DEFAULT '08:00',
  end_time TEXT DEFAULT '20:00',
  working_days TEXT DEFAULT '1,2,3,4,5,6',
  working_periods TEXT DEFAULT '08:00-12:00,16:00-20:00',
  max_patients_per_slot INTEGER DEFAULT 4,
  slot_interval_minutes INTEGER DEFAULT 30,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

INSERT INTO schedule_settings (
  start_time, end_time, working_days, working_periods,
  max_patients_per_slot, slot_interval_minutes
) VALUES (
  '08:00', '20:00', '1,2,3,4,5,6',
  '08:00-12:00,16:00-20:00', 4, 30
);

-- =============================================================================
-- 2. TABELA DE FORMULÁRIO PÚBLICO (respostas.html)
-- =============================================================================

CREATE TABLE patient_form_responses (
  id uuid primary key default gen_random_uuid(),
  submitted_at timestamptz default now(),
  response_date date not null,
  patient_name text not null,
  patient_whatsapp text not null,
  patient_pathology text,
  pain integer,
  functionality integer,
  satisfaction integer,
  symptoms text[],
  obs text,
  source text default 'patient_public_form',
  imported boolean default false,
  linked_patient_id text,
  imported_at timestamptz
);

-- =============================================================================
-- 3. ÍNDICES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_patients_name ON patients(name);
CREATE INDEX IF NOT EXISTS idx_patients_whatsapp ON patients(whatsapp);
CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments(appointment_date);
CREATE INDEX IF NOT EXISTS idx_appointments_patient ON appointments(patient_id);
CREATE INDEX IF NOT EXISTS idx_session_packages_patient ON session_packages(patient_id);
CREATE INDEX IF NOT EXISTS idx_movements_patient ON session_movements(patient_id);
CREATE INDEX IF NOT EXISTS idx_clinical_evolutions_patient_date ON clinical_evolutions(patient_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_femic_generated_documents_patient ON femic_generated_documents(patient_id);
CREATE INDEX IF NOT EXISTS idx_femic_generated_documents_created ON femic_generated_documents(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_assistant_tasks_status_updated ON assistant_tasks(status, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_assistant_tasks_origin ON assistant_tasks(origin);
CREATE INDEX IF NOT EXISTS idx_assistant_tasks_fingerprint ON assistant_tasks(extension_fingerprint);

-- =============================================================================
-- 4. SEGURANÇA (ROW LEVEL SECURITY)
-- =============================================================================

ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_insurances ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedule_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinic_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE assistant_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_anamneses ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_evolutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE femic_generated_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_form_responses ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

CREATE POLICY "authenticated_full_access_patients" ON patients FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access_health_insurances" ON health_insurances FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access_services" ON services FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access_schedule_settings" ON schedule_settings FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access_session_packages" ON session_packages FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access_appointments" ON appointments FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access_session_movements" ON session_movements FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access_clinic_rules" ON clinic_rules FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access_assistant_tasks" ON assistant_tasks FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access_clinical_anamneses" ON clinical_anamneses FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access_clinical_evolutions" ON clinical_evolutions FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access_femic_generated_documents" ON femic_generated_documents FOR ALL TO authenticated USING (true) WITH CHECK (true);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'patient_form_responses'
      AND policyname = 'Public insert and read'
  ) THEN
    CREATE POLICY "Public insert and read"
    ON patient_form_responses
    FOR ALL
    USING (true)
    WITH CHECK (true);
  END IF;
END
$$;

NOTIFY pgrst, 'reload schema';
