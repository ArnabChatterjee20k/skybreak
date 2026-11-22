// Local mock of the Appwrite endpoints the Skybreak client uses, for the Duo tests
// (no Appwrite credentials needed). Mirrors the behaviour that matters in a browser:
//  - CORS like Appwrite: only registered Web platform origins pass (others get 403
//    "Invalid Origin"), credentials allowed, X-Fallback-Cookies exposed and accepted.
//  - Email/password sessions: Set-Cookie a_session_<project> plus X-Fallback-Cookies;
//    a request carrying a live session cannot create another (401).
//  - TablesDB rows for database `skybreak`, tables skybreak_lobbies and
//    skybreak_signals with the README's columns, row security, create("users") on the
//    table, and Appwrite's rule that a client may only grant roles it holds.
//  - Queries: equal, orderAsc, orderDesc, limit (JSON syntax).
// The client does not use Realtime (signalling polls rows), so it is not mocked.
//
// Usage: node tools/net/appwrite_mock.js --port 8787 --origin http://127.0.0.1:8080 \
//          --users users.json [--latency 120]
//   users.json: [{"id": "...", "email": "...", "password": "...", "name": "..."}]
// As a module: require('./appwrite_mock').start({port, origins, users, latencyMs}).
'use strict';
const http = require('http');
const crypto = require('crypto');
const fs = require('fs');

const PROJECT = '6a113777000db893b12e';
const DATABASE = 'skybreak';
const COOKIE = `a_session_${PROJECT}`;
const TABLES = {
	skybreak_lobbies: {
		code: { type: 'string', size: 8, required: true },
		host: { type: 'string', size: 36, required: true },
		guest: { type: 'string', size: 36, required: false, default: '' },
		status: { type: 'string', size: 16, required: true },
		seed: { type: 'integer', required: true },
		ai_count: { type: 'integer', required: true },
	},
	skybreak_signals: {
		lobby: { type: 'string', size: 8, required: true },
		from: { type: 'string', size: 36, required: true },
		to: { type: 'string', size: 36, required: true },
		kind: { type: 'string', size: 16, required: true },
		payload: { type: 'string', size: 16384, required: true },
	},
};
const ALLOW_HEADERS = [
	'Accept', 'Origin', 'Cookie', 'Set-Cookie', 'Content-Type', 'Content-Range', 'Range',
	'X-Requested-With', 'X-Appwrite-Project', 'X-Appwrite-Key', 'X-Appwrite-Locale',
	'X-Appwrite-Mode', 'X-Appwrite-JWT', 'X-Appwrite-Response-Format', 'X-Appwrite-Timeout',
	'X-SDK-Version', 'X-SDK-Name', 'X-SDK-Language', 'X-SDK-Platform', 'X-Appwrite-ID',
	'X-Appwrite-Session', 'X-Fallback-Cookies',
].join(', ');

