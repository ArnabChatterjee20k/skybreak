// T-UX2 web checks in headless Chromium.
//   node tools/web/controls_web.js conflicts <build dir>
//     Boots the real build, focuses the canvas and checks the browser defaults behind
//     game bindings are suppressed (Tab focus, Space/wheel scroll, Ctrl+key shortcuts,
//     Ctrl+wheel zoom, right-click menu, middle-click autoscroll). Exits 1 on a leak.
//   node tools/web/controls_web.js rollover <build dir | --stub>
//     Pure Fight's two-players-one-keyboard matrix (no numpad): holds P1 and P2 chords
//     together and checks every keydown/keyup reaches the focused canvas with the right code
//     and Shift side, is suppressed, and focus never moves. --stub runs it on a bare page with
//     the engine's canvas listeners instead of a build; ROLLOVER_EVERY=n samples every nth
//     chord. Exits 1 on a dropped or leaked key.
//   node tools/web/controls_web.js audit <build dir>
//     Runs tests/combat/controls_audit.gd inside the wasm build (export it with
//     tools/web/controls_audit_web.sh) and prints its table. Exits 1 on BROKEN rows.
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const mode = process.argv[2];
const root = path.resolve(process.argv[3] || 'build/web');
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

// Each probe: what the player does, and the browser default that must not happen.
const KEY_PROBES = ['Tab', 'Space', 'Control+s', 'Control+d', 'Control+f', 'Control+r', 'Control+e',
	'Control+g', 'Control+1', 'Control+4', 'Control+a', 'F3', 'Shift+Space', 'Control+Space',
	// Pure Fight P2 (no numpad): arrows scroll, / and ' open Firefox quick find.
	'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Comma', 'Period', 'Slash', 'Semicolon', 'Quote',
	'BracketLeft', 'BracketRight', 'ShiftRight+ArrowLeft', 'ShiftRight+Slash', 'ShiftLeft+KeyD'];

// Pure Fight keys by DOM code (game/input/pure_fight_keys.gd).
const P1 = { dirs: [[], ['KeyD'], ['KeyS', 'KeyD'], ['KeyA', 'KeyW'], ['KeyS', 'KeyA']],
	buttons: ['KeyJ', 'KeyK', 'KeyL', 'KeyU', 'KeyI', 'KeyO', 'KeyE', 'ShiftLeft', 'Space'] };
const P2 = { dirs: [[], ['ArrowLeft'], ['ArrowDown', 'ArrowLeft'], ['ArrowRight', 'ArrowUp'], ['ArrowDown', 'ArrowRight']],
	buttons: ['Comma', 'Period', 'Slash', 'Semicolon', 'Quote', 'BracketRight', 'BracketLeft', 'ShiftRight'] };
const NUMPAD = /^Numpad/;

// Every direction with no, one or two buttons, for one player.
function chords(side) {
	const presses = [[]];
	side.buttons.forEach((a, i) => {
		presses.push([a]);
		side.buttons.slice(i + 1).forEach((b) => presses.push([a, b]));
	});
	const out = [];
	for (const d of side.dirs) for (const b of presses) out.push(d.concat(b));
	return out;
}

// Each player's full chord list against a few of the other's busiest chords, both orders.
function matrix() {
	const a = chords(P1);
	const b = chords(P2);
	const busy = (list) => list.filter((c) => c.length >= 3).filter((_, i) => i % 23 === 0);
	const rows = [];
	for (const c of a) for (const d of busy(b)) rows.push(c.concat(d));
	for (const d of b) for (const c of busy(a)) rows.push(d.concat(c));
	return rows;
}

