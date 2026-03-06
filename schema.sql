-- تفعيل إضافة توليد UUID إذا لم تكن مفعلة
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. إنشاء أنواع البيانات (Enums)
CREATE TYPE emp_status_enum AS ENUM ('active', 'inactive', 'on_leave', 'terminated');
CREATE TYPE fsm_status_enum AS ENUM ('pending', 'approved', 'rejected', 'processed');
CREATE TYPE att_status_enum AS ENUM ('present', 'absent', 'late', 'half_day', 'on_leave');
CREATE TYPE rule_type_enum AS ENUM ('allowance', 'deduction');

-- 2. إنشاء الجداول
-- جدول الأقسام
CREATE TABLE departments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- جدول الموظفين
CREATE TABLE employees (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id), -- الربط مع مصادقة Supabase
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
    position VARCHAR(100),
    hire_date DATE NOT NULL,
    basic_salary DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    role VARCHAR(50) DEFAULT 'employee', -- 'admin', 'hr_manager', 'employee'
    status emp_status_enum DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- جدول الحضور والانصراف
CREATE TABLE attendance (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    check_in TIMESTAMP WITH TIME ZONE,
    check_out TIMESTAMP WITH TIME ZONE,
    status att_status_enum DEFAULT 'absent',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(employee_id, date) -- الموظف لديه سجل حضور واحد لكل يوم (يمكن دعمه للورديات الليلية عبر تعديل المنطق)
);

-- جدول الإجازات (FSM دورة الموافقات)
CREATE TABLE leaves (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    leave_type VARCHAR(50) NOT NULL, -- سنوي، مرضي، بدون راتب..
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_days INTEGER NOT NULL,
    reason TEXT,
    status fsm_status_enum DEFAULT 'pending',
    manager_id UUID REFERENCES employees(id) ON DELETE SET NULL, -- المدير الموافق
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- جدول السلف
CREATE TABLE loans (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL,
    reason TEXT,
    months_installment INTEGER NOT NULL,
    monthly_deduction DECIMAL(10, 2) NOT NULL,
    status fsm_status_enum DEFAULT 'pending',
    manager_id UUID REFERENCES employees(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- جدول قواعد الرواتب (المحرك الديناميكي للبدلات والاستقطاعات)
CREATE TABLE payroll_rules (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type rule_type_enum NOT NULL,
    amount DECIMAL(10, 2), -- مبلغ ثابت
    percentage DECIMAL(5, 2), -- نسبة مئوية من الراتب الأساسي (مثال: 5.0 للإشارة إلى 5%)
    is_global BOOLEAN DEFAULT true, -- إذا كان صحيح يطبق على الجميع
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- جدول قواعد الرواتب المخصصة للموظفين (لربط بدلات أو استقطاعات خاصة بموظفين معينين)
CREATE TABLE employee_payroll_rules (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    rule_id UUID REFERENCES payroll_rules(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(employee_id, rule_id)
);

-- جدول كشوفات الرواتب (حفظ السجلات المعالجة)
CREATE TABLE payslips (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    month INTEGER NOT NULL,
    year INTEGER NOT NULL,
    basic_salary DECIMAL(10, 2) NOT NULL,
    total_allowances DECIMAL(10, 2) NOT NULL DEFAULT 0,
    total_deductions DECIMAL(10, 2) NOT NULL DEFAULT 0,
    absences_deduction DECIMAL(10, 2) NOT NULL DEFAULT 0,
    net_salary DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'draft', -- draft, processed, paid
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(employee_id, month, year)
);

-- 3. الدوال والمحفزات (Triggers)
-- دالة تحديث عمود updated_at تلقائياً
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_employees_timestamp BEFORE UPDATE ON employees FOR EACH ROW EXECUTE PROCEDURE update_timestamp();
CREATE TRIGGER update_leaves_timestamp BEFORE UPDATE ON leaves FOR EACH ROW EXECUTE PROCEDURE update_timestamp();
CREATE TRIGGER update_loans_timestamp BEFORE UPDATE ON loans FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

-- 4. إعدادات الأمان RLS (Row Level Security)

-- تمكين RLS لجميع الجداول
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaves ENABLE ROW LEVEL SECURITY;
ALTER TABLE loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_payroll_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE payslips ENABLE ROW LEVEL SECURITY;

-- دالة مرجعية للتأكد من أن المستخدم مدير نظام (admin أو hr_manager)
CREATE OR REPLACE FUNCTION is_hr_admin() RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM employees 
    WHERE user_id = auth.uid() 
    AND role IN ('admin', 'hr_manager')
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- سياسات جدول الأقسام (الكل يمكنه القراءة)
CREATE POLICY "Departments are viewable by everyone" ON departments FOR SELECT USING (true);
CREATE POLICY "Only admins insert/update departments" ON departments FOR ALL TO authenticated USING (is_hr_admin());

-- سياسات جدول الموظفين
-- الموظف يرى بياناته فقط، والإدارة ترى الجميع
CREATE POLICY "Employees can view own data" ON employees FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "HR admins can manage all employees" ON employees FOR ALL TO authenticated USING (is_hr_admin());

-- سياسات الحضور
CREATE POLICY "Employees can view own attendance" ON attendance FOR SELECT USING (
  employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
);
CREATE POLICY "Employees can manage own attendance" ON attendance FOR ALL USING (
  employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
);
CREATE POLICY "HR Admins manage attendance" ON attendance FOR ALL TO authenticated USING (is_hr_admin());

-- سياسات الإجازات والسلف
CREATE POLICY "Employees view own leaves" ON leaves FOR SELECT USING (
  employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
);
CREATE POLICY "Employees manage own leaves" ON leaves FOR ALL USING (
  employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
);
CREATE POLICY "HR Admins manage leaves" ON leaves FOR ALL TO authenticated USING (is_hr_admin());

CREATE POLICY "Employees view own loans" ON loans FOR SELECT USING (
  employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
);
CREATE POLICY "Employees manage own loans" ON loans FOR ALL USING (
  employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
);
CREATE POLICY "HR Admins manage loans" ON loans FOR ALL TO authenticated USING (is_hr_admin());

-- سياسات الرواتب والقواعد
CREATE POLICY "Employees view payroll rules" ON payroll_rules FOR SELECT TO authenticated USING (true);
CREATE POLICY "HR Admins manage payroll rules" ON payroll_rules FOR ALL TO authenticated USING (is_hr_admin());

CREATE POLICY "Employees view own specific rules" ON employee_payroll_rules FOR SELECT USING (
  employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
);
CREATE POLICY "HR Admins manage specific rules" ON employee_payroll_rules FOR ALL TO authenticated USING (is_hr_admin());

CREATE POLICY "Employees view own payslips" ON payslips FOR SELECT USING (
  employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
);
CREATE POLICY "HR Admins manage payslips" ON payslips FOR ALL TO authenticated USING (is_hr_admin());
