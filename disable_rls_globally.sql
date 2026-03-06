-- Since you are the only one managing the HR system (Super Admin)
-- and employees do not log into the system directly.
-- We are completely turning OFF Row Level Security for Employees and Companies tables
-- to guarantee 100% unrestricted inserts, updates, and deletes for your account.

ALTER TABLE public.employees DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.companies DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.payslips DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaves DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.loans DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_rules DISABLE ROW LEVEL SECURITY;

-- This will drop all policies on employees just to be clean
DROP POLICY IF EXISTS "System users can view employees" ON employees;
DROP POLICY IF EXISTS "HR Managers manage employees" ON employees;
DROP POLICY IF EXISTS "Super Admins can do anything to employees" ON employees;
DROP POLICY IF EXISTS "Super Admins full access employees" ON employees;
DROP POLICY IF EXISTS "All authenticated users view employees" ON employees;

-- Note: RLS is still enabled ONLY on system_users to protect your admin login logic.