async function rollover(page) {
	await page.evaluate(() => {
		window.__keys = [];
		const record = (e) => window.__keys.push({ type: e.type, code: e.code, location: e.location,
			prevented: e.defaultPrevented, target: e.target && e.target.id });
		window.addEventListener('keydown', record);
		window.addEventListener('keyup', record);
	});
	const canvas = await page.$('#canvas');
	const box = await canvas.boundingBox();
	await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
	const all = new Set(P1.buttons.concat(P2.buttons, ...P1.dirs, ...P2.dirs));
	const numpad = [...all].filter((c) => NUMPAD.test(c));
	// ROLLOVER_EVERY=n keeps every nth chord (a running build answers each key slowly).
	const every = Number(process.env.ROLLOVER_EVERY || 1);
	const rows = matrix().filter((_, i) => i % every === 0);
	let bad = 0;
	const failures = [];
	for (const chord of rows) {
		await page.evaluate(() => { window.__keys = []; });
		for (const code of chord) await page.keyboard.down(code);
		const held = await page.evaluate(() => window.__keys.slice());
		for (const code of chord.slice().reverse()) await page.keyboard.up(code);
		const seen = await page.evaluate(() => window.__keys.slice());
		const focus = await page.evaluate(() => document.activeElement && document.activeElement.id);
		const problems = [];
		for (const code of chord) {
			const down = held.find((k) => k.type === 'keydown' && k.code === code);
			const up = seen.find((k) => k.type === 'keyup' && k.code === code);
			if (!down || !up) problems.push(`${code} ${down ? 'no keyup' : 'no keydown'}`);
			else if (!down.prevented) problems.push(`${code} not suppressed`);
			else if (down.target !== 'canvas') problems.push(`${code} went to ${down.target}`);
			if (down && code.startsWith('Shift') && down.location !== (code === 'ShiftLeft' ? 1 : 2)) {
				problems.push(`${code} location ${down.location}`);
			}
		}
		if (focus !== 'canvas') problems.push(`focus moved to ${focus}`);
		if (problems.length) {
			bad += 1;
			if (failures.length < 20) failures.push(`${chord.join('+')}: ${problems.join(', ')}`);
		}
	}
	const longest = Math.max(...rows.map((c) => c.length));
	console.log(`rollover: ${rows.length} chords (P1 x P2, up to ${longest} keys held at once), ${bad} with a dropped, leaked or misrouted key`);
	console.log(`numpad keys in the layout: ${numpad.length ? numpad.join(' ') : 'none'}`);
	failures.forEach((f) => console.log(`  ${f}`));
	return bad === 0 && numpad.length === 0;
}

// A bare page with the engine's own canvas key listeners (library_godot_input.js onKeyEvent).
const STUB = `<!doctype html><html><body style="margin:0"><canvas id="canvas" tabindex="0"
	style="display:block;width:100vw;height:100vh"></canvas><script>
	const c = document.getElementById('canvas');
	for (const t of ['keydown', 'keyup']) c.addEventListener(t, (e) => e.preventDefault());
	c.focus();
	</script></body></html>`;

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
		if (mode === 'audit' && (text.startsWith('  ') || text.startsWith('==') || text.startsWith('|') || text.startsWith('controls_audit'))) {
			console.log(text);
		}
		if (text.startsWith('| lock-on toggle (Tab)')) finish();
	});
	page.on('pageerror', (e) => console.log(`pageerror: ${e.message}`));
	let ok;
	if (mode === 'rollover' && process.argv[3] === '--stub') {
		await page.setContent(STUB);
		ok = await rollover(page);
		await browser.close();
		server.close();
		console.log(ok ? 'PASS' : 'FAIL');
		process.exit(ok ? 0 : 1);
	}
	await page.goto(`http://127.0.0.1:${server.address().port}/`);
	await page.click('#start', { timeout: 120000 });
	await page.waitForSelector('#cover', { state: 'detached', timeout: 300000 });
	if (mode === 'rollover') {
		await page.waitForTimeout(8000);
		ok = await rollover(page);
	} else if (mode === 'conflicts') {
		await page.waitForTimeout(8000);
		ok = await conflicts(page);
	} else {
		await Promise.race([done, page.waitForTimeout(Number(process.env.AUDIT_SECONDS || 1500) * 1000)]);
		ok = lines.some((l) => l.startsWith('| lock-on toggle (Tab)')) && !lines.some((l) => l.includes('BROKEN'));
	}
	if (!ok) {
		console.log('--- last browser console lines ---');
		lines.slice(-40).forEach((l) => console.log(l));
	}
	await browser.close();
	server.close();
	console.log(ok ? 'PASS' : 'FAIL');
	process.exit(ok ? 0 : 1);
})();
