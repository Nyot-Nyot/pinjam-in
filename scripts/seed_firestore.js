#!/usr/bin/env node
// Simple script to write sample LoanItem documents into the Firestore emulator
// Uses the emulator REST endpoint at http://localhost:8080

const fs = require("fs");
const path = require("path");
const fetch = global.fetch || require("node-fetch");
const net = require("net");

function projectIdFromFirebaseJson() {
	try {
		const p = path.resolve(process.cwd(), "firebase.json");
		if (!fs.existsSync(p)) return null;
		const j = JSON.parse(fs.readFileSync(p, "utf8"));
		return j.projectId || j["projects"]?.default || null;
	} catch (e) {
		return null;
	}
}

// CLI args or env override
function parseArgs(args) {
	const out = {};
	for (let i = 0; i < args.length; i++) {
		const a = args[i];
		if (a.startsWith("--")) {
			const key = a.slice(2);
			const next = args[i + 1];
			if (next && !next.startsWith("--")) {
				out[key] = next;
				i++;
			} else {
				out[key] = true;
			}
		}
	}
	return out;
}

const argv = parseArgs(process.argv.slice(2));
const envHost = process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_FIRESTORE_EMULATOR_HOST;
const host = argv.host || envHost || "localhost:8080";
const fileProject = projectIdFromFirebaseJson();
const projectArg = argv.project || process.env.FIRESTORE_PROJECT || fileProject || "demo-project";
const PROJECT_ID = projectArg;
const BASE = `http://${host}/v1/projects/${PROJECT_ID}/databases/%28default%29/documents`;

// Auth emulator host (can be overridden via env or CLI arg). If not provided,
// try common candidates (localhost, Android emulator host 10.0.2.2, 127.0.0.1).
const explicitAuthHost = argv.authHost || process.env.FIREBASE_AUTH_EMULATOR_HOST || null;

async function findAuthHost() {
	const candidates = [];
	if (explicitAuthHost) candidates.push(explicitAuthHost);
	candidates.push("localhost:9099");
	candidates.push("10.0.2.2:9099");
	candidates.push("127.0.0.1:9099");

	function probeTcp(host, port, timeout = 400) {
		return new Promise(resolve => {
			const socket = new net.Socket();
			let done = false;
			const onDone = r => {
				if (done) return;
				done = true;
				try {
					socket.destroy();
				} catch (_) {}
				resolve(r);
			};
			socket.setTimeout(timeout);
			socket.once("connect", () => onDone(true));
			socket.once("timeout", () => onDone(false));
			socket.once("error", () => onDone(false));
			socket.connect(port, host);
		});
	}

	for (const h of candidates) {
		const parts = h.split(":");
		const hostname = parts[0];
		const port = Number(parts[1] || 9099);
		try {
			const ok = await probeTcp(hostname, port, 300);
			if (ok) return h;
		} catch (e) {
			// ignore
		}
	}
	return null;
}

let authHost = explicitAuthHost || null;
let AUTH_BASE = authHost ? `http://${authHost}` : null;

console.log("Seeding using host:", host);
console.log("Seeding using project:", PROJECT_ID);

const now = new Date();

function daysFromNow(days) {
	const d = new Date(now);
	d.setDate(d.getDate() + days);
	return d.toISOString();
}

