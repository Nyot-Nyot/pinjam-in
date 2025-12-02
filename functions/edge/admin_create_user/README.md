# Deploy Edge Function: admin_create_user

## Prasyarat

-   Supabase CLI sudah terinstall
-   Sudah login ke Supabase CLI: `supabase login`
-   Sudah link project: `supabase link --project-ref <your-project-ref>`

## Cara Deploy

### 1. Deploy Edge Function

```bash
# Deploy dari root project
supabase functions deploy admin_create_user
```

### 2. Set Environment Variables (Otomatis)

Environment variables berikut akan otomatis tersedia di Edge Function:

-   `SUPABASE_URL` - URL project Supabase
-   `SUPABASE_SERVICE_ROLE` - Service role key (secret key dengan full access)

**PENTING**: Service role key TIDAK boleh digunakan di client-side (mobile/web app). Hanya boleh di server-side/Edge Functions.

### 3. Test Edge Function

Setelah deploy, test dengan curl:

```bash
# Get your access token from Supabase client
curl -X POST \
  https://<your-project-ref>.supabase.co/functions/v1/admin_create_user \
  -H "Authorization: Bearer <your-user-access-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "TestPass123",
    "full_name": "Test User",
    "role": "user",
    "status": "active",
    "send_verification_email": false
  }'
```

### 4. Verifikasi

-   User baru harus muncul di Supabase Auth dashboard
-   Profile harus tercreate di table `profiles`
-   Audit log harus tercreate di table `audit_logs`

## Security Features

Edge Function ini memiliki security layer:

1. **Authentication Check**: Memverifikasi user yang request sudah login (Bearer token valid)
2. **Authorization Check**: Memverifikasi user yang request memiliki role='admin' di table profiles
3. **Server-side Execution**: Menggunakan service role key yang hanya ada di server
4. **Audit Trail**: Otomatis mencatat siapa yang create user dan kapan

## Error Handling

Function akan return error response jika:

-   Method bukan POST (405)
-   Tidak ada Authorization header (401)
-   Token tidak valid (401)
-   User bukan admin (403)
-   Email/password tidak ada (400)
-   Email sudah terdaftar (400)
-   Error create user (400/500)
-   Error create profile (500)

## Rollback

Jika terjadi error saat create profile, function akan otomatis delete user dari Auth untuk menjaga konsistensi data.
