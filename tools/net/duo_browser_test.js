// Duo end to end in two headless Chromium pages, against the local Appwrite mock:
// serves an exported *debug* web build (the dev-only `appwrite` URL parameter is
// ignored by release builds), opens the host page, goes Main menu -> Duo with the
// keyboard, and lets DuoTestPilot drive the Duo screen (sign in, host, picks, ready,
// start). The guest page joins with the room code the host prints. Inputs then go
// over real browser WebRTC between the pages, with LaggyTransport adding delay,
// jitter, loss and one forced rollback burst. Pass: both pages finish the match,
// every state hash both confirmed is equal, no desync, no console errors, at least
// MIN_SECONDS of match.
//
// Usage: node tools/net/duo_browser_test.js <web build dir> <out dir> [minutes]
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');
const mock = require('./appwrite_mock');

// Main menu layout (game/ui/menus/main_menu.gd, 1920x1080 design): a column at
// x 120 (clicked at 400), y 330, buttons 86 tall with 14 between them; the web build drops Quit.
const MENU = { x: 400, top: 330, height: 86, gap: 14, design: 1080 };

// Centre of the Duo button in page pixels, from the menu's own ENTRIES list, so a new
// entry (Pure Fight moved Duo down one) can't make the test click the wrong one.
function duoButtonAt(viewport) {
	const src = fs.readFileSync(path.join(__dirname, '../../game/ui/menus/main_menu.gd'), 'utf8');
	const list = src.slice(src.indexOf('const ENTRIES'), src.indexOf(']', src.indexOf('const ENTRIES')));
	const ids = [...list.matchAll(/"id": &"(\w+)"/g)].map((m) => m[1]).filter((id) => id !== 'quit');
	const index = ids.indexOf('duo');
	if (index < 0) throw new Error('main_menu.gd ENTRIES has no duo entry');
	const scale = viewport.height / MENU.design;
	const y = MENU.top + index * (MENU.height + MENU.gap) + MENU.height / 2;
	return { x: Math.round(MENU.x * scale), y: Math.round(y * scale) };
}

const root = path.resolve(process.argv[2] || 'build/web');
const out = path.resolve(process.argv[3] || 'reports/net/duo-online');
const minutes = Number(process.argv[4] || 3);
const MIN_SECONDS = 120;
const TIMEOUT_MS = (minutes * 60 + 900) * 1000;
// Test-only accounts that exist only inside the mock; not the real players' passwords.
const PASSWORD = 'mock-only-' + Math.random().toString(36).slice(2);
const USERS = [
	{ id: 'skybreak-player-1', email: 'skybreak-player-1@example.com', password: PASSWORD, name: 'skybreak-player-1' },
	{ id: 'skybreak-player-2', email: 'skybreak-player-2@example.com', password: PASSWORD, name: 'skybreak-player-2' },
];
const NET = { net_lag: 45, net_jitter: 20, net_loss: 0.02 };
const BURST = { burst_frame: 4200, burst_ms: 140 };
const types = {
	'.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm',
	'.pck': 'application/octet-stream', '.png': 'image/png', '.zip': 'application/zip',
};

function serve() {
	const server = http.createServer((req, res) => {
		const url = decodeURIComponent(req.url.split('?')[0]);
		const file = path.join(root, url === '/' ? 'index.html' : url);
		if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
			res.writeHead(404);
			res.end();
			return;
		}
		// No COOP/COEP: the single-threaded build must not need cross-origin isolation.
		res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
		fs.createReadStream(file).pipe(res);
	});
	return new Promise((r) => server.listen(0, '127.0.0.1', () => r(server)));
}

function query(params) {
	return '?' + Object.entries(params).map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join('&');
}