// Generate a larger set of samples matching app model. We intentionally
// vary presence/absence of optional fields (note, contact, imagePath,
// daysRemaining/color) and set isHistory true for some items.
function generateSamples(count = 40) {
	const titles = [
		"Power Bank Xiaomi 10000mAh",
		"Buku: Clean Code",
		"Kabel HDMI 2 Meter",
		"Headset Sony",
		"Mouse Logitech",
		"Charger MacBook",
		"Harddisk 1TB External",
		"Buku: Design Patterns",
		"Flashdisk 32GB",
		"Adaptor USB-C",
		"Kamera Instan",
		"Speaker Bluetooth",
		"Tripod",
		"Proyektor Mini",
		"Router WiFi",
	];
	const borrowers = [
		"Andi Wijaya",
		"Siti Rahmawati",
		"Budi Santoso",
		"Rina Pratiwi",
		"Agus Salim",
		"Dina Marlina",
		"Hendra",
		"Lina",
		"Farhan",
		"Maya",
	];
	const notes = [
		"Untuk tugas kuliah",
		"Dipinjam sementara untuk presentasi",
		"Hati-hati saat membawa",
		"Jangan bawa ke luar negeri",
		null,
		null,
		null,
	];
	const contacts = ["08123456789", "082233445566", null, null, null];

	const images = [null, null, null, "images/powerbank.jpg", "images/book.jpg", "images/hdmi.jpg"];

	const out = [];
	for (let i = 0; i < count; i++) {
		const id = `seed-${i + 1}`;
		const title = titles[i % titles.length] + (i >= titles.length ? ` #${Math.floor(i / titles.length)}` : "");
		const borrower = borrowers[(i * 7) % borrowers.length];

		// daysRemaining: some null, some negative (overdue), some positive
		let daysRemaining = null;
		const r = i % 7;
		if (r === 0) daysRemaining = null;
		else if (r <= 2) daysRemaining = -((i % 5) + 1); // overdue
		else daysRemaining = (i % 14) + 1; // due in future

		// set isHistory for some items explicitly
		const isHistory = i % 5 === 0; // 20% as history

		// Occasionally omit color so app chooses pastelForId
		const color = i % 4 === 0 ? null : 0xff000000 | Math.floor(Math.random() * 0xffffff);

		const note = notes[(i * 3) % notes.length];
		const contact = contacts[(i * 5) % contacts.length];
		const imagePath = images[(i * 3) % images.length];

		out.push({
			id,
			title,
			borrower,
			daysRemaining,
			note,
			contact,
			imagePath,
			color,
			isHistory,
		});
	}
	return out;
}

const samples = generateSamples(60);

// Example auth users to create in the Auth emulator. Passwords are plain-text
// and only used for local testing against the emulator.
const authUsers = [
	{
		email: "test@example.com",
		password: "password123",
		displayName: "Test User",
	},
];

async function deleteDocIfExists(collection, docId) {
	const url = `${BASE}/${collection}/${encodeURIComponent(docId)}`;
	try {
		const res = await fetch(url, { method: "DELETE" });
		// 200/202/204 indicate success; 404 means not found which is OK
		if (res.status === 404) return false;
		return res.ok;
	} catch (e) {
		return false;
	}
}

async function putDoc(collection, docId, data) {
	// Delete existing doc (if any) so seeding is idempotent and replaces old data
	await deleteDocIfExists(collection, docId);

	const url = `${BASE}/${collection}?documentId=${encodeURIComponent(docId)}`;
	// Firestore REST expects typed fields; construct fields explicitly.
	const body = { fields: {} };
	for (const [k, v] of Object.entries(data)) {
		if (v === null || v === undefined) continue;
		if (k === "borrowDate" || k === "targetReturnDate") {
			// timestamps
			body.fields[k] = { timestampValue: new Date(v).toISOString() };
		} else if (typeof v === "string") {
			body.fields[k] = { stringValue: v };
		} else if (Number.isInteger(v)) {
			body.fields[k] = { integerValue: `${v}` };
		} else if (typeof v === "number") {
			body.fields[k] = { doubleValue: `${v}` };
		} else if (typeof v === "boolean") {
			body.fields[k] = { booleanValue: v };
		} else {
			body.fields[k] = { stringValue: JSON.stringify(v) };
		}
	}
	// add updatedAt as timestamp
	body.fields["updatedAt"] = { timestampValue: new Date().toISOString() };

	const res = await fetch(url, {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify(body),
	});
	if (!res.ok) {
		const text = await res.text();
		throw new Error(`Failed to write ${docId}: ${res.status} ${text}`);
	}
	return res.json();
}

