import { writable } from 'svelte/store';
import { supabase } from '$lib/supabaseClient';
import type { User } from '@supabase/supabase-js';

export const user = writable<User | null>(null);
export const loading = writable(true);

// Initialize auth state
export async function initAuth() {
  loading.set(true);
  const { data: { session } } = await supabase.auth.getSession();
  user.set(session?.user ?? null);
  loading.set(false);

  // Listen for auth changes
  supabase.auth.onAuthStateChange((_event, session) => {
    user.set(session?.user ?? null);
  });
}

// Sign in with email and password
export async function signIn(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password
  });
  return { data, error };
}

// Sign out
export async function signOut() {
  const { error } = await supabase.auth.signOut();
  return { error };
}
