import { chromium } from '@playwright/test';

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  // Collect console messages
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
  
  // Wait an extra 3 seconds for Leaflet to init
  await page.waitForTimeout(3000);

  console.log('--- Extracting DOM ---');
  const content = await page.content();
  const hasLeaflet = content.includes('leaflet-container');
  
  console.log('Has leaflet-container in HTML:', hasLeaflet);

  if (!hasLeaflet) {
    // Print the main content area to see what's actually there
    const mainHTML = await page.locator('main').innerHTML();
    console.log('--- MAIN CONTENT HTML ---');
    console.log(mainHTML.slice(0, 2000)); // Print first 2000 chars
  } else {
    console.log('Map rendered successfully!');
  }

  await browser.close();
})();
