// Initialize Supabase Client
const SUPABASE_URL = 'https://fctybugtoeeuvfonmdyl.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZjdHlidWd0b2VldXZmb25tZHlsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2NDk0MzgsImV4cCI6MjA4ODIyNTQzOH0.f5_SGoZI0TuJLCTdmaOqHUSzsf2hj4ZkjlCVLeXNaZE';

// Assign Supabase client directly to window.db to avoid 'const supabase' global conflicts
if (window.supabase) {
    window.db = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}

// Re-enabling Authentication
window.checkAuth = async function () {
    if (!window.db) return null;
    const { data: { session }, error } = await window.db.auth.getSession();
    if (error) console.error("Error checking session:", error);
    return session;
}

// Global utilities
window.showError = (message) => {
    alert('خطأ: ' + message);
}
window.showSuccess = (message) => {
    alert('نجاح: ' + message);
}
