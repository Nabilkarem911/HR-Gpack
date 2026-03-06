-- 1. Create a dedicated system_users table independent of employees
CREATE TABLE system_users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(150),
    role VARCHAR(50) DEFAULT 'viewer', -- 'super_admin', 'hr_manager', 'branch_manager', 'viewer'
    company_id UUID REFERENCES companies(id), -- If null, user sees all companies (Super/HR). If set, user sees only that branch.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Note: We are no longer linking auth.users(id) directly to employees table to avoid RLS confusion when adding employees.
-- The employees table 'user_id' column is now effectively deprecated or could be dropped.
-- To avoid breaking existing code abruptly, we won't drop it yet but we won't rely on it for admin auth.

-- 2. Create a secure trigger function to automatically add signed-up users to system_users
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.system_users (id, email, full_name, role)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name', 'viewer');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for auth.users creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 3. Replace the is_hr_admin() function to read from system_users
CREATE OR REPLACE FUNCTION is_hr_admin() RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM system_users 
    WHERE id = auth.uid() 
    AND role IN ('super_admin', 'hr_manager')
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- 4. Create function to check if user is a Super Admin
CREATE OR REPLACE FUNCTION is_super_admin() RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM system_users 
    WHERE id = auth.uid() 
    AND role = 'super_admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- 5. Fix Employees RLS Policies (This was causing the error when adding employees)
DROP POLICY IF EXISTS "Employees can view own data" ON employees;
DROP POLICY IF EXISTS "HR admins can manage all employees" ON employees;

-- Allow anyone authenticated to VIEW employees (or restrict by branch_manager if needed later)
CREATE POLICY "System users can view employees" ON employees FOR SELECT TO authenticated USING (true);

-- ONLY users with HR Admin or Super Admin role in system_users can Insert/Update/Delete employees
CREATE POLICY "HR Managers manage employees" ON employees FOR ALL TO authenticated USING (is_hr_admin());

-- Also grant full bypass to super admin for safety
CREATE POLICY "Super Admins can do anything to employees" ON employees FOR ALL TO authenticated USING (is_super_admin());


-- 6. Insert your current account directly as a Super Admin (assuming your auth.users has an ID, we will need to update it via frontend if we don't know it, or insert manually if we know your uid)
-- We will build a UI mechanism for the first Super Admin setup if the table is empty.

-- 7. Enable RLS on the new table
ALTER TABLE system_users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own system_user record" ON system_users FOR SELECT USING (id = auth.uid());
CREATE POLICY "Super admins view all system_users" ON system_users FOR SELECT USING (is_super_admin());
CREATE POLICY "Super admins manage system_users" ON system_users FOR ALL USING (is_super_admin());
