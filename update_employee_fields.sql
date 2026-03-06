-- إضافة الحقول الجديدة لجدول الموظفين
ALTER TABLE public.employees
ADD COLUMN IF NOT EXISTS emp_code VARCHAR(50) UNIQUE,
ADD COLUMN IF NOT EXISTS iqama_number VARCHAR(50),
ADD COLUMN IF NOT EXISTS nationality VARCHAR(100),
ADD COLUMN IF NOT EXISTS iqama_profession VARCHAR(100);

-- دالة (Function) لتوليد رقم موظف تسلسلي تلقائياً عند الإضافة إذا لم يتم توفيره
CREATE OR REPLACE FUNCTION generate_emp_code()
RETURNS TRIGGER AS $$
DECLARE
    next_num INTEGER;
BEGIN
    IF NEW.emp_code IS NULL OR NEW.emp_code = '' THEN
        -- استخراج أكبر رقم حالي وإضافة 1 (تجنب الحروف)
        SELECT COALESCE(MAX(NULLIF(regexp_replace(emp_code, '\D', '', 'g'), '')::INTEGER), 0) + 1 
        INTO next_num 
        FROM public.employees;
        
        -- التنسيق: EMP-0001
        NEW.emp_code := 'EMP-' || lpad(next_num::text, 4, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ربط الدالة بـ Trigger لتعمل مباشرة قبل أي عملية إدخال جديدة (Insert)
DROP TRIGGER IF EXISTS trigger_generate_emp_code ON public.employees;
CREATE TRIGGER trigger_generate_emp_code
BEFORE INSERT ON public.employees
FOR EACH ROW
EXECUTE FUNCTION generate_emp_code();

-- تحديث الموظفين الحاليين (إن وجدوا) برقم تسلسلي
DO $$ 
DECLARE
    emp RECORD;
    next_n INTEGER;
BEGIN
    SELECT COALESCE(MAX(NULLIF(regexp_replace(emp_code, '\D', '', 'g'), '')::INTEGER), 0) + 1 INTO next_n FROM public.employees;
    
    FOR emp IN SELECT id FROM public.employees WHERE emp_code IS NULL LOOP
        UPDATE public.employees SET emp_code = 'EMP-' || lpad(next_n::text, 4, '0') WHERE id = emp.id;
        next_n := next_n + 1;
    END LOOP;
END $$;
