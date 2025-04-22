document.addEventListener('DOMContentLoaded', () => {
    const menuItems = document.querySelectorAll('ul > li > a[aria-haspopup="true"]');

    menuItems.forEach(item => {
        item.addEventListener('click', (event) => {
            const expanded = item.getAttribute('aria-expanded') === 'true' || false;
            item.setAttribute('aria-expanded', !expanded);
            const submenu = item.nextElementSibling;
            if (submenu) {
                submenu.style.display = expanded ? 'none' : 'block';
            }
            event.preventDefault();
        });

        item.addEventListener('keydown', (event) => {
            if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault();
                item.click();
            }
        });
    });

    document.addEventListener('click', (event) => {
        menuItems.forEach(item => {
            if (item == event.target) {
            } else if (item.nextElementSibling.contains(event.target)) {
            } else {
                item.setAttribute('aria-expanded', 'false');
                const submenu = item.nextElementSibling;
                if (submenu) {
                    submenu.style.display = 'none';
                }
            }
        });
    });
});