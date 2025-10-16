#!/usr/bin/env node
// Small admin-style seeder that uses the Firebase Auth emulator REST admin endpoint
// to create a user. This avoids the identitytoolkit signUp flow and talks to the
// /emulator/v1/projects/<project>/accounts endpoint which the emulator exposes.

const fetch = global.fetch || require("node-fetch");
const path = require("path");
const fs = require("fs");

// tiny argv parser (accepts --authHost, --project, --firestoreHost)
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

function projectIdFromFirebaseJson() {
	try {
		const p = path.resolve(process.cwd(), "firebase.json");
		if (!fs.existsSync(p)) return "demo-project";
		const j = JSON.parse(fs.readFileSync(p, "utf8"));
		return j.projectId || j["projects"]?.default || "demo-project";
	} catch (e) {
		return "demo-project";
	}
}

const cli = parseArgs(process.argv.slice(2));
const explicitAuthHost = cli.authHost || process.env.FIREBASE_AUTH_EMULATOR_HOST || null;
const explicitFirestoreHost =
	cli.firestoreHost || process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_FIRESTORE_EMULATOR_HOST || null;
const explicitProject = cli.project || null;
const candidates = [explicitAuthHost, "localhost:9099", "10.0.2.2:9099", "127.0.0.1:9099"];
const PROJECT = explicitProject || projectIdFromFirebaseJson();

async function tryCreate(host) {
	const base = `http://${host}/emulator/v1/projects/${PROJECT}/accounts`;
	try {
		const res = await fetch(base, {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify({
				localId: "test_user",
				email: "test@example.com",
				passwordHash: "not_a_real_hash",
				emailVerified: true,
				displayName: "Test User",
			}),
		});
		const text = await res.text();
		console.log("Host:", host, "status:", res.status, "body:", text);
		if (res.ok) return true;
		// Some emulator builds return 405 for admin POST; try identitytoolkit signUp as fallback
		if (res.status === 405 || !res.ok) {
			try {
				const ikUrl = `http://${host}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fakeKey`;
				const ikRes = await fetch(ikUrl, {
					method: "POST",
					headers: { "Content-Type": "application/json" },
					body: JSON.stringify({
						email: "test@example.com",
						password: "password123",
						returnSecureToken: true,
					}),
				});
				const ikText = await ikRes.text();
				console.log("Host:", host, "identitytoolkit status:", ikRes.status, "body:", ikText);
				if (ikRes.ok) return true;
			} catch (e) {
				console.error("identitytoolkit fallback error for host", host, e && e.message ? e.message : e);
			}
		}
		return false;
	} catch (e) {
		console.error("Host:", host, "error:", e && e.message ? e.message : e);
		return false;
	}
}

async function writeFirestoreUserIfPossible(firestoreHost, user) {
	if (!firestoreHost) return false;
	const project = PROJECT || projectIdFromFirebaseJson() || "demo-project";
	const base = `http://${firestoreHost}/v1/projects/${project}/databases/%28default%29/documents`;
	const docId = user.email.replace(/[@.]/g, "_");
	const url = `${base}/users?documentId=${encodeURIComponent(docId)}`;
	const body = {
		fields: {
			email: { stringValue: user.email },
			displayName: { stringValue: user.displayName || "" },
			createdAt: { timestampValue: new Date().toISOString() },
		},
	};
	try {
		const res = await fetch(url, {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify(body),
		});
		const txt = await res.text();
		console.log("Firestore write status:", res.status, txt);
		return res.ok;
	} catch (e) {
		console.error("Failed to write user doc to Firestore at", firestoreHost, e && e.message ? e.message : e);
		return false;
	}
}

(async function main() {
	for (const c of candidates) {
		if (!c) continue;
		console.log("Trying auth host", c);
		const ok = await tryCreate(c);
		if (ok) {
			console.log("Created user via admin emulator API at", c);
			// attempt to write a Firestore user doc if a firestore host is provided
			const fsHost =
				explicitFirestoreHost ||
				process.env.FIRESTORE_EMULATOR_HOST ||
				process.env.FIREBASE_FIRESTORE_EMULATOR_HOST ||
				"localhost:8080";
			try {
				const wrote = await writeFirestoreUserIfPossible(fsHost, {
					email: "test@example.com",
					displayName: "Test User",
				});
				if (wrote) console.log("Also wrote user profile to Firestore at", fsHost);
			} catch (e) {
				// non-fatal
			}
			process.exit(0);
		}
	}
	console.error("Failed to create auth user on any candidate hosts. Make sure the auth emulator is running.");
	process.exit(1);
})();