class Peer {
	constructor(name, page) {
		this.name = name;
		this.page = page;
		this.events = [];
		this.errors = [];
		this.logs = [];
		this.hashes = new Map();
		this.warnings = [];
		let inWarning = false;
		page.on('console', (m) => {
			const text = m.text();
			if (/GL Driver Message/.test(text)) return;
			this.logs.push(`[${m.type()}] ${text}`);
			if (m.type() === 'error') {
				// Godot prints WARNING blocks (message, "at:", backtrace) through console.error.
				const continuation = /^\s+(at: |GDScript backtrace|\[\d+\] )/.test(text);
				if (text.startsWith('WARNING:')) inWarning = true;
				else if (!continuation) inWarning = false;
				const bakeManifest = /Failed to load resource/.test(text) && /\/zones\/manifest\.json/.test(m.location().url || '');
				if (inWarning || bakeManifest) this.warnings.push(text);
				else this.errors.push(text);
			}
			const at = text.indexOf('SKYBREAK_DUO ');
			if (at >= 0) {
				const event = JSON.parse(text.slice(at + 13));
				this.events.push(event);
				if (event.hashes) for (const [frame, h] of event.hashes) this.hashes.set(frame, h);
				if (event.event !== 'stats') console.log(`${this.name}: ${JSON.stringify(event).slice(0, 300)}`);
				else console.log(`${this.name}: frame ${event.frame} rtt ${event.rtt} ms rollbacks ${event.rollbacks} (max ${event.max_depth}) stalls ${event.stalls} compared ${event.compared} lives ${event.lives} fps ${event.fps}`);
			}
		});
		page.on('pageerror', (e) => this.errors.push(`pageerror: ${e.message}`));
	}

	last(event) {
		return [...this.events].reverse().find((e) => e.event === event);
	}

	async waitFor(event, ms) {
		const end = Date.now() + ms;
		while (Date.now() < end) {
			const found = this.last(event);
			if (found) return found;
			const failed = this.last('error');
			if (failed) throw new Error(`${this.name} failed: ${JSON.stringify(failed)}`);
			await new Promise((r) => setTimeout(r, 250));
		}
		throw new Error(`${this.name}: no ${event} within ${ms / 1000} s`);
	}

	async boot(url) {
		await this.page.goto(url);
		await this.page.click('#start', { timeout: 240000 });
		await this.page.waitForSelector('#cover', { state: 'detached', timeout: 240000 });
		await this.page.waitForTimeout(8000);
		// Any key ends the splash; then click the main menu's Duo entry.
		await this.page.keyboard.press('Space');
		await this.page.waitForTimeout(2500);
		const at = duoButtonAt(this.page.viewportSize());
		await this.page.mouse.move(at.x, at.y);
		await this.page.waitForTimeout(300);
		await this.page.mouse.click(at.x, at.y);
		await this.waitFor('lobby', 30000);
	}

	async shot(name) {
		const file = path.join(out, name);
		try {
			await this.page.screenshot({ path: file, timeout: 120000 });
			console.log(`screenshot ${path.relative(process.cwd(), file)}`);
		} catch (e) {
			// A page busy loading a zone can miss a screenshot; that is not a net failure.
			console.log(`screenshot ${name} skipped: ${String(e.message).split('\n')[0]}`);
		}
	}
}

