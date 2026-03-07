document.addEventListener('DOMContentLoaded', () => {
    const mainContent = document.getElementById('main-content');
    const navLinks = document.querySelectorAll('.nav-link');
    const sidebar = document.getElementById('sidebar');
    const toggleSidebarBtn = document.getElementById('toggle-sidebar');

    // Sidebar Toggle
    toggleSidebarBtn.addEventListener('click', () => {
        // Toggle Sidebar visibility and margin dynamically
        if (sidebar.classList.contains('translate-x-full')) {
            sidebar.classList.remove('translate-x-full');
            // On mobile, show it as an overlay
            if (window.innerWidth <= 768) {
                sidebar.classList.add('absolute', 'z-20', 'h-full');
            }
        } else {
            sidebar.classList.add('translate-x-full');
        }
    });

    // Handle Resize for responsive sidebar
    window.addEventListener('resize', () => {
        if (window.innerWidth > 768) {
            sidebar.classList.remove('translate-x-full', 'absolute', 'z-20', 'h-full');
        } else {
            sidebar.classList.add('translate-x-full');
        }
    });

    // Initial check on load
    if (window.innerWidth <= 768) {
        sidebar.classList.add('translate-x-full');
    }

    // Simple Router (Master Layout loading partials)
    const loadPage = async (pageName) => {
        // Strict Front-End Route Guard securely protecting the System Users Page
        if (pageName === 'users' && window.currentUserRole !== 'super_admin') {
            alert('غير مصرح لك بالدخول لهذه الصفحة');
            window.location.hash = '#dashboard';
            return;
        }

        try {
            // Show loader
            mainContent.innerHTML = `
                <div class="flex justify-center items-center h-full w-full">
                    <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
                </div>
            `;

            // Update active state in nav sidebar
            navLinks.forEach(link => {
                link.classList.remove('active');
                if (link.dataset.page === pageName) {
                    link.classList.add('active');
                }
            });

            // Fetch page HTML
            const response = await fetch(`pages/${pageName}.html`);
            if (!response.ok) {
                // Return simple 404 or create page placeholder
                if (response.status === 404) {
                    mainContent.innerHTML = `
                        <div class="flex flex-col items-center justify-center h-full text-slate-400">
                            <i class="fa-solid fa-hammer text-6xl mb-4 text-slate-300"></i>
                            <h2 class="text-2xl font-bold">الصفحة قيد الإنشاء</h2>
                            <p class="mt-2 text-slate-500">جاري العمل على وحدة "${pageName}"</p>
                        </div>
                    `;
                    return;
                }
                throw new Error('Page note loaded');
            }
            const html = await response.text();

            // Render page content with animation
            mainContent.innerHTML = `<div class="page-enter">${html}</div>`;

            // Execute scripts inside the injected HTML (Vanilla JS limitation workaround)
            const scripts = mainContent.querySelectorAll('script');
            scripts.forEach(oldScript => {
                // Prevent reloading supabaseClient inside partials if accidentally added
                if (oldScript.src && oldScript.src.includes('supabaseClient')) return;

                const newScript = document.createElement('script');
                Array.from(oldScript.attributes).forEach(attr => newScript.setAttribute(attr.name, attr.value));
                newScript.appendChild(document.createTextNode(oldScript.innerHTML));
                if (oldScript.parentNode) {
                    oldScript.parentNode.replaceChild(newScript, oldScript);
                }
            });

        } catch (error) {
            console.error('Error loading page:', error);
            mainContent.innerHTML = `
                <div class="bg-red-50 border-r-4 border-red-500 p-4 rounded-md inline-block">
                    <div class="flex items-center">
                        <i class="fa-solid fa-circle-exclamation text-red-500 text-xl ml-3"></i>
                        <p class="text-red-700 font-bold">عذراً، حدث خطأ أثناء تحميل الصفحة.</p>
                    </div>
                </div>
            `;
        }
    }; // end loadPage

    // Listen for hash changes
    window.addEventListener('hashchange', () => {
        let hash = window.location.hash.substring(1);
        if (!hash) hash = 'dashboard';
        loadPage(hash);
    });

    // Intercept nav clicks to hide sidebar on mobile automatically
    navLinks.forEach(link => {
        link.addEventListener('click', () => {
            if (window.innerWidth <= 768) {
                sidebar.classList.add('translate-x-full');
            }
        });
    });

    // Load initial route or check auth
    const initApp = async () => {
        // Robust auto-login session check (Remember Me)
        const { data } = await window.db.auth.getSession();
        let initialHash = window.location.hash.substring(1);

        if (data && data.session) {
            try {
                // Fetch logged-in user details to sync shell
                const { data: userData, error } = await window.db
                    .from('system_users')
                    .select('full_name, role, custom_permissions')
                    .eq('id', data.session.user.id)
                    .single();

                if (userData) {
                    // Load Global App State for Routing Checks
                    window.currentUserRole = userData.role;
                    window.currentUserPerms = userData.custom_permissions;

                    // Manage Sidebar Visibility
                    const usersNav = document.querySelector('a[data-page="users"]');
                    if (usersNav && window.currentUserRole !== 'super_admin') {
                        usersNav.parentElement.style.display = 'none';
                    }

                    const roleMap = {
                        'super_admin': 'مدير عام',
                        'hr_manager': 'موارد بشرية',
                        'branch_manager': 'مدير فرع',
                        'viewer': 'مشاهد'
                    };
                    const nameElem = document.getElementById('current-user-name');
                    if (nameElem) {
                        nameElem.innerText = userData.full_name || 'مستخدم غير معروف';
                        const roleElem = nameElem.nextElementSibling;
                        if (roleElem) roleElem.innerText = roleMap[userData.role] || userData.role;
                    }
                }
            } catch (err) {
                console.error("Error fetching user profile for shell:", err);
            }

            // Immediately hide Login and route to Dashboard or requested page
            if (!initialHash || initialHash === 'login') {
                initialHash = 'dashboard';
                window.location.hash = '#dashboard';
            }
            loadPage(initialHash);
        } else {
            // No session, force login page
            window.location.hash = '#login';
            loadPage('login');
        }

        // Setup Logout functionality
        const logoutBtn = document.getElementById('logout-btn');
        if (logoutBtn) {
            logoutBtn.addEventListener('click', async () => {
                await window.db.auth.signOut();
                window.location.hash = '#login';
                window.location.reload();
            });
        }
    };

    initApp();
});
