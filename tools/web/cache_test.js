// Tests the web build's boot cache (sw.js + boot_cache.js) in headless Chromium, like a
// player relaunching the browser between visits (one persistent profile, one origin):
//  a) first load caches everything      b) server stopped: boots from cache, reaches a match
//  c) version.json delayed past 3 s: boots the cached build at ~3 s
//  d) new build with one changed file: only that file is downloaded, the new build runs
//  e) update interrupted halfway (connection cut, then browser closed): old build still boots
//  f) storage quota too small: loads from the network, no cache
// Usage: node tools/web/cache_test.js [build dir] [out dir]   (build from tools/web/build_web.sh)
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');

const buildA = path.resolve(process.argv[2] || 'build/web');
const out = path.resolve(process.argv[3] || 'reports/web/cache');
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'skybreak-cache-'));
const profile = path.join(work, 'profile');
const writeVersion = path.join(__dirname, 'write_version.sh');
const types = {
	'.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm',
	'.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json',
};

// Server state the scenarios change.
const srv = { root: buildA, versionDelay: 0, cut: null, log: [] };
const sockets = new Set();
let server = null;
let port = 0;

function handle(req, res) {
	const u = new URL(req.url, 'http://x');
	const rel = decodeURIComponent(u.pathname).replace(/^\//, '') || 'index.html';
	const file = path.join(srv.root, rel);
	if (!file.startsWith(srv.root) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
		res.writeHead(404);
		res.end();
		return;
	}
	const size = fs.statSync(file).size;
	const entry = { rel, sbv: u.searchParams.has('sbv'), bytes: 0, t: Date.now() };
	srv.log.push(entry);
	const send = () => {
		const headers = { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Content-Length': size };
		if (rel === 'version.json') headers['Cache-Control'] = 'no-cache';
		res.writeHead(200, headers);
		if (srv.cut && srv.cut.rel === rel) {
			// Sends the first half, then drops the connection (or stalls, for a browser kill).
			const half = Math.floor(size * srv.cut.fraction);
			const stream = fs.createReadStream(file, { start: 0, end: half - 1 });
			stream.on('data', (c) => { entry.bytes += c.length; });
			stream.on('end', () => {
				srv.cut.reached = true;
				if (srv.cut.mode === 'drop') req.socket.destroy();
			});
			stream.pipe(res, { end: false });
			return;
		}
		const stream = fs.createReadStream(file);
		stream.on('data', (c) => { entry.bytes += c.length; });
		stream.pipe(res);
	};
	if (rel === 'version.json' && srv.versionDelay > 0) setTimeout(send, srv.versionDelay); else send();
}

async function startServer() {
	server = http.createServer(handle);
	server.on('connection', (s) => { sockets.add(s); s.on('close', () => sockets.delete(s)); });
	await new Promise((r) => server.listen(port, '127.0.0.1', r));
	port = server.address().port;
}

async function stopServer() {
	if (!server) return;
	for (const s of sockets) s.destroy();
	await new Promise((r) => server.close(r));
	server = null;
}

// A copy of a build (hard links) with one file replaced and its own version.json.
function derive(from, name, rel, transform) {
	const dir = path.join(work, name);
	execFileSync('cp', ['-al', from, dir]);
	const target = path.join(dir, rel);
	const data = transform(fs.readFileSync(target));
	fs.rmSync(target);
	fs.writeFileSync(target, data);
	fs.rmSync(path.join(dir, 'version.json'));
	execFileSync(writeVersion, [dir, name]);
	return dir;
}

const mb = (b) => (b / 1048576).toFixed(1) + ' MB';
const results = [];
let context = null;

async function launch(opts = {}) {
	context = await chromium.launchPersistentContext(profile, {
		viewport: { width: 1280, height: 720 },
		args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
	});
	if (opts.quota) {
		const page = context.pages()[0] || await context.newPage();
		const cdp = await context.newCDPSession(page);
		await cdp.send('Storage.overrideQuotaForOrigin', { origin: `http://127.0.0.1:${port}`, quotaSize: opts.quota });
	}
	return context;
}

async function close() {
	if (context) await context.close();
	context = null;
}

// Opens the game; returns the page, the boot results (one per page load) and timings.
async function open(opts = {}) {
	const page = context.pages()[0] || await context.newPage();
	const errors = [];
	const boots = [];
	page.on('console', (m) => {
		const t = m.text();
		if (/GL Driver Message/.test(t)) return;
		const b = t.match(/^Skybreak boot: (.*)$/);
		if (b) boots.push(JSON.parse(b[1]));
		if (m.type() === 'error' && !(opts.allowErrors || []).some((re) => re.test(t))) errors.push(t);
	});
	page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
	const t0 = Date.now();
	await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: 'commit' });
	if (opts.untilStart === false) return { page, boots, errors, t0 };
	await page.waitForSelector('#start', { state: 'visible', timeout: 300000 });
	const startMs = Date.now() - t0;
	return { page, boots, errors, t0, startMs };
}

