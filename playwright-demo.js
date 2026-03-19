const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();

  // Search Wikipedia for "Asahi Linux"
  await page.goto('https://en.wikipedia.org');
  console.log('Page title:', await page.title());

  await page.locator('#searchInput').fill('Asahi Linux');
  await page.locator('#searchInput').press('Enter');
  await page.waitForLoadState('domcontentloaded');

  console.log('Article title:', await page.title());

  const intro = await page.locator('#mw-content-text p:not(.mw-empty-elt)').first().textContent();
  console.log('\nFirst paragraph:');
  console.log(intro.trim().slice(0, 300));

  await browser.close();
})();
