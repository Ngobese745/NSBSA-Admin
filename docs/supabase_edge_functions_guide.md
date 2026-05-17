# Supabase Edge Functions Migration Guide

To fully secure your application, you must move administrative operations from the client-side to Supabase Edge Functions. This allows you to use the `SERVICE_ROLE_KEY` securely on the server.

## 1. Setup
Install the Supabase CLI and initialize:
```bash
supabase init
```

## 2. Create the Admin Function
Create a function named `admin-tasks`:
```bash
supabase functions new admin-tasks
```

## 3. Implementation Example (deno)
Add this logic to `supabase/functions/admin-tasks/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  const { action, payload } = await req.json()
  
  // Initialize admin client with SERVICE_ROLE_KEY
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  // Verify the requester has 'Super Admin' role
  const authHeader = req.headers.get('Authorization')!
  const client = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_ANON_KEY') ?? '', {
    global: { headers: { Authorization: authHeader } }
  })
  const { data: { user } } = await client.auth.getUser()
  
  const { data: profile } = await supabaseAdmin
    .from('profiles')
    .select('role')
    .eq('id', user?.id)
    .single()

  if (profile?.role !== 'Super Admin') {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 403 })
  }

  // Handle actions
  switch (action) {
    case 'create-user':
      const { email, password, metadata } = payload
      return await supabaseAdmin.auth.admin.createUser({ email, password, user_metadata: metadata })
    // Add other cases: block-user, delete-user, etc.
  }
})
```

## 4. Update Flutter Code
In `AccountManagementService.dart`, replace `_admin` calls with:

```dart
final response = await Supabase.instance.client.functions.invoke(
  'admin-tasks',
  body: {
    'action': 'create-user',
    'payload': { ... }
  },
);
```
