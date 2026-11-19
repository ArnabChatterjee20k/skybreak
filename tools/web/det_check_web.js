// Serves a det-check web export, starts it in headless Chromium and prints the
// det_check lines from the browser console. Exits 1 if they never finish.
// Usage: node tools/web/det_check_web.js <build dir> [timeout seconds]
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const root = path.resolve(process.argv[2]);
const seconds = Number(process.argv[3] || 900);
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
	res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
	fs.createReadStream(file).pipe(res);
});

(async () => {
	await new Promise((r) => server.listen(0, '127.0.0.1', r));
	const browser = await chromium.launch({
		args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
	});
	const page = await browser.newPage();
	const lines = [];
	let finish;
	const done = new Promise((r) => { finish = r; });
	page.on('console', (m) => {
		const text = m.text();
		if (text.startsWith('det_check') || text.startsWith('det_math') || /^(ffa|bot) t\d+ /.test(text)) {
			lines.push(text);
		}
		if (text === 'det_check done') finish(true);
	});
	page.on('pageerror', (e) => console.log(`pageerror: ${e.message}`));
	await page.goto(`http://127.0.0.1:${server.address().port}/`);
	const start = await page.$('#start');
	if (start) await start.click();
	const ok = await Promise.race([done, new Promise((r) => setTimeout(() => r(false), seconds * 1000))]);
	const ua = await page.evaluate(() => navigator.userAgent);
	await browser.close();
	server.close();
	console.log(`# ${ua}`);
	lines.filter((l) => l !== 'det_check done').forEach((l) => console.log(l));
	if (!ok) {
		console.log('FAIL: det_check did not finish');
		process.exit(1);
	}
})();
