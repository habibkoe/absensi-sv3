<script lang="ts">
  import { signOut, user } from '$lib/stores/authStore';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';

  let menuOpen = false;

  async function handleSignOut() {
    await signOut();
    goto('/login');
  }

  function isActive(path: string) {
    return $page.url.pathname === path || $page.url.pathname.startsWith(path + '/');
  }
</script>

<nav class="text-white bg-blue-600 shadow-lg">
  <div class="container px-4 py-4 mx-auto">
    <div class="flex items-center justify-between">
      <div class="flex items-center space-x-8">
        <a href="/" class="text-xl font-bold">Attendance System</a>
        
        <div class="hidden space-x-4 md:flex">
          <a
            href="/"
            class="px-3 py-2 rounded-lg transition-colors {isActive('/') && $page.url.pathname === '/' ? 'bg-blue-700' : 'hover:bg-blue-700'}"
          >
            Dashboard
          </a>
          <a
            href="/classrooms"
            class="px-3 py-2 rounded-lg transition-colors {isActive('/classrooms') ? 'bg-blue-700' : 'hover:bg-blue-700'}"
          >
            Classrooms
          </a>
          <a
            href="/students"
            class="px-3 py-2 rounded-lg transition-colors {isActive('/students') ? 'bg-blue-700' : 'hover:bg-blue-700'}"
          >
            Students
          </a>
          <a
            href="/attendance"
            class="px-3 py-2 rounded-lg transition-colors {isActive('/attendance') ? 'bg-blue-700' : 'hover:bg-blue-700'}"
          >
            Attendance
          </a>
          <a
            href="/reports"
            class="px-3 py-2 rounded-lg transition-colors {isActive('/reports') ? 'bg-blue-700' : 'hover:bg-blue-700'}"
          >
            Reports
          </a>
        </div>
      </div>

      <div class="flex items-center space-x-4">
        <span class="hidden text-sm md:block">{$user?.email}</span>
        <button
          on:click={handleSignOut}
          class="px-4 py-2 text-sm font-semibold transition-colors bg-blue-700 rounded-lg hover:bg-blue-800"
        >
          Sign Out
        </button>
        <button
          class="md:hidden"
          on:click={() => (menuOpen = !menuOpen)}
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"></path>
          </svg>
        </button>
      </div>
    </div>

    {#if menuOpen}
      <div class="mt-4 space-y-2 md:hidden">
        <a
          href="/"
          class="block px-3 py-2 rounded-lg {isActive('/') && $page.url.pathname === '/' ? 'bg-blue-700' : 'hover:bg-blue-700'}"
          on:click={() => (menuOpen = false)}
        >
          Dashboard
        </a>
        <a
          href="/classrooms"
          class="block px-3 py-2 rounded-lg {isActive('/classrooms') ? 'bg-blue-700' : 'hover:bg-blue-700'}"
          on:click={() => (menuOpen = false)}
        >
          Classrooms
        </a>
        <a
          href="/students"
          class="block px-3 py-2 rounded-lg {isActive('/students') ? 'bg-blue-700' : 'hover:bg-blue-700'}"
          on:click={() => (menuOpen = false)}
        >
          Students
        </a>
        <a
          href="/attendance"
          class="block px-3 py-2 rounded-lg {isActive('/attendance') ? 'bg-blue-700' : 'hover:bg-blue-700'}"
          on:click={() => (menuOpen = false)}
        >
          Attendance
        </a>
        <a
          href="/reports"
          class="block px-3 py-2 rounded-lg {isActive('/reports') ? 'bg-blue-700' : 'hover:bg-blue-700'}"
          on:click={() => (menuOpen = false)}
        >
          Reports
        </a>
      </div>
    {/if}
  </div>
</nav>
