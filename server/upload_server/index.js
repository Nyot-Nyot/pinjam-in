const express = require("express");
const multer = require("multer");
const { createClient } = require("@supabase/supabase-js");
const fs = require("fs");

// Configure via environment variables
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE; // service_role key
const PORT = process.env.PORT || 3000;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE) {
	console.error("SUPABASE_URL and SUPABASE_SERVICE_ROLE must be set");
	process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE, {
	auth: {
		persistSession: false,
	},
});

const upload = multer({ dest: "/tmp/uploads" });
const app = express();

app.post("/upload", upload.single("file"), async (req, res) => {
	try {
		const file = req.file;
		if (!file) return res.status(400).json({ error: "no file" });

		const { bucket = "public-images", key = file.originalname } = req.body;
		const objectKey = `items/${Date.now()}/${key}`;

		// Read file buffer
		const buffer = fs.readFileSync(file.path);

		const { data, error } = await supabase.storage.from(bucket).upload(objectKey, buffer, {
			contentType: file.mimetype,
			upsert: false,
		});

		// Remove the temp file
		fs.unlinkSync(file.path);

		if (error) {
			console.error("Supabase storage error", error);
			return res.status(500).json({ error });
		}

		// Get public url
		const { data: pub, error: pubErr } = supabase.storage.from(bucket).getPublicUrl(objectKey);
		if (pubErr) return res.status(500).json({ error: pubErr });

		return res.json({ url: pub.publicUrl, key: objectKey });
	} catch (e) {
		console.error(e);
		return res.status(500).json({ error: e.message || String(e) });
	}
});

app.listen(PORT, () => console.log(`Upload server listening on ${PORT}`));
