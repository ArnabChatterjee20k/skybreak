// Headless browser match smoke test for build/web (T-UX1): boots, walks the
// menus into a VS AI match with Enter, checks the control hints show, flies up
// with Space, waits for the fly-down prompt, double-taps C and checks the
// fighter lands (prompt gone). Saves a screenshot per step.
// Usage: node tools/web/match_smoke_test.js [build dir] [out dir]
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const root = path.resolve(process.argv[2] || 'build/web');
const out = path.resolve(process.argv[3] || path.join(root, '..', 'web_match_smoke'));
fs.mkdirSync(out, { recursive: true });
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

// Yellow prompt text pixels in the band above the hint strip (fraction of the frame).
async function promptPixels(page) {
	const png = (await page.screenshot()).toString('base64');
	return page.evaluate(async (data) => {
		const bitmap = await createImageBitmap(await (await fetch(`data:image/png;base64,${data}`)).blob());
		const c = new OffscreenCanvas(bitmap.width, bitmap.height);
		const g = c.getContext('2d');
		g.drawImage(bitmap, 0, 0);
		const y0 = Math.floor(bitmap.height * 0.86);
		const y1 = Math.floor(bitmap.height * 0.94);
		const x0 = Math.floor(bitmap.width * 0.3);
		const x1 = Math.floor(bitmap.width * 0.7);
		const d = g.getImageData(x0, y0, x1 - x0, y1 - y0).data;
		let n = 0;
		for (let i = 0; i < d.length; i += 4) {
			if (d[i] > 220 && d[i + 1] > 180 && d[i + 1] < 235 && d[i + 2] < 90) n++;
		}
		return n;
	}, png);
}

(async () => {
	await new Promise((r) => server.listen(0, '127.0.0.1', r));
	const url = `http://127.0.0.1:${server.address().port}/`;
	const browser = await chromium.launch({
		args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist',
			'--autoplay-policy=no-user-gesture-required'],
	});
	const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
	const errors = [];
	// The desktop-only WebRTC GDExtension has no web library; its load errors are expected.
	const expected = (t) => t.includes('webrtc_native') || t.includes('gdextension');
	page.on('console', (m) => { if (m.type() === 'error' && !expected(m.text())) errors.push(m.text()); });
	page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}\n${e.stack}`));
	page.on('console', (m) => { if (process.env.VERBOSE) console.log(`[${m.type()}] ${m.text()}`); });
	await page.goto(url);
	await page.click('#start', { timeout: 60000 });
	await page.waitForSelector('#cover', { state: 'detached', timeout: 180000 });
	await page.waitForTimeout(8000);
	await page.click('canvas', { position: { x: 5, y: 5 } });
	const shot = (name) => page.screenshot({ path: path.join(out, `${name}.png`) });
	// Splash, main menu (VS AI), character select (confirm), zone select (fight).
	// Steps are keys ("Enter") or clicks at 1280x720 points ("click:1090:686").
	const steps = (process.env.MENU_STEPS || 'Enter,Enter,click:1090:686,click:1105:655').split(',');
	for (let i = 0; i < steps.length; i++) {
		if (steps[i].startsWith('click:')) {
			const [, x, y] = steps[i].split(':').map(Number);
			await page.mouse.click(x, y);
		} else {
			await page.keyboard.press(steps[i]);
		}
		await page.waitForTimeout(2500);
		await shot(`menu_${i}`);
	}
	await page.waitForTimeout(15000);
	await shot('match_start');
	await page.keyboard.down('Space');
	await page.waitForTimeout(1500);
	await page.keyboard.up('Space');
	await page.waitForTimeout(6000);
	await shot('hovering');
	const hovering = await promptPixels(page);
	await page.keyboard.press('KeyC');
	await page.waitForTimeout(80);
	await page.keyboard.press('KeyC');
	await page.waitForTimeout(5000);
	await shot('after_dive');
	const landed = await promptPixels(page);
	const open = !page.isClosed();
	console.log(`prompt pixels while hovering: ${hovering}, after double-tap C: ${landed}, page open: ${open}`);
	await browser.close();
	server.close();
	const ok = errors.length === 0 && hovering > 50 && landed < hovering / 5;
	if (errors.length) console.log(`console errors:\n${errors.join('\n')}`);
	console.log(ok ? 'PASS: hints shown, fly-down prompt appeared, double-tap C landed' : 'FAIL');
	process.exit(ok ? 0 : 1);
})().catch((e) => {
	console.error(e);
	server.close();
	process.exit(1);
});
