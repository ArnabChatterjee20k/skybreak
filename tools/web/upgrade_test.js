// PF-ZONE-HANG regression: replays the owner's browser history in ONE persistent Chromium profile
// (same origin throughout, like a normal profile; incognito never showed the bug) and checks that the
// newest build still reaches a running match:
//  1. each older build in order: boot, play a versus match (fills Cache Storage, user:// zone packs)
//  2. on the last older build: Settings -> Graphics -> HIGH, like the owner (saved in IndexedDB);
//     with --old-freeze-check, Pure Fight -> FIGHT there must freeze (the bug, as a control)
//  3. an update to the newest build cut off halfway (index.pck connection dropped), browser closed
//  4. newest build: Pure Fight -> Verdant Falls -> FIGHT by mouse, Pure Fight -> FIGHT by keyboard
//     (Enter), and versus -> Ember Rift -> FIGHT; each must reach window.skybreakMatch (set by
//     MatchConfig on the web) with the page answering throughout, then frames keep coming
//  5. a cold profile (like incognito) reaches a Pure Fight match on the newest build
// Usage:
//   node tools/web/upgrade_test.js <out dir> <old build dir>... <new build dir> [--old-freeze-check]
//   node tools/web/upgrade_test.js <out dir> --live <url> --profile <dir> --phase seed|verify [--expect-build <sha>]
//     seed: the live (old) build fills <dir> and saves HIGH; verify: the same profile, after a deploy.
// Build dirs come from tools/web/build_web.sh or the web-build branch's web/ folder.
'use strict';
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { chromium } = require('playwright');

const argv = process.argv.slice(2);
const flag = (name) => { const i = argv.indexOf(name); if (i < 0) return null; const v = argv[i + 1]; argv.splice(i, 2); return v; };
const bool = (name) => { const i = argv.indexOf(name); if (i < 0) return false; argv.splice(i, 1); return true; };
const live = flag('--live');
const liveProfile = flag('--profile');
const phase = flag('--phase');
const expectBuild = flag('--expect-build');
const oldFreezeCheck = bool('--old-freeze-check');
const out = path.resolve(argv.shift() || 'reports/web/pf-zone-hang/upgrade');
const builds = argv.map((b) => path.resolve(b));
fs.mkdirSync(out, { recursive: true });

const PORT = Number(process.env.SKYBREAK_TEST_PORT || 8793);
// 1280x720 viewport; the game lays out at 1920x1080, so screen points are 2/3 of the layout.
const AT = {
	chooseZone: [1180, 686], fight: [1107, 657], graphicsTab: [343, 157], high: [687, 278],
	verdant: [893, 388], ember: [1117, 388],
};
const MATCH_TIMEOUT_MS = 300000;
const OLD_MATCH_WAIT_MS = 45000;
// A page that doesn't answer this long counts as frozen.
const STALL_MS = 20000;
const MIN_FRAMES_5S = 2;
const types = {
	'.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm',
	'.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json',
};
const results = [];
const log = (s) => { console.log(s); fs.appendFileSync(path.join(out, 'log.txt'), s + '\n'); };
fs.writeFileSync(path.join(out, 'log.txt'), '');

