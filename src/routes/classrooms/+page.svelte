<script lang="ts">
  import Navigation from '$lib/components/Navigation.svelte';
  import { supabase } from '$lib/supabaseClient';
  import type { Classroom } from '$lib/types';
  import { onMount } from 'svelte';

  let classrooms: Classroom[] = [];
  let loading = true;
  let showModal = false;
  let editingClassroom: Classroom | null = null;
  let formData = { name: '', year_of_study: 1 };
  let error = '';
  let success = '';

  onMount(async () => {
    await loadClassrooms();
  });

  async function loadClassrooms() {
    loading = true;
    const { data, error: fetchError } = await supabase
      .from('master_class_room')
      .select('*')
      .order('year_of_study', { ascending: true });

    if (fetchError) {
      console.error('Error loading classrooms:', fetchError);
    } else {
      classrooms = data || [];
    }
    loading = false;
  }

  function openAddModal() {
    editingClassroom = null;
    formData = { name: '', year_of_study: 1 };
    error = '';
    showModal = true;
  }

  function openEditModal(classroom: Classroom) {
    editingClassroom = classroom;
    formData = {
      name: classroom.name,
      year_of_study: classroom.year_of_study
    };
    error = '';
    showModal = true;
  }

  function closeModal() {
    showModal = false;
    editingClassroom = null;
    formData = { name: '', year_of_study: 1 };
    error = '';
  }

  async function handleSubmit() {
    if (!formData.name.trim()) {
      error = 'Classroom name is required';
      return;
    }

    if (formData.year_of_study < 1) {
      error = 'Year of study must be at least 1';
      return;
    }

    if (editingClassroom) {
      // Update existing classroom
      const { error: updateError } = await supabase
        .from('master_class_room')
        .update({
          name: formData.name,
          year_of_study: formData.year_of_study,
          updated_at: new Date().toISOString()
        })
        .eq('id', editingClassroom.id);

      if (updateError) {
        error = updateError.message;
      } else {
        success = 'Classroom updated successfully!';
        closeModal();
        await loadClassrooms();
        setTimeout(() => (success = ''), 3000);
      }
    } else {
      // Add new classroom
      const { error: insertError } = await supabase
        .from('master_class_room')
        .insert([formData]);

      if (insertError) {
        error = insertError.message;
      } else {
        success = 'Classroom added successfully!';
        closeModal();
        await loadClassrooms();
        setTimeout(() => (success = ''), 3000);
      }
    }
  }

  async function handleDelete(classroom: Classroom) {
    if (!confirm(`Are you sure you want to delete "${classroom.name}"?`)) {
      return;
    }

    const { error: deleteError } = await supabase
      .from('master_class_room')
      .delete()
      .eq('id', classroom.id);

    if (deleteError) {
      error = deleteError.message;
      setTimeout(() => (error = ''), 3000);
    } else {
      success = 'Classroom deleted successfully!';
      await loadClassrooms();
      setTimeout(() => (success = ''), 3000);
    }
  }
</script>

<Navigation />

<div class="min-h-screen bg-gray-100">
  <div class="container px-4 py-8 mx-auto">
    <div class="flex items-center justify-between mb-8">
      <h1 class="text-3xl font-bold text-gray-800">Classrooms</h1>
      <button
        on:click={openAddModal}
        class="px-4 py-2 font-semibold text-white transition-colors bg-blue-600 rounded-lg hover:bg-blue-700"
      >
        + Add Classroom
      </button>
    </div>

    {#if success}
      <div class="p-4 mb-4 text-green-700 bg-green-100 border border-green-400 rounded">
        {success}
      </div>
    {/if}

    {#if error && !showModal}
      <div class="p-4 mb-4 text-red-700 bg-red-100 border border-red-400 rounded">
        {error}
      </div>
    {/if}

    {#if loading}
      <div class="text-center">
        <div class="w-12 h-12 mx-auto border-b-2 border-blue-600 rounded-full animate-spin"></div>
        <p class="mt-4 text-gray-600">Loading classrooms...</p>
      </div>
    {:else if classrooms.length === 0}
      <div class="p-8 text-center bg-white rounded-lg shadow-md">
        <p class="text-gray-600">No classrooms found. Add your first classroom to get started!</p>
      </div>
    {:else}
      <div class="overflow-hidden bg-white rounded-lg shadow-md">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase">Name</th>
              <th class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase">Year of Study</th>
              <th class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase">Created At</th>
              <th class="px-6 py-3 text-xs font-medium tracking-wider text-right text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each classrooms as classroom}
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 text-sm font-medium text-gray-900 whitespace-nowrap">{classroom.name}</td>
                <td class="px-6 py-4 text-sm text-gray-500 whitespace-nowrap">Year {classroom.year_of_study}</td>
                <td class="px-6 py-4 text-sm text-gray-500 whitespace-nowrap">{new Date(classroom.created_at).toLocaleDateString()}</td>
                <td class="px-6 py-4 space-x-2 text-sm font-medium text-right whitespace-nowrap">
                  <button
                    on:click={() => openEditModal(classroom)}
                    class="text-blue-600 hover:text-blue-900"
                  >
                    Edit
                  </button>
                  <button
                    on:click={() => handleDelete(classroom)}
                    class="text-red-600 hover:text-red-900"
                  >
                    Delete
                  </button>
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
  <div class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black bg-opacity-50">
    <div class="w-full max-w-md p-6 bg-white rounded-lg shadow-xl">
      <h2 class="mb-4 text-2xl font-bold text-gray-800">
        {editingClassroom ? 'Edit Classroom' : 'Add Classroom'}
      </h2>

      <form on:submit|preventDefault={handleSubmit} class="space-y-4">
        <div>
          <label for="name" class="block mb-2 text-sm font-medium text-gray-700">
            Classroom Name
          </label>
          <input
            type="text"
            id="name"
            bind:value={formData.name}
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="e.g., Class A, Grade 10A"
            required
          />
        </div>

        <div>
          <label for="year" class="block mb-2 text-sm font-medium text-gray-700">
            Year of Study
          </label>
          <input
            type="number"
            id="year"
            bind:value={formData.year_of_study}
            min="1"
            max="12"
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            required
          />
        </div>

        {#if error}
          <div class="p-3 text-sm text-red-700 bg-red-100 border border-red-400 rounded">
            {error}
          </div>
        {/if}

        <div class="flex justify-end space-x-3">
          <button
            type="button"
            on:click={closeModal}
            class="px-4 py-2 text-gray-700 transition-colors bg-gray-200 rounded-lg hover:bg-gray-300"
          >
            Cancel
          </button>
          <button
            type="submit"
            class="px-4 py-2 font-semibold text-white transition-colors bg-blue-600 rounded-lg hover:bg-blue-700"
          >
            {editingClassroom ? 'Update' : 'Add'}
          </button>
        </div>
      </form>
    </div>
  </div>
{/if}
