// T-UX2 web checks in headless Chromium.
//   node tools/web/controls_web.js conflicts <build dir>
//     Boots the real build, focuses the canvas and checks the browser defaults behind
//     game bindings are suppressed (Tab focus, Space/wheel scroll, Ctrl+key shortcuts,
//     Ctrl+wheel zoom, right-click menu, middle-click autoscroll). Exits 1 on a leak.
//   node tools/web/controls_web.js audit <build dir> [legend]
//     Runs tests/combat/controls_audit.gd inside the wasm build (export it with
//     tools/web/controls_audit_web.sh) and prints its table. Exits 1 on BROKEN rows.
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const mode = process.argv[2];
const root = path.resolve(process.argv[3] || 'build/web');
const legend = process.argv[4] || 'kael';
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
	if (mode === 'audit' && file.endsWith('index.html')) {
		// Run the audit script as the main loop instead of the front end.
		const html = fs.readFileSync(file, 'utf8').replace("args: ['--main-pack', pack]",
			`args: ['--main-pack', pack, '-s', 'res://tests/combat/controls_audit.gd', '--', '${legend}']`);
		res.end(html);
		return;
	}
	fs.createReadStream(file).pipe(res);
});

// Each probe: what the player does, and the browser default that must not happen.
const KEY_PROBES = ['Tab', 'Space', 'Control+s', 'Control+d', 'Control+f', 'Control+r', 'Control+e',
	'Control+g', 'Control+1', 'Control+4', 'Control+a', 'F3', 'Shift+Space', 'Control+Space'];

async function conflicts(page) {
	await page.evaluate(() => {
		window.__probe = [];
		const record = (e) => window.__probe.push({ type: e.type, key: e.key || '', button: e.button,
			ctrl: e.ctrlKey, prevented: e.defaultPrevented });
		for (const t of ['keydown', 'wheel', 'contextmenu', 'mousedown', 'auxclick']) {
			// Window bubble phase: after the engine's own canvas listeners.
			window.addEventListener(t, record, { passive: false });
		}
	});
	const canvas = await page.$('#canvas');
	const box = await canvas.boundingBox();
	await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
	await page.evaluate(() => { window.__probe = []; });
	const rows = [];
	for (const combo of KEY_PROBES) {
		await page.evaluate(() => { window.__probe = []; });
		await page.keyboard.press(combo);
		const seen = await page.evaluate(() => window.__probe.filter((p) => p.type === 'keydown'));
		const last = seen[seen.length - 1];
		const focus = await page.evaluate(() => document.activeElement && document.activeElement.id);
		rows.push([combo, last ? last.prevented : 'no event', focus === 'canvas' ? '' : `focus moved to ${focus}`]);
	}
	const mouse = async (name, act, type) => {
		await page.evaluate(() => { window.__probe = []; });
		await act();
		const seen = await page.evaluate((t) => window.__probe.filter((p) => p.type === t), type);
		rows.push([name, seen.length ? seen.every((p) => p.prevented) : 'no event', '']);
	};
	const cx = box.x + box.width / 2;
	const cy = box.y + box.height / 2;
	await mouse('Mouse wheel', () => page.mouse.wheel(0, 120), 'wheel');
	await page.keyboard.down('Control');
	await mouse('Ctrl+wheel (zoom)', () => page.mouse.wheel(0, 120), 'wheel');
	await page.keyboard.up('Control');
	await mouse('Right click (context menu)', () => page.mouse.click(cx, cy, { button: 'right' }), 'contextmenu');
	await mouse('Middle click (autoscroll)', () => page.mouse.click(cx, cy, { button: 'middle' }), 'mousedown');
	const scrollY = await page.evaluate(() => window.scrollY);
	console.log('| Browser default behind | Suppressed (defaultPrevented) | Note |');
	console.log('|---|---|---|');
	let leaks = 0;
	for (const [name, prevented, note] of rows) {
		if (prevented !== true || note) leaks += 1;
		console.log(`| ${name} | ${prevented} | ${note} |`);
	}
	console.log(`page scrollY after the probes: ${scrollY}`);
	return leaks === 0 && scrollY === 0;
}

(async () => {
	await new Promise((r) => server.listen(0, '127.0.0.1', r));
	const browser = await chromium.launch({
		args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
	});
	const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
	const lines = [];
	let finish;
	const done = new Promise((r) => { finish = r; });
	page.on('console', (m) => {
		const text = m.text();
		lines.push(text);
		if (mode === 'audit' && (text.startsWith('  ') || text.startsWith('==') || text.startsWith('|'))) {
			console.log(text);
		}
		if (text.startsWith('| lock-on toggle (Tab)')) finish();
	});
	page.on('pageerror', (e) => console.log(`pageerror: ${e.message}`));
	await page.goto(`http://127.0.0.1:${server.address().port}/`);
	await page.click('#start', { timeout: 120000 });
	await page.waitForSelector('#cover', { state: 'detached', timeout: 300000 });
	let ok;
	if (mode === 'conflicts') {
		await page.waitForTimeout(8000);
		ok = await conflicts(page);
	} else {
		await Promise.race([done, page.waitForTimeout(1500 * 1000)]);
		ok = lines.some((l) => l.startsWith('| lock-on toggle (Tab)')) && !lines.some((l) => l.includes('BROKEN'));
	}
	await browser.close();
	server.close();
	console.log(ok ? 'PASS' : 'FAIL');
	process.exit(ok ? 0 : 1);
})();