function start({ port = 0, origins = [], users = [], latencyMs = 0, log = () => {} } = {}) {
	const sessions = new Map(); // secret -> userId
	const rows = { skybreak_lobbies: new Map(), skybreak_signals: new Map() };
	const stats = { requests: 0, byRoute: {}, errors: {}, refusedOrigins: 0, permissionRefusals: 0 };
	let clock = Date.now();

	const isoNow = () => {
		clock = Math.max(clock + 1, Date.now());
		return new Date(clock).toISOString().replace('Z', '+00:00');
	};

	function userFor(req) {
		let secret = null;
		const cookie = req.headers.cookie || '';
		for (const part of cookie.split(';')) {
			const [k, v] = part.trim().split('=');
			if (k === COOKIE) secret = v;
		}
		const fallback = req.headers['x-fallback-cookies'];
		if (!secret && fallback) {
			try { secret = JSON.parse(fallback)[COOKIE]; } catch (e) { secret = null; }
		}
		const id = secret ? sessions.get(secret) : null;
		return id ? { id, secret, user: users.find((u) => u.id === id) } : null;
	}

	function roles(me) {
		return me ? ['any', 'users', `user:${me.id}`] : ['any', 'guests'];
	}

	function allowed(row, action, me) {
		const mine = roles(me);
		return row.$permissions.some((p) => {
			const m = /^(\w+)\("([^"]+)"\)$/.exec(p);
			return m && (m[1] === action || (m[1] === 'write' && action !== 'read')) && mine.includes(m[2]);
		});
	}

	function validate(table, data, partial) {
		const columns = TABLES[table];
		for (const key of Object.keys(data)) {
			if (!columns[key]) return `Invalid document structure: Unknown attribute: "${key}"`;
			const c = columns[key];
			const v = data[key];
			if (c.type === 'string' && (typeof v !== 'string' || v.length > c.size)) {
				return `Invalid document structure: Attribute "${key}" has invalid type. Value must be a valid string and no longer than ${c.size} chars`;
			}
			if (c.type === 'integer' && !Number.isInteger(v)) {
				return `Invalid document structure: Attribute "${key}" has invalid type. Value must be a valid integer`;
			}
		}
		if (!partial) {
			for (const [key, c] of Object.entries(columns)) {
				if (c.required && data[key] === undefined) return `Invalid document structure: Missing required attribute "${key}"`;
			}
		}
		return null;
	}

	function send(req, res, code, body, headers = {}) {
		const route = `${req.method} ${req.url.split('?')[0].replace(/\/rows\/[^/]+$/, '/rows/:id')}`;
		stats.byRoute[route] = (stats.byRoute[route] || 0) + 1;
		if (code >= 400) stats.errors[`${code} ${route}`] = (stats.errors[`${code} ${route}`] || 0) + 1;
		const out = code === 204 ? '' : JSON.stringify(body);
		const finish = () => {
			res.writeHead(code, { 'Content-Type': 'application/json', ...headers, ...cors(req) });
			res.end(out);
		};
		if (latencyMs > 0) setTimeout(finish, latencyMs); else finish();
	}

	function error(req, res, code, message, type) {
		send(req, res, code, { message, code, type, version: 'mock' });
	}

	function cors(req) {
		const origin = req.headers.origin;
		if (!origin) return {};
		return {
			'Access-Control-Allow-Origin': origin,
			'Access-Control-Allow-Credentials': 'true',
			'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE',
			'Access-Control-Allow-Headers': ALLOW_HEADERS,
			'Access-Control-Expose-Headers': 'X-Appwrite-Session, X-Fallback-Cookies',
			Vary: 'Origin',
		};
	}

	const server = http.createServer((req, res) => {
		stats.requests++;
		const origin = req.headers.origin;
		if (origin && !origins.includes(origin)) {
			stats.refusedOrigins++;
			// Appwrite answers an unregistered origin without CORS headers, so the browser blocks it.
			res.writeHead(403, { 'Content-Type': 'application/json' });
			res.end(JSON.stringify({ message: `Invalid Origin. Register your new client (${new URL(origin).hostname}) as a new Web platform on your project console dashboard`, code: 403, type: 'general_unknown_origin' }));
			return;
		}
		if (req.method === 'OPTIONS') {
			res.writeHead(204, cors(req));
			res.end();
			return;
		}
		let raw = '';
		req.on('data', (c) => { raw += c; });
		req.on('end', () => {
			let body = {};
			if (raw) {
				try { body = JSON.parse(raw); } catch (e) { return error(req, res, 400, 'Invalid JSON', 'general_argument_invalid'); }
			}
			if (req.headers['x-appwrite-project'] !== PROJECT) {
				return error(req, res, 404, 'Project with the requested ID could not be found.', 'project_not_found');
			}
			try { route(req, res, body); } catch (e) { log(`mock error ${e.stack}`); error(req, res, 500, String(e), 'general_unknown'); }
		});
	});

	function route(req, res, body) {
		const url = new URL(req.url, 'http://mock');
		const path = url.pathname;
		const me = userFor(req);
		log(`${req.method} ${path}${url.search ? '?' + decodeURIComponent(url.search).slice(0, 120) : ''} ${me ? me.id : '-'}`);
		if (path === '/v1/account/sessions/email' && req.method === 'POST') {
			if (me) return error(req, res, 401, 'Creation of a session is prohibited when a session is active.', 'user_session_already_exists');
			const user = users.find((u) => u.email === String(body.email || '').toLowerCase());
			if (!user || user.password !== body.password) {
				return error(req, res, 401, 'Invalid credentials. Please check the email and password.', 'user_invalid_credentials');
			}
			const secret = crypto.randomBytes(24).toString('hex');
			sessions.set(secret, user.id);
			return send(req, res, 201, { $id: crypto.randomBytes(10).toString('hex'), userId: user.id, secret: '', provider: 'email' }, {
				'Set-Cookie': `${COOKIE}=${secret}; path=/; httponly; samesite=none; secure`,
				'X-Fallback-Cookies': JSON.stringify({ [COOKIE]: secret }),
			});
		}
		if (path === '/v1/account' && req.method === 'GET') {
			if (!me) return error(req, res, 401, 'User (role: guests) missing scope (account)', 'general_unauthorized_scope');
			return send(req, res, 200, { $id: me.id, name: me.user.name, email: me.user.email, labels: ['skybreak'] });
		}
		if (path === '/v1/account/sessions/current') {
			if (!me) return error(req, res, 401, 'User (role: guests) missing scope (account)', 'general_unauthorized_scope');
			if (req.method === 'PATCH') return send(req, res, 200, { $id: 'current', userId: me.id });
			if (req.method === 'DELETE') {
				sessions.delete(me.secret);
				return send(req, res, 204, null);
			}
		}
		const m = /^\/v1\/tablesdb\/([^/]+)\/tables\/([^/]+)\/rows(?:\/([^/]+))?$/.exec(path);
		if (m) return rowsRoute(req, res, body, url, me, m[1], m[2], m[3]);
		return error(req, res, 404, `Route not found: ${req.method} ${path}`, 'general_route_not_found');
	}

	function rowsRoute(req, res, body, url, me, db, table, id) {
		if (db !== DATABASE) return error(req, res, 404, 'Database not found', 'database_not_found');
		if (!TABLES[table]) return error(req, res, 404, 'Table with the requested ID could not be found.', 'table_not_found');
		const store = rows[table];
		if (!id && req.method === 'POST') {
			if (!me) return error(req, res, 401, 'The current user is not authorized to perform the requested action.', 'user_unauthorized');
			const data = { ...(body.data || {}) };
			for (const [k, c] of Object.entries(TABLES[table])) if (data[k] === undefined && c.default !== undefined) data[k] = c.default;
			const invalid = validate(table, data, false);
			if (invalid) return error(req, res, 400, invalid, 'document_invalid_structure');
			const permissions = body.permissions || [];
			const mine = roles(me);
			for (const p of permissions) {
				const r = /^\w+\("([^"]+)"\)$/.exec(p);
				if (!r || !mine.includes(r[1])) {
					stats.permissionRefusals++;
					return error(req, res, 401, `Permissions must be one of: (${mine.map((x) => `"${x}"`).join(', ')})`, 'user_unauthorized');
				}
			}
			const rowId = !body.rowId || body.rowId === 'unique()' ? crypto.randomBytes(10).toString('hex') : body.rowId;
			if (store.has(rowId)) return error(req, res, 409, 'Row with the requested ID already exists.', 'row_already_exists');
			const now = isoNow();
			const row = { $id: rowId, $sequence: store.size + 1, $tableId: table, $databaseId: db, $createdAt: now, $updatedAt: now, $permissions: permissions, ...data };
			store.set(rowId, row);
			return send(req, res, 201, row);
		}
		if (!id && req.method === 'GET') {
			let list = [...store.values()].filter((r) => allowed(r, 'read', me));
			let limit = 25;
			for (const q of url.searchParams.getAll('queries[]')) {
				let query;
				try { query = JSON.parse(q); } catch (e) { return error(req, res, 400, `Invalid query: ${q}`, 'general_query_invalid'); }
				if (query.method === 'equal') list = list.filter((r) => query.values.includes(r[query.attribute]));
				else if (query.method === 'orderAsc') list.sort((a, b) => (a[query.attribute] < b[query.attribute] ? -1 : 1));
				else if (query.method === 'orderDesc') list.sort((a, b) => (a[query.attribute] > b[query.attribute] ? -1 : 1));
				else if (query.method === 'limit') limit = query.values[0];
				else return error(req, res, 400, `Invalid query method: ${query.method}`, 'general_query_invalid');
			}
			return send(req, res, 200, { total: list.length, rows: list.slice(0, limit) });
		}
		const row = id ? store.get(id) : null;
		if (!row || !allowed(row, 'read', me)) {
			return error(req, res, 404, 'Row with the requested ID could not be found.', 'row_not_found');
		}
		if (req.method === 'GET') return send(req, res, 200, row);
		if (req.method === 'PATCH') {
			if (!allowed(row, 'update', me)) return error(req, res, 401, 'The current user is not authorized to perform the requested action.', 'user_unauthorized');
			const invalid = validate(table, body.data || {}, true);
			if (invalid) return error(req, res, 400, invalid, 'document_invalid_structure');
			Object.assign(row, body.data || {}, { $updatedAt: isoNow() });
			return send(req, res, 200, row);
		}
		if (req.method === 'DELETE') {
			if (!allowed(row, 'delete', me)) return error(req, res, 401, 'The current user is not authorized to perform the requested action.', 'user_unauthorized');
			store.delete(id);
			return send(req, res, 204, null);
		}
		return error(req, res, 405, 'Method not allowed', 'general_route_not_found');
	}

	return new Promise((resolve) => {
		server.listen(port, '127.0.0.1', () => resolve({
			server, stats, rows,
			url: `http://127.0.0.1:${server.address().port}/v1`,
			close: () => new Promise((r) => server.close(r)),
		}));
	});
}

module.exports = { start, PROJECT, TABLES };

if (require.main === module) {
	const args = process.argv.slice(2);
	const arg = (name, fallback) => {
		const i = args.indexOf(`--${name}`);
		return i >= 0 ? args[i + 1] : fallback;
	};
	const users = JSON.parse(fs.readFileSync(arg('users'), 'utf8'));
	start({
		port: Number(arg('port', 8787)),
		origins: [arg('origin', 'http://127.0.0.1:8080')],
		users,
		latencyMs: Number(arg('latency', 0)),
		log: (l) => console.log(l),
	}).then((m) => console.log(`Appwrite mock on ${m.url}`));
}
