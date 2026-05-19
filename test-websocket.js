
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
  const context = browser.contexts()[0];
  const page = await context.newPage();

  // Test WebSocket connection
  page.on('websocket', ws => {
    console.log('WebSocket opened:', ws.url());
    ws.on('framesent', frame => console.log('Frame sent:', frame));
    ws.on('framereceived', frame => console.log('Frame received:', frame));
    ws.on('close', () => console.log('WebSocket closed'));
  });

  // Try to connect to a public echo WebSocket server
  try {
    await page.goto('data:text/html,<script>new WebSocket("wss://echo.websocket.org");</script>');
    await page.waitForTimeout(5000);
    console.log('WebSocket test completed');
  } catch (err) {
    console.error('WebSocket test failed:', err);
  }

  await page.close();
  await browser.close();
})();
