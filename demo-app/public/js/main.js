// Check VC-AuthN status on page load
document.addEventListener('DOMContentLoaded', async () => {
    try {
        const response = await fetch('/api/vc-authn/status');
        const data = await response.json();

        if (data.status === 'online') {
            console.log('✅ VC-AuthN OIDC Controller is online');
        } else {
            console.warn('⚠️ VC-AuthN OIDC Controller is offline');
        }
    } catch (error) {
        console.error('❌ Failed to check VC-AuthN status:', error);
    }
});

// Add smooth scrolling
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    });
});