// Click to start, menu -> vs AI -> zone -> Fight, a few seconds of play; screenshot.
// The match has started once the game asks for zones/manifest.json (ZoneBakeDownload).
async function playMatch(run, shotName) {
	const { page } = run;
	let manifest = 0;
	page.on('request', (r) => { if (/\/zones\/manifest\.json$/.test(new URL(r.url()).pathname)) manifest++; });
	const tClick = Date.now();
	await page.click('#start');
	await page.waitForSelector('#cover', { state: 'detached', timeout: 180000 });
	const engineMs = Date.now() - tClick;
	await page.waitForTimeout(8000);
	await page.mouse.click(5, 5);
	// Splash, main menu (VS AI), character select (confirm), zone select (fight), as descend_smoke_test.js.
	for (const step of ['Enter', 'Enter', 'click:1090:686', 'click:1105:657']) {
		if (step.startsWith('click:')) {
			const [, x, y] = step.split(':').map(Number);
			await page.mouse.click(x, y);
		} else {
			await page.keyboard.press(step);
		}
		await page.waitForTimeout(4000);
	}
	const tFight = Date.now();
	while (manifest === 0 && Date.now() - tFight < 30000) await page.waitForTimeout(500);
	if (manifest === 0) throw new Error('no match: the game never asked for zones/manifest.json');
	await page.waitForTimeout(15000);
	for (const k of ['KeyW', 'KeyQ', 'Space', 'KeyD', 'KeyF']) {
		await page.keyboard.down(k);
		await page.waitForTimeout(400);
		await page.keyboard.up(k);
	}
	await page.screenshot({ path: path.join(out, shotName), timeout: 120000 });
	return { engineMs, matchMs: Date.now() - tFight };
}

// What the page's caches hold: pointer build and cached paths per build cache.
async function cacheState(page) {
	return page.evaluate(async () => {
		const state = { pointer: null, caches: {} };
		const meta = await caches.open('skybreak-meta');
		const p = await meta.match(new URL('pointer.json', location.href).href);
		if (p) state.pointer = (await p.json()).build;
		for (const name of await caches.keys()) {
			if (name === 'skybreak-meta') continue;
			const keys = await (await caches.open(name)).keys();
			state.caches[name] = keys.map((r) => new URL(r.url).pathname.slice(1)).sort();
		}
		return state;
	});
}

function precached(version) {
	return Object.keys(version.files).filter((f) => f !== 'sw.js' && f !== 'version.json' && !/^zones\/.*\.pck$/.test(f)).sort();
}

function downloads(fromIndex) {
	return srv.log.slice(fromIndex).filter((e) => e.rel !== 'version.json');
}

