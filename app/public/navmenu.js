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
        console.log(event.target.getAttribute('title') + 'target');
        menuItems.forEach(item => {
            if (item == event.target) {
                console.log(item.getAttribute('title')+ ' equals');
            } else if (item.nextElementSibling.contains(event.target)) {
                console.log(item.getAttribute('title')+' contains');
            } else {
                console.log(item.getAttribute('title'));
                item.setAttribute('aria-expanded', 'false');
                const submenu = item.nextElementSibling;
                if (submenu) {
                    submenu.style.display = 'none';
                }
            }
        });
    });
});