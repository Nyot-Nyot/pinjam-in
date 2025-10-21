import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm'
import { serve } from 'std/server'

// Configure these via deployment environment variables
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE')
const BUCKET = Deno.env.get('SUPABASE_IMAGES_BUCKET') || 'public-images'

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE env vars')
}

const supabase = createClient(SUPABASE_URL ?? '', SUPABASE_SERVICE_ROLE ?? '')

serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'method not allowed' }), { status: 405 })
    }

    const contentType = req.headers.get('content-type') || ''
    if (!contentType.includes('multipart/form-data')) {
      return new Response(JSON.stringify({ error: 'expected multipart/form-data' }), { status: 400 })
    }

    const formData = await req.formData()
    const file = formData.get('file') as File | null
    const key = (formData.get('key') as string) || null

    if (!file) {
      return new Response(JSON.stringify({ error: 'missing file' }), { status: 400 })
    }

    const arrayBuffer = await file.arrayBuffer()
    const uint8 = new Uint8Array(arrayBuffer)

    // Determine object key if not provided
    const objectKey = key ?? `items/${Date.now()}.jpg`

    const { error } = await supabase.storage.from(BUCKET).upload(objectKey, uint8, {
      contentType: file.type || 'application/octet-stream',
      cacheControl: '3600',
      upsert: false,
    })

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 500 })
    }

    const publicUrl = `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${objectKey}`
    return new Response(JSON.stringify({ publicUrl }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    })
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e?.message ?? String(e) }), { status: 500 })
  }
})
