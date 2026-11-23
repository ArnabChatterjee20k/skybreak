// Skybreak boot cache: keeps the web build in Cache Storage and updates it from version.json.
// SkybreakCache.boot(ui) checks version.json (3 s timeout), downloads only the files whose
// SHA-256 changed into "skybreak-<build>", then writes the pointer the service worker
// (sw.js) reads: that single write swaps builds, so a half-finished update leaves the
// cached build as it was. Resolves {mode, build} once the engine may load:
// "cached" (current or offline), "updated", "network" (no cache, no room or no SW).
'use strict';

const SkybreakCache = (function () {
	const PREFIX = 'skybreak-';
	const META = 'skybreak-meta';
	const POINTER = 'pointer.json';
	const PENDING = 'pending.json';
	const VERSION_TIMEOUT_MS = 3000;
	const CONTROLLER_TIMEOUT_MS = 4000;
	// Files the worker never serves from the cache.
	const UNCACHED = new Set(['version.json', 'sw.js']);
	// Room kept free on top of an update's bytes.
	const QUOTA_MARGIN = 8 << 20;
	let lastEstimate = null;

	function key(rel) {
		return new URL(rel, document.baseURI).href;
	}

	// A cached request's path relative to the page's folder.
	function relative(url) {
		return decodeURIComponent(new URL(url).pathname.slice(new URL('.', document.baseURI).pathname.length));
	}

	// Files fetched before the game starts; zone packs come per match (the worker keeps them).
	function precached(files) {
		return Object.keys(files).filter((f) => !UNCACHED.has(f) && !/^zones\/[^/]+\.pck$/.test(f));
	}

	async function readPointer() {
		try {
			const res = await (await caches.open(META)).match(key(POINTER));
			return res ? await res.json() : null;
		} catch (e) {
			return null;
		}
	}

	async function writePointer(v) {
		const body = JSON.stringify({ build: v.build, files: v.files, sizes: v.sizes || {} });
		await (await caches.open(META)).put(key(POINTER),
			new Response(body, { headers: { 'Content-Type': 'application/json' } }));
	}

	// Marks the build being filled, so a worker activating meanwhile keeps its cache.
	async function writePending(build) {
		await (await caches.open(META)).put(key(PENDING),
			new Response(JSON.stringify({ build }), { headers: { 'Content-Type': 'application/json' } }));
	}

	async function clearPending() {
		await (await caches.open(META)).delete(key(PENDING));
	}

	async function clearPointer() {
		await (await caches.open(META)).delete(key(POINTER));
	}

	// Deletes build caches other than keep (names without the prefix).
	async function deleteBuilds(keep) {
		for (const name of await caches.keys()) {
			if (name.startsWith(PREFIX) && name !== META && !keep.includes(name.slice(PREFIX.length))) {
				await caches.delete(name);
			}
		}
	}

	async function fetchVersion() {
		const ctl = new AbortController();
		const timer = setTimeout(() => ctl.abort(), VERSION_TIMEOUT_MS);
		try {
			const res = await fetch('version.json?t=' + Date.now(), { cache: 'no-store', signal: ctl.signal });
			if (!res.ok) {
				return null;
			}
			const v = await res.json();
			return v && typeof v.build === 'string' && v.files && typeof v.files === 'object' ? v : null;
		} catch (e) {
			return null;
		} finally {
			clearTimeout(timer);
		}
	}

	async function controller() {
		const reg = await navigator.serviceWorker.register('sw.js', { updateViaCache: 'none' });
		// Checks sw.js now, so a newer worker replaces an older one on this visit.
		reg.update().catch(() => {});
		if (navigator.serviceWorker.controller) {
			return navigator.serviceWorker.controller;
		}
		return new Promise((resolve) => {
			const timer = setTimeout(() => resolve(navigator.serviceWorker.controller), CONTROLLER_TIMEOUT_MS);
			navigator.serviceWorker.addEventListener('controllerchange', () => {
				clearTimeout(timer);
				resolve(navigator.serviceWorker.controller);
			}, { once: true });
		});
	}

	async function hasAll(build, files) {
		const cache = await caches.open(PREFIX + build);
		const have = new Set((await cache.keys()).map((r) => r.url));
		return precached(files).every((f) => have.has(key(f)));
	}

	async function sha256(buffer) {
		const d = new Uint8Array(await crypto.subtle.digest('SHA-256', buffer));
		return Array.from(d, (b) => b.toString(16).padStart(2, '0')).join('');
	}

	// Downloads one file, counting bytes as they arrive; rejects unless its SHA-256 matches.
	async function download(rel, sha, onBytes) {
		const res = await fetch(rel + '?sbv=' + sha.slice(0, 12), { cache: 'no-store' });
		if (!res.ok) {
			throw new Error(rel + ': HTTP ' + res.status);
		}
		const reader = res.body.getReader();
		const chunks = [];
		for (;;) {
			const { done, value } = await reader.read();
			if (done) {
				break;
			}
			chunks.push(value);
			onBytes(value.byteLength);
		}
		const blob = new Blob(chunks);
		if (await sha256(await blob.arrayBuffer()) !== sha) {
			throw new Error(rel + ': SHA-256 differs from version.json');
		}
		const type = res.headers.get('Content-Type') || 'application/octet-stream';
		return new Response(blob, { headers: { 'Content-Type': type, 'Content-Length': String(blob.size) } });
	}

	async function fits(bytes) {
		if (!navigator.storage || !navigator.storage.estimate) {
			return true;
		}
		const { usage, quota } = await navigator.storage.estimate();
		lastEstimate = { usage, quota };
		return !quota || usage + bytes + QUOTA_MARGIN <= quota;
	}

	function isQuotaError(e) {
		return e && (e.name === 'QuotaExceededError' || /quota/i.test(e.message || ''));
	}

	// Fills skybreak-<v.build> (reusing unchanged and already-downloaded files), then swaps.
	async function update(ptr, v, ui) {
		const files = precached(v.files);
		const target = await caches.open(PREFIX + v.build);
		const old = ptr ? await caches.open(PREFIX + ptr.build) : null;
		const have = new Set((await target.keys()).map((r) => r.url));
		const copy = [];
		const fetchList = [];
		for (const f of files) {
			if (have.has(key(f))) {
				continue;
			}
			const reusable = old && ptr.files[f] === v.files[f] ? await old.match(key(f)) : null;
			if (reusable) {
				copy.push([f, reusable]);
			} else {
				fetchList.push(f);
			}
		}
		const sizes = v.sizes || {};
		const total = fetchList.reduce((n, f) => n + (sizes[f] || 0), 0);
		if (navigator.storage && navigator.storage.persist) {
			await navigator.storage.persist().catch(() => false);
		}
		if (!await fits(total)) {
			await deleteBuilds(ptr ? [ptr.build, v.build] : [v.build]);
			if (!await fits(total)) {
				return { mode: 'nospace', total, estimate: lastEstimate };
			}
		}
		let done = 0;
		await writePending(v.build);
		try {
			for (const [f, res] of copy) {
				await target.put(key(f), res);
			}
			ui.progress(0, total);
			for (const f of fetchList) {
				const res = await download(f, v.files[f], (n) => {
					done += n;
					ui.progress(done, total);
				});
				await target.put(key(f), res);
			}
		} catch (e) {
			// The estimate can be optimistic; a full disk is a quota case, not a broken update.
			if (!isQuotaError(e)) {
				throw e;
			}
			await caches.delete(PREFIX + v.build);
			await clearPending();
			return { mode: 'nospace', total, estimate: lastEstimate, why: e.message };
		}
		// Zone packs the old build kept and the new one still lists.
		if (old) {
			for (const req of await old.keys()) {
				const f = relative(req.url);
				if (/^zones\/[^/]+\.pck$/.test(f) && v.files[f] && v.files[f] === ptr.files[f]) {
					await target.put(req, await old.match(req));
				}
			}
		}
		await writePointer(v);
		await clearPending();
		await deleteBuilds([v.build]);
		return { mode: 'updated', fetched: fetchList, copied: copy.length, total };
	}

	async function boot(ui) {
		const t0 = performance.now();
		const result = (r) => Object.assign(r, { ms: Math.round(performance.now() - t0) });
		if (!('serviceWorker' in navigator) || !window.caches || !window.isSecureContext) {
			return result({ mode: 'network', why: 'no service worker' });
		}
		let ptr = null;
		try {
			if (!await controller()) {
				return result({ mode: 'network', why: 'service worker not in control' });
			}
			ptr = await readPointer();
			if (ptr && !await hasAll(ptr.build, ptr.files)) {
				ptr = null;
			}
		} catch (e) {
			return result({ mode: 'network', why: String(e) });
		}
		const v = await fetchVersion();
		if (!v) {
			return result(ptr ? { mode: 'cached', build: ptr.build, why: 'no version.json in 3 s' }
				: { mode: 'network', why: 'no version.json and no cache' });
		}
		if (ptr && ptr.build === v.build) {
			return result({ mode: 'cached', build: ptr.build });
		}
		ui.status(ptr ? 'Updating…' : 'Downloading…');
		try {
			const r = await update(ptr, v, ui);
			if (r.mode === 'nospace') {
				// Too little storage: drop the cache and load from the network.
				await clearPointer();
				await deleteBuilds([]);
				if (ptr && ptr.files['index.html'] !== v.files['index.html']) {
					return result({ mode: 'reload', why: 'no room; page changed' });
				}
				return result({ mode: 'network', why: 'not enough storage for ' + r.total + ' bytes', estimate: r.estimate });
			}
			if (ptr && ptr.files['index.html'] !== v.files['index.html']) {
				return result(Object.assign(r, { mode: 'reload', build: v.build }));
			}
			return result(Object.assign(r, { build: v.build }));
		} catch (e) {
			console.warn('Skybreak update failed, keeping the cached build:', e);
			return result(ptr ? { mode: 'cached', build: ptr.build, why: 'update failed: ' + e.message }
				: { mode: 'network', why: 'first download failed: ' + e.message });
		}
	}

	return { boot };
}());
