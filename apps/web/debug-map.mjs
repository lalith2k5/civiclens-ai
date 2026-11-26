import { chromium } from '@playwright/test';

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  page.on('console', msg => console.log('BROWSER CONSOLE:', msg.type(), msg.text()));
  page.on('pageerror', error => console.log('BROWSER ERROR:', error.message));

  console.log('--- Navigating to login ---');
  await page.goto('http://localhost:3000/login');
  await page.click('button:has-text("Operator")');
  await page.click('button[type="submit"]');
  await page.waitForURL(/.*operations/);
  console.log('Logged in successfully.');

  console.log('--- Navigating to Map ---');
  await page.goto('http://localhost:3000/operations/map');
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(3000);

  console.log('--- Extracting DOM ---');
  const hasLeaflet = await page.locator('.leaflet-container').count();
  
  console.log('Number of leaflet-containers found:', hasLeaflet);

  if (hasLeaflet === 0) {
    const mainHTML = await page.locator('main').innerHTML();
    console.log('--- MAIN CONTENT HTML ---');
    console.log(mainHTML.slice(0, 3000));
  } else {
    console.log('Map rendered successfully!');
  }

  await browser.close();
})();
