<script lang="ts">
  import { signIn } from "$lib/stores/authStore";

  import { goto } from "$app/navigation";
  import Button from "$lib/components/Button.svelte";
  import Input from "$lib/components/Input.svelte";

  let email = "";
  let password = "";
  let error = "";
  let loading = false;

  async function handleLogin() {
    if (!email || !password) {
      error = "Please fill in all fields";
      return;
    }

    loading = true;
    error = "";

    const { data, error: signInError } = await signIn(email, password);

    if (signInError) {
      error = signInError.message;
      loading = false;
    } else if (data.user) {
      goto("/");
    }
  }
</script>

<svelte:head>
  <title>Absensi Siswa - Login</title>
  <meta name="description" content="Absensi siswa" />
</svelte:head>

<div class="flex items-center justify-center min-h-screen bg-gray-100">
  <div class="w-full max-w-md p-8 bg-white rounded-lg shadow-md">
    <h1 class="mb-6 text-3xl font-bold text-center text-gray-800">
      Sistem Absensi Siswa
    </h1>
    <h2 class="mb-6 text-xl font-semibold text-center text-gray-600">Login</h2>

    <form on:submit|preventDefault={handleLogin} class="space-y-4">
      <Input
        type="email"
        id="email"
        label="Email"
        bind:value={email}
        placeholder="Masukkan email anda"
        required
      />

      <Input
        type="password"
        id="password"
        label="Password"
        bind:value={password}
        placeholder="Masukkan password anda"
        required
      />

      {#if error}
        <div
          class="p-3 text-sm text-red-700 bg-red-100 border border-red-400 rounded"
        >
          {error}
        </div>
      {/if}

      <Button type="submit" width="full" {loading} disabled={loading}>
        {loading ? "Signing in..." : "Sign In"}
      </Button>
    </form>
  </div>
</div>
