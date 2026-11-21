import { chromium } from '@playwright/test';

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  page.on('console', msg => console.log(`[CONSOLE ${msg.type().toUpperCase()}] ${msg.text()}`));
  page.on('pageerror', error => console.log('[PAGE ERROR]', error.message));

  console.log('--- Navigating to login ---');
  await page.goto('http://localhost:3000/login');
  await page.fill('input[type="email"]', 'operator@civiclens.ai');
  await page.fill('input[type="password"]', 'password123');
  await page.click('button[type="submit"]');
  
  try {
    await page.waitForURL(/.*operations/, { timeout: 5000 });
    console.log('Logged in OK.');
  } catch(e) { console.log('Login redirect failed. Current URL:', page.url()); }

  console.log('--- Navigating to map ---');
  await page.goto('http://localhost:3000/operations/map');
  
  try {
    await page.waitForSelector('.leaflet-container', { timeout: 5000 });
    console.log('Map loaded OK.');
  } catch(e) {
    console.log('Map failed to load. Current URL:', page.url());
    const mainHTML = await page.locator('body').innerHTML();
    console.log('--- BODY HTML (first 1500 chars) ---');
    console.log(mainHTML.slice(0, 1500));
  }

  await browser.close();
})();
