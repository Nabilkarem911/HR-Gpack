-- هذا السكريبت سيقوم تلقائياً بترقية أول حساب مسجل في النظام ليكون (مدير عام Super Admin)
-- مما سيفتح لك كافة الصلاحيات المغلقة ويسمح لك بإضافة الموظفين والمنشآت والمستخدمين.

DO $$ 
DECLARE
  first_user_id UUID;
  first_user_email VARCHAR;
BEGIN
  -- جلب أول مستخدم قام بتسجيل الدخول في النظام
  SELECT id, email INTO first_user_id, first_user_email FROM auth.users ORDER BY created_at ASC LIMIT 1;
  
  IF first_user_id IS NOT NULL THEN
    -- محاولة إضافته كمدير عام، أو تحديث صلاحيته إذا كان موجوداً مسبقاً
    INSERT INTO public.system_users (id, email, full_name, role)
    VALUES (first_user_id, first_user_email, 'المدير العام (الأساسي)', 'super_admin')
    ON CONFLICT (id) DO UPDATE SET role = 'super_admin';
  END IF;
END $$;
