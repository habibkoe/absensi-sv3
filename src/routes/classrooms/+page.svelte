<script lang="ts">
  import Navigation from "$lib/components/Navigation.svelte";
  import Button from "$lib/components/Button.svelte";
  import Input from "$lib/components/Input.svelte";
  import { supabase } from "$lib/supabaseClient";
  import type { Classroom } from "$lib/types";
  import { onMount } from "svelte";

  let classrooms: Classroom[] = [];
  let loading = true;
  let showModal = false;
  let editingClassroom: Classroom | null = null;
  let formData = {
    name: "",
    start_year: new Date().getFullYear(),
    end_year: new Date().getFullYear() + 1,
  };
  let error = "";
  let success = "";

  onMount(async () => {
    await loadClassrooms();
  });

  async function loadClassrooms() {
    loading = true;
    const { data, error: fetchError } = await supabase
      .from("master_class_room")
      .select("*")
      .order("start_year", { ascending: true });

    if (fetchError) {
      console.error("Error loading classrooms:", fetchError);
    } else {
      classrooms = data || [];
    }
    loading = false;
  }

  function openAddModal() {
    editingClassroom = null;
    const currentYear = new Date().getFullYear();
    formData = { name: "", start_year: currentYear, end_year: currentYear + 1 };
    error = "";
    showModal = true;
  }

  function openEditModal(classroom: Classroom) {
    editingClassroom = classroom;
    formData = {
      name: classroom.name,
      start_year: classroom.start_year,
      end_year: classroom.end_year,
    };
    error = "";
    showModal = true;
  }

  function closeModal() {
    showModal = false;
    editingClassroom = null;
    const currentYear = new Date().getFullYear();
    formData = { name: "", start_year: currentYear, end_year: currentYear + 1 };
    error = "";
  }

  async function handleSubmit() {
    if (!formData.name.trim()) {
      error = "Classroom name is required";
      return;
    }

    if (formData.start_year < 2000 || formData.start_year > 2100) {
      error = "Start year must be between 2000 and 2100";
      return;
    }

    if (formData.end_year <= formData.start_year) {
      error = "End year must be greater than start year";
      return;
    }

    if (editingClassroom) {
      // Update existing classroom
      const { error: updateError } = await supabase
        .from("master_class_room")
        .update({
          name: formData.name,
          start_year: formData.start_year,
          end_year: formData.end_year,
          updated_at: new Date().toISOString(),
        })
        .eq("id", editingClassroom.id);

      if (updateError) {
        error = updateError.message;
      } else {
        success = "Classroom updated successfully!";
        closeModal();
        await loadClassrooms();
        setTimeout(() => (success = ""), 3000);
      }
    } else {
      // Add new classroom
      const { error: insertError } = await supabase
        .from("master_class_room")
        .insert([formData]);

      if (insertError) {
        error = insertError.message;
      } else {
        success = "Classroom added successfully!";
        closeModal();
        await loadClassrooms();
        setTimeout(() => (success = ""), 3000);
      }
    }
  }

  async function handleDelete(classroom: Classroom) {
    if (!confirm(`Are you sure you want to delete "${classroom.name}"?`)) {
      return;
    }

    const { error: deleteError } = await supabase
      .from("master_class_room")
      .delete()
      .eq("id", classroom.id);

    if (deleteError) {
      error = deleteError.message;
      setTimeout(() => (error = ""), 3000);
    } else {
      success = "Classroom deleted successfully!";
      await loadClassrooms();
      setTimeout(() => (success = ""), 3000);
    }
  }
</script>

<svelte:head>
  <title>Absensi Siswa - Master Ruang Kelas</title>
  <meta name="description" content="Absensi siswa" />
</svelte:head>

<Navigation />

