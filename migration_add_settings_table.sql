-- Create settings table
CREATE TABLE IF NOT EXISTS settings (
  key VARCHAR(255) PRIMARY KEY,
  value TEXT,
  description TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Allow authenticated users to read settings" ON settings
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to insert settings" ON settings
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update settings" ON settings
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to delete settings" ON settings
  FOR DELETE TO authenticated USING (true);

-- Insert default attendance time limit (12:00 PM)
INSERT INTO settings (key, value, description)
VALUES ('attendance_time_limit', '12:00', 'Batas waktu pengeditan absensi (format HH:mm)')
ON CONFLICT (key) DO NOTHING;
