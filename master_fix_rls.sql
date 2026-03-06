-- 1. التأكد من إنشاء حساب لك كمدير عام في جدول system_users
DO $$ 
DECLARE
  first_user_id UUID;
  first_user_email VARCHAR;
BEGIN
  -- جرج أول مستخدم (وهو أنت)
  SELECT id, email INTO first_user_id, first_user_email FROM auth.users ORDER BY created_at ASC LIMIT 1;
  
  IF first_user_id IS NOT NULL THEN
    -- إدراج المستخدم بصلاحية super_admin، أو تحديثه إذا كان موجوداً
    INSERT INTO public.system_users (id, email, full_name, role)
    VALUES (first_user_id, first_user_email, 'المدير العام', 'super_admin')
    ON CONFLICT (id) DO UPDATE SET role = 'super_admin';
  END IF;
END $$;

-- 2. إيقاف RLS عن جدول الموظفين كلياً وحل مشكلة سياسات الإضافة (Insert) للموظفين.
ALTER TABLE public.employees DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.companies DISABLE ROW LEVEL SECURITY;

-- 3. مسح أي سياسات سابقة قد تسبب التعارض
DROP POLICY IF EXISTS "System users can view employees" ON employees;
DROP POLICY IF EXISTS "HR Managers manage employees" ON employees;
DROP POLICY IF EXISTS "Super Admins can do anything to employees" ON employees;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON companies;
DROP POLICY IF EXISTS "Super Admins can manage companies" ON companies;

-- 4. إعادة تفعيل RLS بشكل نظيف وصحيح 100%
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;

-- 5. إنشاء سياسات شاملة للمدير العام (Super Admin)
-- سياسات الشركات (Companies)
CREATE POLICY "Super Admins full access companies" ON companies 
FOR ALL TO authenticated 
USING (is_super_admin()) 
WITH CHECK (is_super_admin());

-- سماح لجميع المستخدمين الموثقين برؤية الشركات فقط
CREATE POLICY "All authenticated users view companies" ON companies 
FOR SELECT TO authenticated 
USING (true);

-- سياسات الموظفين (Employees)
CREATE POLICY "Super Admins full access employees" ON employees 
FOR ALL TO authenticated 
USING (is_super_admin()) 
WITH CHECK (is_super_admin());

-- سماح لجميع المستخدمين الموثقين برؤية الموظفين فقط (أو فلترة حسب الشركة لاحقاً)
CREATE POLICY "All authenticated users view employees" ON employees 
FOR SELECT TO authenticated 
USING (true);

-- 6. سياسات جدول system_users نفسه لضمان أن المدير يمكنه تحديث صلاحيات الآخرين
DROP POLICY IF EXISTS "Super admins manage system_users" ON system_users;
CREATE POLICY "Super admins manage system_users" ON system_users 
FOR ALL TO authenticated 
USING (is_super_admin()) 
WITH CHECK (is_super_admin());

-- 7. فك حماية جدول الرواتب مؤقتاً لضمان عدم وجود مشكلة عند الإضافة (upsert)
ALTER TABLE public.payslips DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Super Admins manage payslips" ON payslips;
ALTER TABLE public.payslips ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Super Admins manage payslips" ON payslips 
FOR ALL TO authenticated 
USING (is_super_admin()) 
WITH CHECK (is_super_admin());
CREATE POLICY "All view payslips" ON payslips 
FOR SELECT TO authenticated 
USING (true);