<div class="min-h-screen bg-gray-100">
  <div class="container px-4 py-8 mx-auto">
    <div class="flex items-center justify-between mb-8">
      <h1 class="text-3xl font-bold text-gray-800">Ruang Kelas</h1>
      <Button on:click={openAddModal}>+ Tambah data</Button>
    </div>

    {#if success}
      <div
        class="p-4 mb-4 text-green-700 bg-green-100 border border-green-400 rounded"
      >
        {success}
      </div>
    {/if}

    {#if error && !showModal}
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
        <p class="mt-4 text-gray-600">Loading ruang kelas...</p>
      </div>
    {:else if classrooms.length === 0}
      <div class="p-8 text-center bg-white rounded-lg shadow-md">
        <p class="text-gray-600">
          Tidak ada ruang kelas yang ditemukan. Tambah data ruang kelas terlebih
          dahulu!
        </p>
      </div>
    {:else}
      <div class="overflow-hidden bg-white rounded-lg shadow-md">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th
                class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                >No</th
              >
              <th
                class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                >Nama</th
              >
              <th
                class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                >Tahun Pelajaran</th
              >
              <th
                class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                >Dibuat Pada</th
              >
              <th
                class="px-6 py-3 text-xs font-medium tracking-wider text-right text-gray-500 uppercase"
                >Actions</th
              >
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each classrooms as classroom, i}
              <tr class="hover:bg-gray-50">
                <td
                  class="px-6 py-4 text-sm font-medium text-gray-900 whitespace-nowrap"
                  >{i + 1}</td
                >
                <td
                  class="px-6 py-4 text-sm font-medium text-gray-900 whitespace-nowrap"
                  >{classroom.name}</td
                >
                <td class="px-6 py-4 text-sm text-gray-500 whitespace-nowrap"
                  >{classroom.start_year}/{classroom.end_year}</td
                >
                <td class="px-6 py-4 text-sm text-gray-500 whitespace-nowrap"
                  >{new Date(classroom.created_at).toLocaleDateString()}</td
                >
                <td
                  class="px-6 py-4 space-x-2 text-sm font-medium text-right whitespace-nowrap"
                >
                  <Button
                    variant="link"
                    class="text-blue-600 hover:text-blue-900"
                    on:click={() => openEditModal(classroom)}
                  >
                    Edit
                  </Button>
                  <Button
                    variant="link"
                    class="text-red-600 hover:text-red-900"
                    on:click={() => handleDelete(classroom)}
                  >
                    Delete
                  </Button>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  </div>
</div>

<!-- Modal -->
{#if showModal}
  <div
    class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black bg-opacity-50"
  >
    <div class="w-full max-w-md p-6 bg-white rounded-lg shadow-xl">
      <h2 class="mb-4 text-2xl font-bold text-gray-800">
        {editingClassroom ? "Edit Ruang Kelas" : "Tambah Ruang Kelas"}
      </h2>

      <form on:submit|preventDefault={handleSubmit} class="space-y-4">
        <Input
          type="text"
          id="name"
          label="Nama kelas"
          bind:value={formData.name}
          placeholder="e.g., Class A, Grade 10A"
          required
        />

        <div class="grid grid-cols-2 gap-4">
          <Input
            type="number"
            id="start_year"
            label="Tahun mulai"
            bind:value={formData.start_year}
            min="2000"
            max="2100"
            required
          />
          <Input
            type="number"
            id="end_year"
            label="Tahun Akhir"
            bind:value={formData.end_year}
            min="2000"
            max="2100"
            required
          />
        </div>

        {#if error}
          <div
            class="p-3 text-sm text-red-700 bg-red-100 border border-red-400 rounded"
          >
            {error}
          </div>
        {/if}

        <div class="flex justify-end space-x-3">
          <Button type="button" variant="secondary" on:click={closeModal}>
            Cancel
          </Button>
          <Button type="submit">
            {editingClassroom ? "Update" : "Simpan"}
          </Button>
        </div>
      </form>
    </div>
  </div>
{/if}