function check(name, ok, detail) {
	console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}: ${detail}`);
	return ok;
}

async function scenario(id, title, fn) {
	console.log(`\n== ${id}) ${title}`);
	const t0 = Date.now();
	let pass = false;
	let notes = {};
	try {
		[pass, notes] = await fn();
	} catch (e) {
		console.log(`FAIL ${id}: ${e.stack || e}`);
	}
	await close();
	if (!server) await startServer();
	results.push({ id, title, pass, seconds: Math.round((Date.now() - t0) / 100) / 10, ...notes });
	console.log(`${pass ? 'PASS' : 'FAIL'} ${id}) ${title}`);
}

(async () => {
	fs.mkdirSync(out, { recursive: true });
	const versionA = JSON.parse(fs.readFileSync(path.join(buildA, 'version.json')));
	// Build B: one changed file (a marker in index.html; a page change also exercises the reload).
	const buildB = derive(buildA, 'B', 'index.html', (b) => Buffer.from(b.toString().replace('<head>', '<head>\n<meta name="skybreak-test-build" content="B">')));
	const versionB = JSON.parse(fs.readFileSync(path.join(buildB, 'version.json')));
	// Build C: a changed index.pck (never booted; its download is cut halfway).
	const buildC = derive(buildB, 'C', 'index.pck', (b) => Buffer.concat([b, Buffer.from('skybreak cache test C')]));
	await startServer();

	await scenario('a', 'first load caches everything', async () => {
		await launch();
		const before = srv.log.length;
		const run = await open();
		const boot = run.boots[0] || {};
		const state0 = await cacheState(run.page);
		const want = precached(versionA);
		const got = state0.caches[`skybreak-${versionA.build}`] || [];
		const play = await playMatch(run, 'a_first_load_match.png');
		const state1 = await cacheState(run.page);
		const dl = downloads(before);
		// The first page load (index.html, boot_cache.js) comes from the network before the worker exists.
		const firstPage = ['index.html', 'boot_cache.js'];
		const fetchedTwice = want.filter((f) => dl.filter((e) => e.rel === f && e.sbv).length !== 1
			|| dl.some((e) => e.rel === f && !e.sbv && !firstPage.includes(f)));
		const zones = (state1.caches[`skybreak-${versionA.build}`] || []).filter((f) => /^zones\/.*\.pck$/.test(f));
		const ok = [
			check('a', boot.mode === 'updated', `boot ${JSON.stringify(boot)}`),
			check('a', state0.pointer === versionA.build, `pointer ${state0.pointer}`),
			check('a', want.every((f) => got.includes(f)), `${got.length}/${want.length} build files cached`),
			check('a', fetchedTwice.length === 0, `each build file downloaded once by the updater, none by the engine (${fetchedTwice.join(', ') || 'yes'})`),
			check('a', zones.length >= 1, `zone pack cached on demand: ${zones.join(', ') || 'none'}`),
			check('a', run.errors.length === 0, `${run.errors.length} console errors ${run.errors.slice(0, 3).join(' | ')}`),
		].every(Boolean);
		return [ok, { boot, startMs: run.startMs, ...play, downloaded: mb(dl.reduce((n, e) => n + e.bytes, 0)), zones }];
	});

	await scenario('b', 'offline (server stopped) boots from cache and reaches a match', async () => {
		await stopServer();
		await launch();
		const run = await open();
		const boot = run.boots[0] || {};
		const play = await playMatch(run, 'b_offline_match.png');
		const ok = [
			check('b', boot.mode === 'cached' && boot.build === versionA.build, `boot ${JSON.stringify(boot)}`),
			check('b', run.errors.length === 0, `${run.errors.length} console errors ${run.errors.slice(0, 3).join(' | ')}`),
		].every(Boolean);
		await startServer();
		return [ok, { boot, startMs: run.startMs, ...play }];
	});

	await scenario('c', 'version.json delayed 6 s boots the cached build at ~3 s', async () => {
		srv.versionDelay = 6000;
		await launch();
		const before = srv.log.length;
		const run = await open();
		const boot = run.boots[0] || {};
		const play = await playMatch(run, 'c_slow_version_match.png');
		srv.versionDelay = 0;
		const dl = downloads(before).filter((e) => e.sbv);
		const ok = [
			check('c', boot.mode === 'cached' && boot.build === versionA.build, `boot ${JSON.stringify(boot)}`),
			check('c', boot.ms >= 2900 && boot.ms < 4500, `decided at ${boot.ms} ms, start button at ${run.startMs} ms`),
			check('c', dl.length === 0, `${dl.length} build downloads`),
			check('c', run.errors.length === 0, `${run.errors.length} console errors ${run.errors.slice(0, 3).join(' | ')}`),
		].every(Boolean);
		return [ok, { boot, startMs: run.startMs, ...play }];
	});

	await scenario('d', 'new build with one changed file: only that file is downloaded', async () => {
		srv.root = buildB;
		await launch();
		const before = srv.log.length;
		const run = await open();
		await run.page.waitForFunction(() => window.skybreakBootResult && window.skybreakBootResult.mode !== 'reload');
		const dl = downloads(before).filter((e) => e.sbv);
		const marker = await run.page.evaluate(() => {
			const m = document.querySelector('meta[name="skybreak-test-build"]');
			return m ? m.content : null;
		});
		const state = await cacheState(run.page);
		const play = await playMatch(run, 'd_new_build_match.png');
		const ok = [
			check('d', run.boots.length === 2 && run.boots[0].mode === 'reload' && run.boots[1].mode === 'cached'
				&& run.boots[1].build === versionB.build, `boots ${JSON.stringify(run.boots)}`),
			check('d', dl.length === 1 && dl[0].rel === 'index.html', `downloaded: ${dl.map((e) => `${e.rel} (${e.bytes} B)`).join(', ')}`),
			check('d', marker === 'B', `page marker ${marker}`),
			check('d', state.pointer === versionB.build && Object.keys(state.caches).length === 1,
				`pointer ${state.pointer}, caches ${Object.keys(state.caches).join(', ')}`),
			check('d', (state.caches['skybreak-B'] || []).some((f) => /^zones\/.*\.pck$/.test(f)), 'zone pack carried over'),
			check('d', run.errors.length === 0, `${run.errors.length} console errors ${run.errors.slice(0, 3).join(' | ')}`),
		].every(Boolean);
		return [ok, { boots: run.boots, startMs: run.startMs, ...play, downloaded: dl.map((e) => `${e.rel} ${e.bytes} B`) }];
	});

	await scenario('e', 'update interrupted halfway: the old build still boots', async () => {
		// e1: the connection drops halfway through index.pck.
		srv.root = buildC;
		srv.cut = { rel: 'index.pck', fraction: 0.5, mode: 'drop' };
		await launch();
		let run = await open();
		const boot1 = run.boots[0] || {};
		const state1 = await cacheState(run.page);
		const play = await playMatch(run, 'e_interrupted_match.png');
		// The cut download itself is logged by the browser; that is the fault under test.
		const errors1 = run.errors.filter((t) => !/ERR_CONTENT_LENGTH_MISMATCH/.test(t));
		await close();
		// e2: the browser is closed halfway through index.pck, then relaunched offline.
		srv.cut = { rel: 'index.pck', fraction: 0.5, mode: 'stall' };
		await launch();
		run = await open({ untilStart: false });
		const t = Date.now();
		while (!srv.cut.reached && Date.now() - t < 120000) await new Promise((r) => setTimeout(r, 200));
		const reached = srv.cut.reached;
		await close();
		srv.cut = null;
		await stopServer();
		await launch();
		run = await open();
		const boot2 = run.boots[0] || {};
		const state2 = await cacheState(run.page);
		const engine2 = await (async () => {
			await run.page.click('#start');
			await run.page.waitForSelector('#cover', { state: 'detached', timeout: 180000 });
			await run.page.waitForTimeout(6000);
			await run.page.screenshot({ path: path.join(out, 'e_after_browser_kill_menu.png') });
			return true;
		})();
		await startServer();
		srv.root = buildB;
		const ok = [
			check('e1', boot1.mode === 'cached' && boot1.build === versionB.build && /update failed/.test(boot1.why || ''),
				`boot ${JSON.stringify(boot1)}`),
			check('e1', state1.pointer === versionB.build, `pointer still ${state1.pointer}`),
			check('e1', errors1.length === 0, `${errors1.length} console errors ${errors1.slice(0, 3).join(' | ')}`),
			check('e2', reached, 'browser closed after half of index.pck arrived'),
			check('e2', boot2.mode === 'cached' && boot2.build === versionB.build, `boot ${JSON.stringify(boot2)}`),
			check('e2', state2.pointer === versionB.build, `pointer ${state2.pointer}, caches ${Object.keys(state2.caches).join(', ')}`),
			check('e2', engine2 && run.errors.length === 0, `engine started, ${run.errors.length} console errors ${run.errors.slice(0, 3).join(' | ')}`),
		].every(Boolean);
		return [ok, { boot1, boot2, ...play }];
	});

	await scenario('f', 'storage quota too small: plain network load', async () => {
		fs.rmSync(profile, { recursive: true, force: true });
		srv.root = buildA;
		await launch({ quota: 20 << 20 });
		const run = await open();
		const boot = run.boots[0] || {};
		const state = await cacheState(run.page);
		await run.page.click('#start');
		await run.page.waitForSelector('#cover', { state: 'detached', timeout: 180000 });
		await run.page.waitForTimeout(6000);
		await run.page.screenshot({ path: path.join(out, 'f_small_quota_menu.png') });
		const ok = [
			check('f', boot.mode === 'network' && /not enough storage/.test(boot.why || ''), `boot ${JSON.stringify(boot)}`),
			check('f', state.pointer === null && Object.keys(state.caches).length === 0, `caches ${JSON.stringify(state.caches)}`),
			check('f', run.errors.length === 0, `${run.errors.length} console errors ${run.errors.slice(0, 3).join(' | ')}`),
		].every(Boolean);
		return [ok, { boot, startMs: run.startMs }];
	});

	await stopServer();
	fs.writeFileSync(path.join(out, 'results.json'), JSON.stringify(results, null, '\t') + '\n');
	fs.rmSync(work, { recursive: true, force: true });
	const failed = results.filter((r) => !r.pass);
	console.log(`\n${results.length - failed.length}/${results.length} cache scenarios passed`);
	process.exit(failed.length ? 1 : 0);
})().catch(async (e) => {
	console.error(e);
	process.exit(1);
});
