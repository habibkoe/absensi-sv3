<script lang="ts">
  import Navigation from '$lib/components/Navigation.svelte';
  import { supabase } from '$lib/supabaseClient';
  import type { Student, Classroom } from '$lib/types';
  import { onMount } from 'svelte';
  import imageCompression from 'browser-image-compression';

  let students: (Student & { classroom?: Classroom })[] = [];
  let classrooms: Classroom[] = [];
  let loading = true;
  let showModal = false;
  let editingStudent: Student | null = null;
  let formData = {
    name: '',
    registration_number: '',
    class_room_id: ''
  };
  let photoFile: File | null = null;
  let photoPreview: string | null = null;
  let compressedSize: string = '';
  let error = '';
  let success = '';
  let filterClassroom = '';
  let searchQuery = '';
  let uploadingPhoto = false;

  onMount(async () => {
    await Promise.all([loadStudents(), loadClassrooms()]);
  });

  async function loadClassrooms() {
    const { data } = await supabase
      .from('master_class_room')
      .select('*')
      .order('start_year', { ascending: true });
    classrooms = data || [];
  }

  async function loadStudents() {
    loading = true;
    const { data, error: fetchError } = await supabase
      .from('students')
      .select(`
        *,
        classroom:master_class_room(*)
      `)
      .order('name', { ascending: true });

    if (fetchError) {
      console.error('Error loading students:', fetchError);
    } else {
      students = data || [];
    }
    loading = false;
  }

  function openAddModal() {
    editingStudent = null;
    formData = {
      name: '',
      registration_number: '',
      class_room_id: ''
    };
    photoFile = null;
    photoPreview = null;
    error = '';
    showModal = true;
  }

  function openEditModal(student: Student) {
    editingStudent = student;
    formData = {
      name: student.name,
      registration_number: student.registration_number,
      class_room_id: student.class_room_id || ''
    };
    photoFile = null;
    photoPreview = student.photo_url;
    error = '';
    showModal = true;
  }

  function closeModal() {
    showModal = false;
    editingStudent = null;
    formData = {
      name: '',
      registration_number: '',
      class_room_id: ''
    };
    photoFile = null;
    photoPreview = null;
    error = '';
  }

  async function handlePhotoChange(event: Event) {
    const target = event.target as HTMLInputElement;
    const file = target.files?.[0];
    
    if (file) {
      if (file.size > 5 * 1024 * 1024) {
        error = 'Photo size must be less than 5MB';
        return;
      }
      
      if (!file.type.startsWith('image/')) {
        error = 'Please upload an image file';
        return;
      }

      error = '';
      
      try {
        // Compress the image to approximately 70KB
        const options = {
          maxSizeMB: 0.07, // 70KB
          maxWidthOrHeight: 800,
          useWebWorker: true,
          initialQuality: 0.8
        };
        
        const compressedFile = await imageCompression(file, options);
        photoFile = compressedFile;
        
        // Show preview
        const reader = new FileReader();
        reader.onload = (e) => {
          photoPreview = e.target?.result as string;
        };
        reader.readAsDataURL(compressedFile);
        
        // Store compressed file size for display
        compressedSize = `${(compressedFile.size / 1024).toFixed(2)} KB`;
        
        // Show compressed file size in console
        console.log(`Original size: ${(file.size / 1024).toFixed(2)} KB`);
        console.log(`Compressed size: ${compressedSize}`);
      } catch (err) {
        console.error('Error compressing image:', err);
        error = 'Failed to compress image. Please try another photo.';
      }
    }
  }

  async function uploadPhoto(file: File): Promise<string | null> {
    uploadingPhoto = true;
    try {
      const fileExt = file.name.split('.').pop();
      const fileName = `${Math.random().toString(36).substring(2)}-${Date.now()}.${fileExt}`;
      const filePath = `${fileName}`;

      const { error: uploadError } = await supabase.storage
        .from('student-photos')
        .upload(filePath, file);

      if (uploadError) {
        throw uploadError;
      }

      const { data: { publicUrl } } = supabase.storage
        .from('student-photos')
        .getPublicUrl(filePath);

      return publicUrl;
    } catch (err) {
      console.error('Error uploading photo:', err);
      return null;
    } finally {
      uploadingPhoto = false;
    }
  }

  async function handleSubmit() {
    if (!formData.name.trim()) {
      error = 'Student name is required';
      return;
    }

    if (!formData.registration_number.trim()) {
      error = 'Registration number is required';
      return;
    }

    if (formData.registration_number.length > 20) {
      error = 'Registration number must not exceed 20 characters';
      return;
    }

    let photo_url = editingStudent?.photo_url || null;

    // Upload new photo if provided
    if (photoFile) {
      const uploadedUrl = await uploadPhoto(photoFile);
      if (uploadedUrl) {
        photo_url = uploadedUrl;
      } else {
        error = 'Failed to upload photo';
        return;
      }
    }

    if (editingStudent) {
      // Update existing student
      const { error: updateError } = await supabase
        .from('students')
        .update({
          name: formData.name,
          registration_number: formData.registration_number,
          class_room_id: formData.class_room_id || null,
          photo_url,
          updated_at: new Date().toISOString()
        })
        .eq('id', editingStudent.id);

      if (updateError) {
        error = updateError.message;
      } else {
        success = 'Student updated successfully!';
        closeModal();
        await loadStudents();
        setTimeout(() => (success = ''), 3000);
      }
    } else {
      // Add new student
      const { error: insertError } = await supabase
        .from('students')
        .insert([{
          name: formData.name,
          registration_number: formData.registration_number,
          class_room_id: formData.class_room_id || null,
          photo_url
        }]);

      if (insertError) {
        error = insertError.message;
      } else {
        success = 'Student added successfully!';
        closeModal();
        await loadStudents();
        setTimeout(() => (success = ''), 3000);
      }
    }
  }

  async function handleDelete(student: Student) {
    if (!confirm(`Are you sure you want to delete "${student.name}"?`)) {
      return;
    }

    const { error: deleteError } = await supabase
      .from('students')
      .delete()
      .eq('id', student.id);

    if (deleteError) {
      error = deleteError.message;
      setTimeout(() => (error = ''), 3000);
    } else {
      success = 'Student deleted successfully!';
      await loadStudents();
      setTimeout(() => (success = ''), 3000);
    }
  }

  $: filteredStudents = students.filter(student => {
    const matchesClassroom = !filterClassroom || student.class_room_id === filterClassroom;
    const matchesSearch = !searchQuery || 
      student.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      student.registration_number.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesClassroom && matchesSearch;
  });
