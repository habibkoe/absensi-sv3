<script lang="ts">
  import '../app.css';
  import { onMount } from 'svelte';
  import { initAuth, user, loading } from '$lib/stores/authStore';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';

  onMount(async () => {
    await initAuth();
  });

  // Redirect to login if not authenticated
  $: if (!$loading && !$user && !$page.url.pathname.includes('/login')) {
    goto('/login');
  }
</script>

{#if $loading}
  <div class="flex items-center justify-center min-h-screen">
    <div class="text-center">
      <div class="w-12 h-12 mx-auto border-b-2 border-blue-600 rounded-full animate-spin"></div>
      <p class="mt-4 text-gray-600">Loading...</p>
    </div>
  </div>
{:else}
  <slot />
{/if}
