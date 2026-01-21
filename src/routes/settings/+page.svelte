<script lang="ts">
  import Navigation from "$lib/components/Navigation.svelte";
  import Button from "$lib/components/Button.svelte";
  import Input from "$lib/components/Input.svelte";
  import { supabase } from "$lib/supabaseClient";
  import type { Setting } from "$lib/types";
  import { onMount } from "svelte";

  let settings: Map<string, Setting> = new Map();
  let loading = false;
  let saving = false;
  let error = "";
  let success = "";

  // Form values
  let attendanceTimeLimit = "12:00";

  onMount(async () => {
    await loadSettings();
  });

  async function loadSettings() {
    loading = true;
    error = "";

    try {
      const { data, error: fetchError } = await supabase
        .from("settings")
        .select("*");

      if (fetchError) throw fetchError;

      if (data) {
        data.forEach((setting: Setting) => {
          settings.set(setting.key, setting);
        });

        // Initialize form values from settings
        const timeLimit = settings.get("attendance_time_limit");
        if (timeLimit) {
          attendanceTimeLimit = timeLimit.value;
        }
      }
    } catch (err: any) {
      console.error("Error loading settings:", err);
      error = err.message || "Failed to load settings";
    }

    loading = false;
  }

  async function saveSettings() {
    saving = true;
    error = "";
    success = "";

    try {
      // Update attendance_time_limit
      const { error: updateError } = await supabase
        .from("settings")
        .upsert({
          key: "attendance_time_limit",
          value: attendanceTimeLimit,
          description: "Batas waktu pengeditan absensi (format HH:mm)",
          updated_at: new Date().toISOString()
        });

      if (updateError) throw updateError;

      success = "Pengaturan berhasil disimpan!";
      
      // Reload settings to ensure we have fresh data
      await loadSettings();
      
      setTimeout(() => (success = ""), 3000);
    } catch (err: any) {
      console.error("Error saving settings:", err);
      error = err.message || "Gagal menyimpan pengaturan";
    }

    saving = false;
  }
</script>

<svelte:head>
  <title>Pengaturan - Sistem Absensi</title>
</svelte:head>

<Navigation />

<div class="min-h-screen bg-gray-100">
  <div class="container px-4 py-8 mx-auto">
    <h1 class="mb-8 text-3xl font-bold text-gray-800">Pengaturan Sistem</h1>

    {#if success}
      <div
        class="p-4 mb-4 text-green-700 bg-green-100 border border-green-400 rounded"
      >
        {success}
      </div>
    {/if}

    {#if error}
      <div
        class="p-4 mb-4 text-red-700 bg-red-100 border border-red-400 rounded"
      >
        {error}
      </div>
    {/if}

    {#if loading}
      <div class="text-center">
        <div
          class="w-12 h-12 mx-auto border-b-2 border-blue-600 rounded-full animate-spin"
        ></div>
        <p class="mt-4 text-gray-600">Memuat pengaturan...</p>
      </div>
    {:else}
      <div class="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
        <!-- Attendance Settings Card -->
        <div class="p-6 bg-white rounded-lg shadow-md">
          <h2 class="mb-4 text-xl font-semibold text-gray-800">Pengaturan Absensi</h2>
          
          <div class="space-y-4">
            <div>
              <label for="attendanceTimeLimit" class="block mb-2 text-sm font-medium text-gray-700">
                Batas Waktu Absensi
              </label>
              <p class="mb-2 text-xs text-gray-500">
                Guru tidak dapat mengubah absensi setelah jam ini pada hari yang sama.
              </p>
              <input
                type="time"
                id="attendanceTimeLimit"
                bind:value={attendanceTimeLimit}
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>

            <div class="pt-4 mt-4 border-t border-gray-100">
              <Button
                on:click={saveSettings}
                disabled={saving}
                class="w-full"
                {saving}
              >
                Simpan Pengaturan
              </Button>
            </div>
          </div>
        </div>
      </div>
    {/if}
  </div>
</div>