async function seed() {
	console.log("Seeding Firestore emulator with project:", PROJECT_ID);
	// Find a reachable Auth emulator host (try common candidates)
	if (!AUTH_BASE) {
		const found = await findAuthHost();
		if (found) {
			authHost = found;
			AUTH_BASE = `http://${authHost}`;
			console.log("Auth emulator reachable at", authHost);
		}
	}

	// Probe Auth emulator before creating users
	let authAvailable = false;
	if (AUTH_BASE) {
		const authProbeUrl = `${AUTH_BASE}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fakeKey`;
		try {
			const probe = await fetch(authProbeUrl, { method: "OPTIONS" });
			// OPTIONS may be blocked; try GET as fallback
			if (probe.ok || probe.status === 405) {
				authAvailable = true;
			} else {
				const probeGet = await fetch(AUTH_BASE);
				authAvailable = probeGet.ok;
			}
		} catch (e) {
			authAvailable = false;
		}
	}

	if (authAvailable) {
		for (const u of authUsers) {
			try {
				await createAuthUser(u.email, u.password, u.displayName);
				console.log("Auth user created:", u.email);
				// Also ensure a users doc exists in Firestore
				const userDoc = {
					email: u.email,
					displayName: u.displayName,
					createdAt: new Date().toISOString(),
				};
				await putDoc("users", u.email.replace(/[@.]/g, "_"), userDoc);
				console.log("User profile written for", u.email);
			} catch (e) {
				console.error("Auth creation failed for", u.email, e && e.message ? e.message : e);
			}
		}
	} else {
		console.log("Auth emulator not available at", authHost, "; skipping auth user creation.");
	}

	// Aggressive fallback: even if probing failed, try creating auth users on
	// common candidate hosts (admin endpoint and identitytoolkit signup). This
	// helps when simple TCP/HTTP probes are blocked but the admin API is still
	// reachable.
	if (!authAvailable) {
		const candidates = [];
		if (explicitAuthHost) candidates.push(explicitAuthHost);
		candidates.push("localhost:9099");
		candidates.push("10.0.2.2:9099");
		candidates.push("127.0.0.1:9099");
		for (const h of candidates) {
			if (!h) continue;
			try {
				const ok = await attemptAuthCreateOnHost(h, authUsers[0]);
				if (ok) {
					console.log("Aggressive auth create succeeded on", h);
					// write users doc as well
					const u = authUsers[0];
					const userDoc = { email: u.email, displayName: u.displayName, createdAt: new Date().toISOString() };
					await putDoc("users", u.email.replace(/[@.]/g, "_"), userDoc);
					break;
				}
			} catch (e) {
				console.error("Aggressive auth create failed for", h, e && e.message ? e.message : e);
			}
		}
	}
	for (const s of samples) {
		const doc = {
			id: s.id,
			title: s.title,
			borrower: s.borrower,
			// store borrowDate as now for new seeded docs
			borrowDate: new Date().toISOString(),
			// if daysRemaining exists, compute an absolute targetReturnDate
			targetReturnDate:
				s.daysRemaining == null
					? null
					: new Date(Date.now() + s.daysRemaining * 24 * 60 * 60 * 1000).toISOString(),
			daysRemaining: s.daysRemaining,
			note: s.note,
			contact: s.contact,
			imagePath: s.imagePath,
			color: s.color,
			isHistory: s.isHistory,
		};
		try {
			await putDoc("loan_items", s.id, doc);
			console.log("Wrote", s.id);
		} catch (e) {
			console.error("Error writing", s.id, e.message || e);
		}
	}
	console.log("Seeding complete. Open emulator UI at http://localhost:4000 to inspect.");
}

async function createAuthUser(email, password, displayName) {
	// Auth emulator accepts the Identity Toolkit REST endpoint. Use a fake API key.
	const url = `${AUTH_BASE}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fakeKey`;
	const body = {
		email: email,
		password: password,
		returnSecureToken: true,
	};
	const res = await fetch(url, {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify(body),
	});
	if (!res.ok) {
		const t = await res.text();
		throw new Error(`Auth create failed: ${res.status} ${t}`);
	}
	const json = await res.json();
	// Optionally set displayName via updateProfile endpoint
	if (displayName) {
		const updateUrl = `${AUTH_BASE}/identitytoolkit.googleapis.com/v1/accounts:update?key=fakeKey`;
		const updateBody = {
			idToken: json.idToken,
			displayName: displayName,
			returnSecureToken: true,
		};
		await fetch(updateUrl, {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify(updateBody),
		});
	}
	return json;
}

async function attemptAuthCreateOnHost(host, user) {
	// Try admin endpoint first: POST http://<host>/emulator/v1/projects/<project>/accounts
	const adminUrl = `http://${host}/emulator/v1/projects/${PROJECT_ID}/accounts`;
	try {
		const res = await fetch(adminUrl, {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify({
				localId: user.email.split("@")[0],
				email: user.email,
				passwordHash: "not_a_real_hash",
				emailVerified: true,
				displayName: user.displayName,
			}),
		});
		if (res.ok) return true;
		// continue to try identitytoolkit
	} catch (e) {
		// ignore
	}

	// Fallback to identitytoolkit signUp endpoint
	const ikUrl = `http://${host}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fakeKey`;
	try {
		const res = await fetch(ikUrl, {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify({ email: user.email, password: user.password, returnSecureToken: true }),
		});
		if (res.ok) return true;
	} catch (e) {
		// ignore
	}
	return false;
}

seed().catch(e => {
	console.error("Seeding failed:", e && e.stack ? e.stack : e);
	process.exit(1);
});
