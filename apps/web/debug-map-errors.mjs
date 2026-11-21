import { chromium } from '@playwright/test';

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  page.on('console', msg => {
    if (msg.type() === 'error' || msg.type() === 'warning') {
      console.log(`[BROWSER ${msg.type().toUpperCase()}] ${msg.text()}`);
    }
  });
  page.on('pageerror', error => console.log('[PAGE ERROR]', error.message));

  // Login
  await page.goto('http://localhost:3000/login');
  await page.fill('input[type="email"]', 'operator@civiclens.ai');
  await page.fill('input[type="password"]', 'password123');
  await page.click('button[type="submit"]');
  await page.waitForURL(/.*operations/);

  // Go to map
  console.log('--- Navigating to map ---');
  await page.goto('http://localhost:3000/operations/map');
  await page.waitForTimeout(5000);

  const content = await page.content();
  const hasLeaflet = content.includes('leaflet-container');
  console.log('Has leaflet-container:', hasLeaflet);

  if (!hasLeaflet) {
    const mainHTML = await page.locator('main').innerHTML();
    console.log('--- MAIN HTML (first 1000 chars) ---');
    console.log(mainHTML.slice(0, 1000));
  }

  await browser.close();
})();
