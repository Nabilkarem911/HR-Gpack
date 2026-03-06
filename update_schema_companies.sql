-- 1. إنشاء جدول المنشآت (Companies)
CREATE TABLE IF NOT EXISTS companies (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. إعداد سياسات الأمان للمنشآت
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Companies viewable by everyone" ON companies FOR SELECT USING (true);
CREATE POLICY "HR admins manage companies" ON companies FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM employees WHERE user_id = auth.uid() AND role IN ('admin', 'hr_manager'))
);

-- 3. إضافة ارتباط المنشأة بجدول الموظفين
ALTER TABLE employees ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES companies(id) ON DELETE SET NULL;

-- 4. إدراج المنشآت الافتراضية كعينة مبدئية
INSERT INTO companies (name) VALUES 
('مطعم أسماك البحارة'), 
('مستودع عميد البحارة'), 
('مصنع غلاف وغطاء');
