// Skybreak service worker: serves the web build from Cache Storage.
// The page (boot_cache.js) fills caches named "skybreak-<build>" and then writes the
// pointer {build, files, sizes} to the meta cache; that write is the atomic swap.
// This worker only reads the pointer: it serves the current build's cached files,
// passes everything else to the network and keeps on-demand zone packs it fetched.
'use strict';

const PREFIX = 'skybreak-';
const META = 'skybreak-meta';
const POINTER = 'pointer.json';
// The build an update is filling right now (boot_cache.js); its cache is kept.
const PENDING = 'pending.json';

// A new worker takes over at once, even from an older or broken one, and drops build caches the
// pointer no longer names (left by an update that stopped halfway, or by older workers).
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil((async () => {
	await self.clients.claim();
	const ptr = await pointer();
	const pending = await readMeta(PENDING);
	const keep = [ptr && ptr.build, pending && pending.build].filter(Boolean).map((b) => PREFIX + b);
	for (const name of await caches.keys()) {
		if (name.startsWith(PREFIX) && name !== META && !keep.includes(name)) {
			await caches.delete(name);
		}
	}
})()));

// Path relative to the worker's folder ("" for the folder itself).
function relativePath(url) {
	const scope = new URL(self.registration.scope);
	if (url.origin !== scope.origin || !url.pathname.startsWith(scope.pathname)) {
		return null;
	}
	return decodeURIComponent(url.pathname.slice(scope.pathname.length));
}

async function readMeta(name) {
	try {
		const meta = await caches.open(META);
		const res = await meta.match(new URL(name, self.registration.scope).href);
		return res ? await res.json() : null;
	} catch (e) {
		return null;
	}
}

function pointer() {
	return readMeta(POINTER);
}

// Zone packs are fetched per match and named by content hash, so they never go stale.
function isZonePack(rel) {
	return /^zones\/[^/]+\.pck$/.test(rel);
}

async function keepZonePack(cache, url, res, size) {
	try {
		if (navigator.storage && navigator.storage.estimate) {
			const { usage, quota } = await navigator.storage.estimate();
			if (quota && usage + size * 1.1 > quota) {
				return;
			}
		}
		await cache.put(url, res);
	} catch (e) {
		// Quota or storage errors: the pack still reached the game from the network.
	}
}

async function respond(request, rel) {
	const ptr = await pointer();
	if (!ptr || !ptr.files || ptr.files[rel] === undefined) {
		return fetch(request);
	}
	const cache = await caches.open(PREFIX + ptr.build);
	const key = new URL(rel, self.registration.scope).href;
	const hit = await cache.match(key);
	if (hit) {
		return hit;
	}
	const res = await fetch(request);
	if (res.ok && res.status === 200 && isZonePack(rel)) {
		const size = (ptr.sizes && ptr.sizes[rel]) || 0;
		keepZonePack(cache, key, res.clone(), size);
	}
	return res;
}

self.addEventListener('fetch', (event) => {
	const request = event.request;
	if (request.method !== 'GET' || request.headers.has('range')) {
		return;
	}
	const url = new URL(request.url);
	let rel = relativePath(url);
	// sw.js and the updater's downloads ("?sbv=") always come from the network.
	if (rel === null || rel === 'sw.js' || url.searchParams.has('sbv')) {
		return;
	}
	// version.json too; offline it answers "{}" (no build) so the page boots the cache without a console error.
	if (rel === 'version.json') {
		event.respondWith(fetch(request).catch(() => new Response('{}', { headers: { 'Content-Type': 'application/json' } })));
		return;
	}
	if (rel === '') {
		rel = 'index.html';
	}
	event.respondWith(respond(request, rel));
});