(async () => {
	const t0 = Date.now();
	fs.mkdirSync(out, { recursive: true });
	const site = await serve();
	const origin = `http://127.0.0.1:${site.address().port}`;
	const mockLog = fs.createWriteStream(path.join(out, 'appwrite_mock.log'));
	const appwrite = await mock.start({ origins: [origin], users: USERS, latencyMs: 120,
		log: (line) => mockLog.write(`${((Date.now() - t0) / 1000).toFixed(1)} ${line}\n`) });
	console.log(`site ${origin}, Appwrite mock ${appwrite.url} (120 ms per request)`);
	const launch = () => chromium.launch({
		args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist',
			'--disable-features=WebRtcHideLocalIpsWithMdns', '--autoplay-policy=no-user-gesture-required'],
	});
	const viewport = { width: 640, height: 360 };
	// Two browser processes with their own storage (user:// lives in IndexedDB), like two devices.
	const browsers = [await launch(), await launch()];
	const host = new Peer('host', await (await browsers[0].newContext({ viewport })).newPage());
	const guest = new Peer('guest', await (await browsers[1].newContext({ viewport })).newPage());
	// render_hz: SwiftShader takes ~1 s per frame; drawing one every 4 s lets the game loop run near 60 Hz.
	const common = { appwrite: appwrite.url, password: PASSWORD, render_hz: 0.25, start_delay: 12, ...NET };
	const started = Date.now();
	let verdict = 'FAIL';
	const problems = [];
	try {
		await host.boot(origin + '/' + query({ ...common, duo_test: 'host', email: USERS[0].email,
			legend: 'kael', zone: 'heartbloom_gardens', ai_count: 1, ai_level: 2, lives: 6, minutes, ...BURST }));
		const code = (await host.waitFor('code', 60000)).code;
		await host.shot('host_1_room_code.png');
		await guest.boot(origin + '/' + query({ ...common, duo_test: 'join', email: USERS[1].email,
			legend: 'vexa', code }));
		await host.waitFor('connected', 120000);
		await guest.waitFor('connected', 120000);
		await host.waitFor('picked', 60000);
		await guest.page.waitForTimeout(5000);
		await host.shot('host_2_lobby_setup.png');
		await guest.shot('guest_2_lobby_setup.png');
		await host.waitFor('match_loaded', 900000);
		await guest.waitFor('match_loaded', 900000);
		const loaded = Date.now();
		const shots = [30, 90, 150];
		while (!(host.last('over') && guest.last('over'))) {
			if (Date.now() - started > TIMEOUT_MS) throw new Error('match did not finish in time');
			if (host.last('desync') || guest.last('desync')) break;
			const s = (Date.now() - loaded) / 1000;
			if (shots.length && s >= shots[0]) {
				const mark = shots.shift();
				await host.shot(`host_3_match_${mark}s.png`);
				await guest.shot(`guest_3_match_${mark}s.png`);
			}
			await new Promise((r) => setTimeout(r, 1000));
		}
		await host.page.waitForTimeout(3000);
		await host.shot('host_4_match_over.png');
		await guest.shot('guest_4_match_over.png');
	} catch (e) {
		problems.push(String(e.message || e));
		await host.shot('host_failure.png').catch(() => {});
		await guest.shot('guest_failure.png').catch(() => {});
	}

	const hostOver = host.last('over');
	const guestOver = guest.last('over');
	let compared = 0;
	let mismatched = 0;
	for (const [frame, h] of host.hashes) {
		if (!guest.hashes.has(frame)) continue;
		compared++;
		if (guest.hashes.get(frame) !== h) {
			mismatched++;
			if (mismatched <= 5) problems.push(`hash mismatch at tick ${frame}: ${h} vs ${guest.hashes.get(frame)}`);
		}
	}
	const lastFrame = Math.min(hostOver ? hostOver.frame : 0, guestOver ? guestOver.frame : 0);
	const matchSeconds = lastFrame / 60;
	if (!hostOver || !guestOver) problems.push('a page did not finish the match');
	if (host.last('desync') || guest.last('desync')) problems.push('desync reported');
	if (compared < 100) problems.push(`only ${compared} common state hashes`);
	if (matchSeconds < MIN_SECONDS) problems.push(`match lasted ${matchSeconds.toFixed(0)} s of sim time (< ${MIN_SECONDS})`);
	if (!host.last('burst')) problems.push('the forced rollback burst did not run');
	for (const peer of [host, guest]) {
		for (const e of peer.errors) problems.push(`${peer.name} console error: ${e.slice(0, 300)}`);
	}
	if (problems.length === 0) verdict = 'PASS';
	const stats = (peer) => {
		const over = peer.last('over') || {};
		const all = peer.events.filter((e) => e.event === 'stats');
		const rtts = all.map((e) => e.rtt).filter((r) => r > 0);
		return {
			frames: over.frame, winning_team: over.winning_team, timed_out: over.timed_out,
			rollbacks: over.rollbacks, max_rollback_depth: over.max_depth, hashes_compared_in_band: over.compared,
			stalls: (all[all.length - 1] || {}).stalls, sync_skips: (all[all.length - 1] || {}).sync_skips,
			rtt_ms_median: rtts.sort((a, b) => a - b)[Math.floor(rtts.length / 2)] || null,
			fps_median: all.map((e) => e.fps).sort((a, b) => a - b)[Math.floor(all.length / 2)] || null,
			console_errors: peer.errors.length,
			godot_warnings: peer.warnings.filter((w) => w.startsWith('WARNING:')),
		};
	};
	const report = {
		verdict, problems, wall_seconds: Math.round((Date.now() - started) / 1000),
		match_sim_seconds: Math.round(matchSeconds), common_state_hashes: compared, mismatched_hashes: mismatched,
		net: NET, burst: BURST, appwrite_mock: { latency_ms: 120, ...appwrite.stats },
		host: stats(host), guest: stats(guest),
	};
	fs.writeFileSync(path.join(out, 'browser_test.json'), JSON.stringify(report, null, 2));
	fs.writeFileSync(path.join(out, 'browser_console_host.log'), host.logs.join('\n'));
	fs.writeFileSync(path.join(out, 'browser_console_guest.log'), guest.logs.join('\n'));
	console.log(JSON.stringify(report, null, 2));
	for (const b of browsers) await b.close();
	await appwrite.close();
	site.close();
	console.log(`${verdict}: Duo host -> join -> match over WebRTC in two pages`);
	process.exit(verdict === 'PASS' ? 0 : 1);
})().catch((e) => {
	console.error(e);
	process.exit(1);
});
