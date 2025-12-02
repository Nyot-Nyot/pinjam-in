import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY')
      return new Response(
        JSON.stringify({ error: 'Server configuration error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client with service role (has admin privileges)
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get authorization header to verify user is authenticated
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify the user making the request
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)

    if (authError || !user) {
      console.error('Auth error:', authError)
      return new Response(
        JSON.stringify({ error: 'Invalid token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if user is admin by querying profiles table
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single()

    if (profileError) {
      console.error('Profile error:', profileError)
      return new Response(
        JSON.stringify({ error: 'Failed to verify admin status' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!profile || profile.role !== 'admin') {
      console.error('Not admin:', { userId: user.id, role: profile?.role })
      return new Response(
        JSON.stringify({ error: 'Forbidden: Admin access required' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const body = await req.json()
    const { email, password, full_name, role, status, send_verification_email } = body

    console.log('Creating user:', { email, role, status })

    // Validate required fields
    if (!email || !password) {
      return new Response(
        JSON.stringify({ error: 'Email and password are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create user in Supabase Auth using admin API
    const { data: newUser, error: createError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: !send_verification_email,
      user_metadata: {
        full_name: full_name || null,
      }
    })

    if (createError) {
      console.error('Create user error:', createError)
      return new Response(
        JSON.stringify({ error: createError.message }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!newUser.user) {
      console.error('No user returned from createUser')
      return new Response(
        JSON.stringify({ error: 'Failed to create user' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('User created in auth:', newUser.user.id)

    // Insert profile record (email is stored in auth.users, not profiles)
    const { error: profileInsertError } = await supabase
      .from('profiles')
      .insert({
        id: newUser.user.id,
        full_name: full_name || null,
        role: role || 'user',
        status: status || 'active',
        updated_at: new Date().toISOString(),
      })

    if (profileInsertError) {
      console.error('Profile insert error:', profileInsertError)
      // Try to delete the auth user since profile creation failed
      try {
        await supabase.auth.admin.deleteUser(newUser.user.id)
      } catch (deleteError) {
        console.error('Failed to cleanup auth user:', deleteError)
      }
      return new Response(
        JSON.stringify({ error: 'Failed to create profile: ' + profileInsertError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('Profile created:', newUser.user.id)

    // Create audit log
    try {
      const { error: auditError } = await supabase.rpc('admin_create_audit_log', {
        p_admin_user_id: user.id,
        p_action_type: 'user_created',
        p_table_name: 'profiles',
        p_record_id: newUser.user.id,
        p_new_values: {
          email,
          full_name,
          role: role || 'user',
          status: status || 'active',
        },
        p_metadata: {
          send_verification_email: send_verification_email || false,
        }
      })

      if (auditError) {
        console.error('Audit log error:', auditError)
        // Don't fail the request if audit log fails
      } else {
        console.log('Audit log created')
      }
    } catch (auditError) {
      console.error('Audit log exception:', auditError)
      // Don't fail the request if audit log fails
    }

    console.log('Success! Returning user_id:', newUser.user.id)

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        user_id: newUser.user.id,
        email: email,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        details: error instanceof Error ? error.message : String(error)
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
