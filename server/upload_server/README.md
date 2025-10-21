# Supabase Upload Server

Simple Node/Express upload server that accepts multipart file uploads and uses the Supabase service_role key to upload files to Storage. Use this if you cannot change storage RLS or need a trusted server to perform uploads.

Environment variables:

-   SUPABASE_URL - your project URL (e.g. https://xyz.supabase.co)
-   SUPABASE_SERVICE_ROLE - your service_role key (keep private)
-   PORT - optional, default 3000

Run:

npm install
SUPABASE_URL="https://<project>.supabase.co" SUPABASE_SERVICE_ROLE="<service_role_key>" node index.js

POST /upload

-   form field `file` - required
-   form field `bucket` - optional (default `public-images`)
-   form field `key` - optional object key name (will be prefixed with items/<timestamp>/)

Response: { url, key }
