// Plays the web build like a player in headless Chromium: start click, front end,
// Play (vs AI) -> Choose zone -> Fight, then 30 s of input with screenshots at 5/15/30 s.
// Served with no COOP/COEP headers, like a static host. Fails on any console error.
// Usage: node tools/web/match_smoke_test.js [build dir] [out dir]
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const root = path.resolve(process.argv[2] || 'build/web');
const out = path.resolve(process.argv[3] || path.join(root, '..', 'web_match_smoke'));
const types = {
	'.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm',
	'.pck': 'application/octet-stream', '.png': 'image/png',
};
let served = 0;

const server = http.createServer((req, res) => {
	const url = decodeURIComponent(req.url.split('?')[0]);
	const file = path.join(root, url === '/' ? 'index.html' : url);
	if (!file.startsWith(root) || !fs.existsSync(file)) {
		res.writeHead(404);
		res.end();
		return;
	}
	served += fs.statSync(file).size;
	res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
	fs.createReadStream(file).pipe(res);
});

// Browser frame intervals (Godot's main loop runs on requestAnimationFrame).
async function frameTimes(page, ms) {
	return page.evaluate((ms) => new Promise((resolve) => {
		const d = [];
		let last = performance.now();
		const end = last + ms;
		const step = (t) => {
			d.push(t - last);
			last = t;
			if (t < end) requestAnimationFrame(step); else resolve(d);
		};
		requestAnimationFrame(step);
	}), ms);
}

function summary(d) {
	const s = [...d].sort((a, b) => a - b);
	const avg = d.reduce((a, b) => a + b, 0) / d.length;
	const p95 = s[Math.floor(s.length * 0.95)];
	return `${d.length} frames, avg ${avg.toFixed(1)} ms (${(1000 / avg).toFixed(1)} fps), p95 ${p95.toFixed(1)} ms, max ${s[s.length - 1].toFixed(1)} ms`;
}

(async () => {
	fs.mkdirSync(out, { recursive: true });
	await new Promise((r) => server.listen(0, '127.0.0.1', r));
	const url = `http://127.0.0.1:${server.address().port}/`;
	const browser = await chromium.launch({
		args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
	});
	const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
	const errors = [];
	const logs = [];
	page.on('console', (m) => {
		if (/GL Driver Message/.test(m.text())) return;
		logs.push(`[${m.type()}] ${m.text()}`);
		if (m.type() === 'error') errors.push(m.text());
	});
	page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
	const shot = async (name) => {
		await page.screenshot({ path: path.join(out, name) });
		console.log(`screenshot ${name}`);
	};

	const t0 = Date.now();
	await page.goto(url);
	await page.click('#start', { timeout: 60000 });
	await page.waitForSelector('#cover', { state: 'detached', timeout: 180000 });
	console.log(`load: start click -> engine running in ${((Date.now() - t0) / 1000).toFixed(1)} s, ${(served / 1048576).toFixed(1)} MB served (uncompressed)`);
	await page.waitForTimeout(8000);
	await shot('1_menu.png');
	console.log(`menu frame time: ${summary(await frameTimes(page, 5000))}`);

	await page.keyboard.press('Enter'); // Play (vs AI)
	await page.waitForTimeout(3000);
	await shot('2_character_select.png');
	await page.mouse.click(1090, 686); // Choose zone >
	await page.waitForTimeout(3000);
	await shot('3_zone_select.png');
	await page.mouse.click(1105, 657); // Fight!
	await page.waitForTimeout(3000);
	await shot('3b_after_fight_click.png');
	const fight = Date.now();

	// 30 s of play: move, fly, ki blasts and attacks, so the match is not idle.
	const presses = ['KeyW', 'KeyQ', 'Space', 'KeyD', 'KeyQ', 'KeyR', 'KeyA', 'KeyF', 'Digit1', 'KeyE'];
	let i = 0;
	const marks = [5, 15, 30];
	let frames = [];
	for (const mark of marks) {
		while (Date.now() - fight < mark * 1000) {
			const k = presses[i++ % presses.length];
			await page.keyboard.down(k);
			frames = frames.concat(await frameTimes(page, 400));
			await page.keyboard.up(k);
			await page.mouse.click(640, 360);
		}
		await shot(`4_match_${mark}s.png`);
	}
	console.log(`match frame time: ${summary(frames)}`);
	console.log('--- browser console ---');
	logs.forEach((l) => console.log(l));
	await browser.close();
	server.close();
	if (errors.length) {
		errors.forEach((e) => console.log(`error: ${e}`));
		console.log(`FAIL: ${errors.length} console error(s)`);
		process.exit(1);
	}
	console.log('PASS: menu -> vs AI match ran 30 s with no console errors');
})().catch((e) => {
	console.error(e);
	server.close();
	process.exit(1);
});