</script>

<svelte:head>
  <title>Absensi Siswa - Master Siswa</title>
  <meta name="description" content="Absensi siswa" />
</svelte:head>

<Navigation />

<div class="min-h-screen bg-gray-100">
  <div class="container px-4 py-8 mx-auto">
    <div class="flex items-center justify-between mb-8">
      <h1 class="text-3xl font-bold text-gray-800">Students</h1>
      <button
        on:click={openAddModal}
        class="px-4 py-2 font-semibold text-white transition-colors bg-blue-600 rounded-lg hover:bg-blue-700"
      >
        + Add Student
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

    <!-- Filters -->
    <div class="grid grid-cols-1 gap-4 p-4 mb-6 bg-white rounded-lg shadow-md md:grid-cols-2">
      <div>
        <label for="search" class="block mb-2 text-sm font-medium text-gray-700">
          Search by name or registration number
        </label>
        <input
          type="text"
          id="search"
          bind:value={searchQuery}
          class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          placeholder="Search..."
        />
      </div>
      <div>
        <label for="filter" class="block mb-2 text-sm font-medium text-gray-700">
          Filter by classroom
        </label>
        <select
          id="filter"
          bind:value={filterClassroom}
          class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        >
          <option value="">All Classrooms</option>
          {#each classrooms as classroom}
            <option value={classroom.id}>{classroom.name} ({classroom.start_year}/{classroom.end_year})</option>
          {/each}
        </select>
      </div>
    </div>

    {#if loading}
      <div class="text-center">
        <div class="w-12 h-12 mx-auto border-b-2 border-blue-600 rounded-full animate-spin"></div>
        <p class="mt-4 text-gray-600">Loading students...</p>
      </div>
    {:else if filteredStudents.length === 0}
      <div class="p-8 text-center bg-white rounded-lg shadow-md">
        <p class="text-gray-600">No students found. Add your first student to get started!</p>
      </div>
    {:else}
      <div class="overflow-hidden bg-white rounded-lg shadow-md">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase">Photo</th>
              <th class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase">Name</th>
              <th class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase">Registration Number</th>
              <th class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase">Classroom</th>
              <th class="px-6 py-3 text-xs font-medium tracking-wider text-right text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each filteredStudents as student}
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  {#if student.photo_url}
                    <img src={student.photo_url} alt={student.name} class="object-cover w-12 h-12 rounded-full" />
                  {:else}
                    <div class="flex items-center justify-center w-12 h-12 text-white bg-gray-400 rounded-full">
                      {student.name.charAt(0).toUpperCase()}
                    </div>
                  {/if}
                </td>
                <td class="px-6 py-4 text-sm font-medium text-gray-900 whitespace-nowrap">{student.name}</td>
                <td class="px-6 py-4 text-sm text-gray-500 whitespace-nowrap">{student.registration_number}</td>
                <td class="px-6 py-4 text-sm text-gray-500 whitespace-nowrap">
                  {#if student.classroom}
                    {student.classroom.name} ({student.classroom.start_year}/{student.classroom.end_year})
                  {:else}
                    <span class="text-gray-400">Not assigned</span>
                  {/if}
                </td>
                <td class="px-6 py-4 space-x-2 text-sm font-medium text-right whitespace-nowrap">
                  <button
                    on:click={() => openEditModal(student)}
                    class="text-blue-600 hover:text-blue-900"
                  >
                    Edit
                  </button>
                  <button
                    on:click={() => handleDelete(student)}
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
  <div class="fixed inset-0 z-50 flex items-center justify-center p-4 overflow-y-auto bg-black bg-opacity-50">
    <div class="w-full max-w-md p-6 my-8 bg-white rounded-lg shadow-xl">
      <h2 class="mb-4 text-2xl font-bold text-gray-800">
        {editingStudent ? 'Edit Student' : 'Add Student'}
      </h2>

      <form on:submit|preventDefault={handleSubmit} class="space-y-4">
        <!-- Photo Upload -->
        <div>
          <label class="block mb-2 text-sm font-medium text-gray-700">
            Student Photo
          </label>
          {#if photoPreview}
            <div class="mb-2 text-center">
              <img src={photoPreview} alt="Preview" class="object-cover w-32 h-32 mx-auto rounded-lg shadow-md" />
              {#if compressedSize}
                <p class="mt-2 text-xs font-medium text-green-600">
                  ✓ Compressed to {compressedSize}
                </p>
              {/if}
            </div>
          {/if}
          <input
            type="file"
            accept="image/*"
            on:change={handlePhotoChange}
            class="w-full px-4 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
          <p class="mt-1 text-xs text-gray-500">Image will be automatically compressed to ~70KB</p>
        </div>

        <div>
          <label for="studentName" class="block mb-2 text-sm font-medium text-gray-700">
            Student Name *
          </label>
          <input
            type="text"
            id="studentName"
            bind:value={formData.name}
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="Enter student name"
            required
          />
        </div>

        <div>
          <label for="regNumber" class="block mb-2 text-sm font-medium text-gray-700">
            Registration Number * (max 20 digits)
          </label>
          <input
            type="text"
            id="regNumber"
            bind:value={formData.registration_number}
            maxlength="20"
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="Enter registration number"
            required
          />
        </div>

        <div>
          <label for="classroom" class="block mb-2 text-sm font-medium text-gray-700">
            Classroom
          </label>
          <select
            id="classroom"
            bind:value={formData.class_room_id}
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="">Select classroom</option>
            {#each classrooms as classroom}
              <option value={classroom.id}>{classroom.name} ({classroom.start_year}/{classroom.end_year})</option>
            {/each}
          </select>
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
            disabled={uploadingPhoto}
          >
            Cancel
          </button>
          <button
            type="submit"
            class="px-4 py-2 font-semibold text-white transition-colors bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
            disabled={uploadingPhoto}
          >
            {uploadingPhoto ? 'Uploading...' : editingStudent ? 'Update' : 'Add'}
          </button>
        </div>
      </form>
    </div>
  </div>
{/if}