// ---- local server: one origin, the root swapped between visits ----
const srv = { root: null, cut: null };
const sockets = new Set();
const server = http.createServer((req, res) => {
	const u = new URL(req.url, 'http://x');
	const rel = decodeURIComponent(u.pathname).replace(/^\//, '') || 'index.html';
	const file = path.join(srv.root || '/nonexistent', rel);
	if (!srv.root || !file.startsWith(srv.root) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
		res.writeHead(404);
		res.end();
		return;
	}
	const size = fs.statSync(file).size;
	const headers = { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Content-Length': size };
	if (rel === 'version.json') headers['Cache-Control'] = 'no-cache';
	res.writeHead(200, headers);
	if (srv.cut && srv.cut.rel === rel) {
		const stream = fs.createReadStream(file, { start: 0, end: Math.floor(size * srv.cut.fraction) - 1 });
		stream.on('end', () => { srv.cut.reached = true; req.socket.destroy(); });
		stream.pipe(res, { end: false });
		return;
	}
	fs.createReadStream(file).pipe(res);
});
server.on('connection', (s) => { sockets.add(s); s.on('close', () => sockets.delete(s)); });

// ---- browser visits ----
async function open(profile, url, label) {
	const ctx = await chromium.launchPersistentContext(profile, {
		viewport: { width: 1280, height: 720 },
		args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
	});
	const page = ctx.pages()[0] || await ctx.newPage();
	const v = { ctx, page, label, console: [], swHits: 0, net: 0, t0: Date.now() };
	page.on('console', (m) => {
		if (/GL Driver Message/.test(m.text())) return;
		v.console.push(`[${m.type()}] ${m.text()}`);
	});
	page.on('pageerror', (e) => v.console.push(`[pageerror] ${e.message}`));
	page.on('response', (r) => { if (r.fromServiceWorker()) v.swHits++; else v.net++; });
	await page.goto(url);
	await page.click('#start', { timeout: 120000 });
	await page.waitForSelector('#cover', { state: 'detached', timeout: 300000 });
	v.boot = await page.evaluate(() => window.skybreakBootResult || null);
	log(`[${label}] engine running in ${((Date.now() - v.t0) / 1000).toFixed(1)} s, boot ${JSON.stringify(v.boot && { mode: v.boot.mode, build: v.boot.build, why: v.boot.why })}`);
	await page.waitForTimeout(8000);
	return v;
}

async function storage(page) {
	return page.evaluate(async () => {
		const c = {};
		for (const n of await caches.keys()) c[n] = (await (await caches.open(n)).keys()).map((r) => new URL(r.url).pathname);
		const reg = await navigator.serviceWorker.getRegistration();
		const dbs = indexedDB.databases ? (await indexedDB.databases()).map((d) => d.name) : [];
		return { caches: c, sw: reg && reg.active ? reg.active.scriptURL : null, idb: dbs };
	});
}

async function close(v, name) {
	try {
		const st = await Promise.race([storage(v.page), new Promise((r) => setTimeout(() => r('page not answering'), 15000))]);
		fs.writeFileSync(path.join(out, `${name}_storage.json`), JSON.stringify(st, null, 1));
		v.storage = st;
	} catch (e) { v.storage = String(e); }
	fs.writeFileSync(path.join(out, `${name}_console.txt`), v.console.join('\n') + '\n');
	log(`[${v.label}] network ${v.net} responses, ${v.swHits} from the service worker`);
	await v.ctx.close().catch(() => {});
}

const key = async (v, k, wait = 1200) => { await v.page.keyboard.press(k); await v.page.waitForTimeout(wait); };
const click = async (v, at, wait = 2500) => { await v.page.mouse.click(at[0], at[1]); await v.page.waitForTimeout(wait); };
async function shot(v, name) {
	await v.page.screenshot({ path: path.join(out, name + '.png'), timeout: 60000 })
		.catch((e) => log(`[${v.label}] screenshot ${name} failed: ${e.message.split('\n')[0]}`));
}

// Splash -> main menu -> the nth entry (0 Play, 1 Pure Fight, 5 Settings).
async function menu(v, n) {
	await key(v, 'Enter', 2500);
	for (let i = 0; i < n; i++) await key(v, 'ArrowDown', 300);
	await key(v, 'Enter', 4000);
}

// Resolves true when the page answers within ms (a frozen main thread doesn't).
async function answers(page, ms) {
	return Promise.race([page.evaluate(() => true).catch(() => false), new Promise((r) => setTimeout(() => r(false), ms))]);
}

// Waits for MatchConfig's window.skybreakMatch; records the longest time the page didn't answer.
async function waitMatch(v, timeout) {
	const t0 = Date.now();
	let worst = 0;
	while (Date.now() - t0 < timeout) {
		const p0 = Date.now();
		const m = await Promise.race([v.page.evaluate(() => window.skybreakMatch || null).catch(() => null),
			new Promise((r) => setTimeout(() => r('frozen'), 10000))]);
		if (m === 'frozen') {
			const ok = await answers(v.page, timeout - (Date.now() - t0));
			worst = Math.max(worst, Date.now() - p0);
			if (!ok) return { match: null, frozenMs: Date.now() - p0, ms: Date.now() - t0 };
			continue;
		}
		worst = Math.max(worst, Date.now() - p0);
		if (m) return { match: m, worstStallMs: worst, ms: Date.now() - t0 };
		await v.page.waitForTimeout(1000);
	}
	return { match: null, worstStallMs: worst, ms: Date.now() - t0 };
}

// Polls the page until stop(); stop() resolves the longest time it didn't answer.
function watchStalls(page) {
	let worst = 0;
	let since = null;
	let running = true;
	(async () => {
		while (running) {
			since = Date.now();
			await answers(page, 600000);
			worst = Math.max(worst, Date.now() - since);
			since = null;
			await new Promise((r) => setTimeout(r, 500));
		}
	})();
	// A stall still going on at stop() counts up to now.
	return { stop: async () => { running = false; return Math.max(worst, since === null ? 0 : Date.now() - since); } };
}

async function frames(page, ms) {
	return page.evaluate((ms) => new Promise((resolve) => {
		let n = 0;
		const end = performance.now() + ms;
		const step = (t) => { n++; if (t < end) requestAnimationFrame(step); else resolve(n); };
		requestAnimationFrame(step);
	}), ms);
}

async function play(v, ms) {
	const keys = ['KeyD', 'KeyJ', 'KeyA', 'KeyK', 'KeyW', 'KeyL'];
	const end = Date.now() + ms;
	for (let i = 0; Date.now() < end; i++) {
		await v.page.keyboard.down(keys[i % keys.length]);
		await v.page.waitForTimeout(250);
		await v.page.keyboard.up(keys[i % keys.length]);
	}
}

// One flow on the current page: returns {ok, ...}.
async function flow(v, name, kind) {
	if (kind === 'vs') {
		await menu(v, 0);
		await click(v, AT.chooseZone);
		await click(v, AT.ember);
		await shot(v, `${name}_zone_select`);
		await click(v, AT.fight, 500);
	} else {
		await menu(v, 1);
		await shot(v, `${name}_legends`);
		await click(v, AT.chooseZone);
		await click(v, AT.verdant);
		if (kind === 'pf-enter') {
			// Focus picks a card: Verdant Falls -> Heartbloom (picked) -> Random -> FIGHT, then Enter.
			await key(v, 'ArrowDown', 500);
			await key(v, 'ArrowRight', 500);
			await key(v, 'ArrowDown', 800);
			await shot(v, `${name}_zone_select`);
			await key(v, 'Enter', 500);
		} else {
			await shot(v, `${name}_zone_select`);
			await click(v, AT.fight, 500);
		}
	}
	const r = await waitMatch(v, MATCH_TIMEOUT_MS);
	await shot(v, `${name}_after_fight`);
	if (!r.match) return Object.assign({ ok: false }, r);
	await play(v, 8000);
	const n = await Promise.race([frames(v.page, 5000), new Promise((res) => setTimeout(() => res(0), 20000))]);
	await shot(v, `${name}_match`);
	const want = { vs: { mode: 'vs_ai', zone: 'ember_rift' }, 'pf-click': { mode: 'pure_fight', zone: 'verdant_falls' },
		'pf-enter': { mode: 'pure_fight', zone: 'heartbloom_gardens' } }[kind];
	// Software WebGL runs the match at a few fps: "running" = frames still come, no long stall.
	const ok = r.match.mode === want.mode && r.match.zone === want.zone && n >= MIN_FRAMES_5S && r.worstStallMs < STALL_MS;
	return Object.assign({ ok, framesIn5s: n }, r);
}

function record(name, ok, detail) {
	results.push({ name, ok, detail });
	log(`${ok ? 'PASS' : 'FAIL'} ${name}: ${JSON.stringify(detail)}`);
}

// Owner step: Settings -> Graphics -> HIGH, then back to the menu.
async function chooseHigh(v, name) {
	await menu(v, 5);
	await click(v, AT.graphicsTab);
	await click(v, AT.high);
	await shot(v, `${name}_settings_high`);
	// Godot syncs user:// to IndexedDB after the write; closing the browser sooner loses it.
	await key(v, 'Escape', 10000);
}

async function visitBuild(profile, url, label, steps) {
	const v = await open(profile, url, label);
	const out = {};
	for (const [name, fn] of steps) out[name] = await fn(v);
	await close(v, label);
	return { v, out };
}

async function localRun() {
	if (builds.length < 2) throw new Error('need at least one old build and the new build');
	await new Promise((r) => server.listen(PORT, '127.0.0.1', r));
	const url = `http://127.0.0.1:${PORT}/`;
	const work = fs.mkdtempSync(path.join(os.tmpdir(), 'skybreak-upgrade-'));
	const profile = path.join(work, 'profile');
	const olds = builds.slice(0, -1);
	const fresh = builds[builds.length - 1];
	const newVersion = JSON.parse(fs.readFileSync(path.join(fresh, 'version.json'), 'utf8')).build;
	log(`builds: ${builds.map((b) => path.basename(b)).join(' -> ')} (new ${newVersion})`);

	for (let i = 0; i < olds.length; i++) {
		srv.root = olds[i];
		const label = `old${i + 1}_${path.basename(olds[i])}`;
		const last = i === olds.length - 1;
		const steps = [['vs', async (v) => {
			await menu(v, 0);
			await click(v, AT.chooseZone);
			await click(v, AT.fight, 500);
			// Older builds set no window.skybreakMatch: give the match time to load, then play.
			const r = await waitMatch(v, OLD_MATCH_WAIT_MS);
			await play(v, 5000);
			await shot(v, `${label}_match`);
			log(`[${label}] versus match: ${JSON.stringify(r.match) || 'no skybreakMatch (older build, no hook)'} after ${(r.ms / 1000).toFixed(0)} s`);
		}]];
		await visitBuild(profile, url, label, steps);
		if (last) {
			await visitBuild(profile, url, `${label}_owner`, [['high', (v) => chooseHigh(v, `${label}_owner`)]]);
			if (oldFreezeCheck) {
				const v = await open(profile, url, `${label}_freeze`);
				const watch = watchStalls(v.page);
				await menu(v, 1);
				await click(v, AT.chooseZone);
				await click(v, AT.verdant);
				await shot(v, `${label}_freeze_zone_select`);
				await click(v, AT.fight, 500);
				// The longest stretch the page didn't answer, from the menu to 3 minutes after FIGHT.
				await v.page.waitForTimeout(180000);
				const worst = await watch.stop();
				const frozen = worst >= STALL_MS;
				await shot(v, `${label}_freeze_after`);
				log(`[${label}] control: Pure Fight FIGHT with HIGH saved: longest stall ${(worst / 1000).toFixed(1)} s`);
				results.push({ name: 'control: the old build stalls >= 20 s with HIGH saved', ok: frozen, detail: { worstStallMs: worst }, control: true });
				await close(v, `${label}_freeze`);
			}
		}
	}

	// Update cut off halfway, then the browser closes.
	srv.root = fresh;
	srv.cut = { rel: 'index.pck', fraction: 0.5, reached: false };
	{
		const ctx = await chromium.launchPersistentContext(profile, { viewport: { width: 1280, height: 720 },
			args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
		const page = ctx.pages()[0] || await ctx.newPage();
		await page.goto(url);
		const t0 = Date.now();
		while (!srv.cut.reached && Date.now() - t0 < 60000) await page.waitForTimeout(250);
		await page.waitForTimeout(1500);
		log(`[interrupted] index.pck cut at 50%: ${srv.cut.reached}`);
		await ctx.close();
	}
	srv.cut = null;

	for (const [name, kind] of [['new_pf_click', 'pf-click'], ['new_pf_enter', 'pf-enter'], ['new_vs', 'vs']]) {
		const v = await open(profile, url, name);
		const r = await flow(v, name, kind);
		await close(v, name);
		const bootOk = v.boot && v.boot.build === newVersion;
		record(name, r.ok && bootOk, Object.assign({ boot: v.boot && v.boot.mode, build: v.boot && v.boot.build }, r));
		if (name === 'new_vs') {
			const names = v.storage && v.storage.caches ? Object.keys(v.storage.caches) : [];
			const stale = names.filter((n) => n.startsWith('skybreak-') && n !== 'skybreak-meta' && n !== `skybreak-${newVersion}`);
			const pending = v.storage && v.storage.caches && (v.storage.caches['skybreak-meta'] || []).some((p) => p.endsWith('pending.json'));
			record('only the new build is cached after the update', stale.length === 0 && !pending, { caches: names, pending });
		}
	}

	const cold = path.join(work, 'cold');
	const v = await open(cold, url, 'cold_pf');
	const r = await flow(v, 'cold_pf', 'pf-click');
	await close(v, 'cold_pf');
	record('cold profile (like incognito) reaches a Pure Fight match', r.ok, r);
	server.close();
	for (const s of sockets) s.destroy();
}

async function liveRun() {
	if (!liveProfile || !['seed', 'verify'].includes(phase)) throw new Error('--live needs --profile and --phase seed|verify');
	const url = live.endsWith('/') ? live : live + '/';
	if (phase === 'seed') {
		await visitBuild(liveProfile, url, 'live_seed', [['vs', async (v) => {
			await menu(v, 0);
			await click(v, AT.chooseZone);
			await click(v, AT.fight, 500);
			const r = await waitMatch(v, OLD_MATCH_WAIT_MS);
			await play(v, 5000);
			await shot(v, 'live_seed_match');
			log(`[live_seed] versus: ${JSON.stringify(r.match)}`);
		}]]);
		await visitBuild(liveProfile, url, 'live_seed_owner', [['high', (v) => chooseHigh(v, 'live_seed_owner')]]);
		record('seeded the profile from the live build', true, {});
		return;
	}
	for (const [name, kind] of [['live_pf_click', 'pf-click'], ['live_pf_enter', 'pf-enter'], ['live_vs', 'vs']]) {
		const v = await open(liveProfile, url, name);
		const r = await flow(v, name, kind);
		await close(v, name);
		const bootOk = !expectBuild || (v.boot && String(v.boot.build).startsWith(expectBuild));
		record(name, r.ok && bootOk, Object.assign({ boot: v.boot && v.boot.mode, build: v.boot && v.boot.build }, r));
	}
}

(async () => {
	if (live) await liveRun(); else await localRun();
	fs.writeFileSync(path.join(out, 'results.json'), JSON.stringify(results, null, 1));
	const failed = results.filter((r) => !r.ok);
	log(failed.length ? `FAIL: ${failed.map((r) => r.name).join('; ')}` : `PASS: ${results.length} checks`);
	process.exit(failed.length ? 1 : 0);
})().catch((e) => {
	log(`FAIL: ${e.stack || e}`);
	server.close();
	process.exit(1);
});
