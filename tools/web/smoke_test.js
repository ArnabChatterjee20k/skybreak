// Headless browser smoke test for build/web: serves it, clicks start, waits for
// the engine to boot, fails on console errors and saves a screenshot.
// Usage: node tools/web/smoke_test.js [build dir] [screenshot.png] [seconds]
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const root = path.resolve(process.argv[2] || 'build/web');
const shot = path.resolve(process.argv[3] || path.join(root, '..', 'web_smoke.png'));
const seconds = Number(process.argv[4] || 40);
const types = {
	'.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm',
	'.pck': 'application/octet-stream', '.png': 'image/png',
};

const server = http.createServer((req, res) => {
	const url = decodeURIComponent(req.url.split('?')[0]);
	const file = path.join(root, url === '/' ? 'index.html' : url);
	if (!file.startsWith(root) || !fs.existsSync(file)) {
		res.writeHead(404);
		res.end();
		return;
	}
	// No COOP/COEP headers on purpose: the single-threaded build must not need them.
	res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
	fs.createReadStream(file).pipe(res);
});

(async () => {
	await new Promise((r) => server.listen(0, '127.0.0.1', r));
	const url = `http://127.0.0.1:${server.address().port}/`;
	const browser = await chromium.launch({
		args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
	});
	const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
	const errors = [];
	const logs = [];
	page.on('console', (m) => {
		logs.push(`[${m.type()}] ${m.text()}`);
		if (m.type() === 'error') errors.push(m.text());
	});
	page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
	await page.goto(url);
	const webgl2 = await page.evaluate(() => !!document.createElement('canvas').getContext('webgl2'));
	console.log(`WebGL2 available: ${webgl2}`);
	await page.click('#start', { timeout: 60000 });
	await page.waitForSelector('#cover', { state: 'detached', timeout: 180000 });
	console.log('Engine started (loading cover removed).');
	await page.waitForTimeout(seconds * 1000);
	const crossOriginIsolated = await page.evaluate(() => self.crossOriginIsolated);
	console.log(`crossOriginIsolated: ${crossOriginIsolated} (expected false)`);
	await page.screenshot({ path: shot });
	console.log(`Screenshot: ${shot}`);
	console.log('--- browser console ---');
	logs.forEach((l) => console.log(l));
	await browser.close();
	server.close();
	if (errors.length) {
		console.log(`FAIL: ${errors.length} console error(s)`);
		process.exit(1);
	}
	console.log('PASS: booted with no console errors');
})().catch((e) => {
	console.error(e);
	server.close();
	process.exit(1);
});
