<script lang="ts">
  import Navigation from "$lib/components/Navigation.svelte";
  import Button from "$lib/components/Button.svelte";
  import { supabase } from "$lib/supabaseClient";
  import type { Student, Classroom } from "$lib/types";
  import { onMount } from "svelte";
  import imageCompression from "browser-image-compression";
  import * as XLSX from "xlsx";

  let students: (Student & { classroom?: Classroom })[] = [];
  let classrooms: Classroom[] = [];
  let loading = true;
  let showModal = false;
  let showImportModal = false;
  let editingStudent: Student | null = null;
  let formData = {
    name: "",
    registration_number: "",
    gender: "" as "L" | "P" | "",
    class_room_id: "",
  };
  let photoFile: File | null = null;
  let photoPreview: string | null = null;
  let compressedSize: string = "";
  let error = "";
  let success = "";
  let filterClassroom = "";
  let searchQuery = "";
  let uploadingPhoto = false;

  // Import related variables
  let importClassroomId = "";
  let importFile: File | null = null;
  let importData: any[] = [];
  let importPreview: any[] = [];
  let importError = "";
  let importing = false;
  let showPreview = false;

  onMount(async () => {
    await Promise.all([loadStudents(), loadClassrooms()]);
  });

  async function loadClassrooms() {
    const { data } = await supabase
      .from("master_class_room")
      .select("*")
      .order("start_year", { ascending: true });
    classrooms = data || [];
  }

  async function loadStudents() {
    loading = true;
    const { data, error: fetchError } = await supabase
      .from("students")
      .select(
        `
        *,
        classroom:master_class_room(*)
      `,
      )
      .order("name", { ascending: true });

    if (fetchError) {
      console.error("Error loading students:", fetchError);
    } else {
      students = data || [];
    }
    loading = false;
  }

  function openImportModal() {
    showImportModal = true;
    importClassroomId = "";
    importFile = null;
    importData = [];
    importPreview = [];
    importError = "";
    showPreview = false;
  }

  function closeImportModal() {
    showImportModal = false;
    importClassroomId = "";
    importFile = null;
    importData = [];
    importPreview = [];
    importError = "";
    showPreview = false;
  }

  async function handleFileUpload(event: Event) {
    const target = event.target as HTMLInputElement;
    const file = target.files?.[0];

    if (!file) return;

    if (!importClassroomId) {
      importError = "Please select a classroom first";
      return;
    }

    importFile = file;
    importError = "";
    showPreview = false;

    try {
      const data = await file.arrayBuffer();
      const workbook = XLSX.read(data);
      const sheetName = workbook.SheetNames[0];
      const worksheet = workbook.Sheets[sheetName];
      const jsonData = XLSX.utils.sheet_to_json(worksheet);

      if (jsonData.length === 0) {
        importError = "Excel file is empty";
        return;
      }

      // Validate and process data
      const processedData = jsonData.map((row: any, index: number) => {
        const errors: string[] = [];

        // Normalize column names (case-insensitive)
        const normalizedRow: any = {};
        Object.keys(row).forEach((key) => {
          normalizedRow[key.toLowerCase().trim()] = row[key];
        });

        const name = normalizedRow.name || normalizedRow.nama || "";
        const registration_number =
          normalizedRow.registration_number ||
          normalizedRow.nis ||
          normalizedRow.nomor_induk ||
          "";
        let gender =
          normalizedRow.gender ||
          normalizedRow.jenis_kelamin ||
          normalizedRow["jenis kelamin"] ||
          "";

        // Validate required fields
        if (!name || name.toString().trim() === "") {
          errors.push("Name is required");
        }

        if (
          !registration_number ||
          registration_number.toString().trim() === ""
        ) {
          errors.push("Registration number is required");
        }

        if (registration_number && registration_number.toString().length > 20) {
          errors.push("Registration number must not exceed 20 characters");
        }

        // Normalize gender
        if (gender) {
          gender = gender.toString().toUpperCase().trim();
          if (
            gender === "L" ||
            gender === "LAKI-LAKI" ||
            gender === "LAKI" ||
            gender === "M" ||
            gender === "MALE"
          ) {
            gender = "L";
          } else if (
            gender === "P" ||
            gender === "PEREMPUAN" ||
            gender === "F" ||
            gender === "FEMALE"
          ) {
            gender = "P";
          } else {
            gender = "";
          }
        }

        return {
          rowNumber: index + 2, // Excel row number (1 is header)
          name: name.toString().trim(),
          registration_number: registration_number.toString().trim(),
          gender: gender || null,
          errors,
          valid: errors.length === 0,
        };
      });

      importData = processedData;
      importPreview = processedData.slice(0, 10); // Show first 10 rows
      showPreview = true;

      const validCount = processedData.filter((d: any) => d.valid).length;
      const invalidCount = processedData.length - validCount;

      if (invalidCount > 0) {
        importError = `Found ${invalidCount} invalid row(s). Please fix the errors before importing.`;
      }
    } catch (err) {
      console.error("Error parsing Excel file:", err);
      importError =
        "Failed to parse Excel file. Please ensure it is a valid Excel file (.xlsx or .xls)";
    }
  }

  async function handleImport() {
    if (!importClassroomId) {
      importError = "Please select a classroom";
      return;
    }

    if (importData.length === 0) {
      importError = "No data to import";
      return;
    }

    const validData = importData.filter((d: any) => d.valid);

    if (validData.length === 0) {
      importError = "No valid data to import";
      return;
    }

    importing = true;
    importError = "";

    try {
      // Prepare data for bulk insert
      const studentsToInsert = validData.map((d: any) => ({
        name: d.name,
        registration_number: d.registration_number,
        gender: d.gender,
        class_room_id: importClassroomId,
        photo_url: null,
      }));

      // Insert all students at once
      const { data, error: insertError } = await supabase
        .from("students")
        .insert(studentsToInsert);

      if (insertError) {
        importError = `Failed to import: ${insertError.message}`;
      } else {
        success = `Successfully imported ${validData.length} student(s)!`;
        closeImportModal();
        await loadStudents();
        setTimeout(() => (success = ""), 5000);
      }
    } catch (err) {
      console.error("Error importing students:", err);
      importError = "An unexpected error occurred during import";
    } finally {
      importing = false;
    }
  }

  function openAddModal() {
    editingStudent = null;
    formData = {
      name: "",
      registration_number: "",
      gender: "",
      class_room_id: "",
    };
    photoFile = null;
    photoPreview = null;
    error = "";
    showModal = true;
  }

  function openEditModal(student: Student) {
    editingStudent = student;
    formData = {
      name: student.name,
      registration_number: student.registration_number,
      gender: student.gender || "",
      class_room_id: student.class_room_id || "",
    };
    photoFile = null;
    photoPreview = student.photo_url;
    error = "";
    showModal = true;
  }

  function closeModal() {
    showModal = false;
    editingStudent = null;
    formData = {
      name: "",
      registration_number: "",
      gender: "",
      class_room_id: "",
    };
    photoFile = null;
    photoPreview = null;
    error = "";
  }

  async function handlePhotoChange(event: Event) {
    const target = event.target as HTMLInputElement;
    const file = target.files?.[0];

    if (file) {
      if (file.size > 5 * 1024 * 1024) {
        error = "Photo size must be less than 5MB";
        return;
      }

      if (!file.type.startsWith("image/")) {
        error = "Please upload an image file";
        return;
      }

      error = "";

      try {
        // Compress the image to approximately 70KB
        const options = {
          maxSizeMB: 0.07, // 70KB
          maxWidthOrHeight: 800,
          useWebWorker: true,
          initialQuality: 0.8,
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
        console.error("Error compressing image:", err);
        error = "Failed to compress image. Please try another photo.";
      }
    }
  }

  async function uploadPhoto(file: File): Promise<string | null> {
    uploadingPhoto = true;
    try {
      const fileExt = file.name.split(".").pop();
      const fileName = `${Math.random().toString(36).substring(2)}-${Date.now()}.${fileExt}`;
      const filePath = `${fileName}`;

      const { error: uploadError } = await supabase.storage
        .from("student-photos")
        .upload(filePath, file);

      if (uploadError) {
        throw uploadError;
      }

      const {
        data: { publicUrl },
      } = supabase.storage.from("student-photos").getPublicUrl(filePath);

      return publicUrl;
    } catch (err) {
      console.error("Error uploading photo:", err);
      return null;
    } finally {
      uploadingPhoto = false;
    }
  }

  async function handleSubmit() {
    if (!formData.name.trim()) {
      error = "Student name is required";
      return;
    }

    if (!formData.registration_number.trim()) {
      error = "Registration number is required";
      return;
    }

    if (formData.registration_number.length > 20) {
      error = "Registration number must not exceed 20 characters";
      return;
    }

    let photo_url = editingStudent?.photo_url || null;

    // Upload new photo if provided
    if (photoFile) {
      const uploadedUrl = await uploadPhoto(photoFile);
      if (uploadedUrl) {
        photo_url = uploadedUrl;
      } else {
        error = "Failed to upload photo";
        return;
      }
    }

    if (editingStudent) {
      // Update existing student
      const { error: updateError } = await supabase
        .from("students")
        .update({
          name: formData.name,
          registration_number: formData.registration_number,
          gender: formData.gender || null,
          class_room_id: formData.class_room_id || null,
          photo_url,
          updated_at: new Date().toISOString(),
        })
        .eq("id", editingStudent.id);

      if (updateError) {
        error = updateError.message;
      } else {
        success = "Student updated successfully!";
        closeModal();
        await loadStudents();
        setTimeout(() => (success = ""), 3000);
      }
    } else {
      // Add new student
      const { error: insertError } = await supabase.from("students").insert([
        {
          name: formData.name,
          registration_number: formData.registration_number,
          gender: formData.gender || null,
          class_room_id: formData.class_room_id || null,
          photo_url,
        },
      ]);

      if (insertError) {
        error = insertError.message;
      } else {
        success = "Student added successfully!";
        closeModal();
        await loadStudents();
        setTimeout(() => (success = ""), 3000);
      }
    }
  }

  async function handleDelete(student: Student) {
    if (!confirm(`Are you sure you want to delete "${student.name}"?`)) {
      return;
    }

    const { error: deleteError } = await supabase
      .from("students")
      .delete()
      .eq("id", student.id);

    if (deleteError) {
      error = deleteError.message;
      setTimeout(() => (error = ""), 3000);
    } else {
      success = "Student deleted successfully!";
      await loadStudents();
      setTimeout(() => (success = ""), 3000);
    }
  }

  $: filteredStudents = students.filter((student) => {
    const matchesClassroom =
      !filterClassroom || student.class_room_id === filterClassroom;
    const matchesSearch =
      !searchQuery ||
      student.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      student.registration_number
        .toLowerCase()
        .includes(searchQuery.toLowerCase());
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
      <h1 class="text-3xl font-bold text-gray-800">Master Siswa</h1>
      <div class="flex gap-3">
        <Button on:click={openImportModal} variant="success">
          📥 Import Data Siswa
        </Button>
        <Button on:click={openAddModal}>+ Tambah data</Button>
      </div>
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

    <!-- Filters -->
    <div
      class="grid grid-cols-1 gap-4 p-4 mb-6 bg-white rounded-lg shadow-md md:grid-cols-2"
    >
      <div>
        <label
          for="search"
          class="block mb-2 text-sm font-medium text-gray-700"
        >
          Cari berdasarkan nama atau NIS
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
        <label
          for="filter"
          class="block mb-2 text-sm font-medium text-gray-700"
        >
          Filter ruang kelas
        </label>
        <select
          id="filter"
          bind:value={filterClassroom}
          class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        >
          <option value="">Semua ruang kelas</option>
          {#each classrooms as classroom}
            <option value={classroom.id}
              >{classroom.name} ({classroom.start_year}/{classroom.end_year})</option
            >
          {/each}
        </select>
      </div>
    </div>

    {#if loading}
      <div class="text-center">
        <div
          class="w-12 h-12 mx-auto border-b-2 border-blue-600 rounded-full animate-spin"
        ></div>
        <p class="mt-4 text-gray-600">Loading siswa...</p>
      </div>
    {:else if filteredStudents.length === 0}
      <div class="p-8 text-center bg-white rounded-lg shadow-md">
        <p class="text-gray-600">
          Tidak ada siswa yang ditemukan. Tambah data pertama!
        </p>
      </div>
    {:else}
      <div class="overflow-hidden bg-white rounded-lg shadow-md">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th
                class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                >Photo</th
              >
              <th
                class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                >Nama</th
              >
              <th
                class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                >Nomor Induk Siswa</th
              >
              <th
                class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                >Jenis Kelamin</th
              >
              <th
                class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                >Ruang Kelas</th
              >
              <th
                class="px-6 py-3 text-xs font-medium tracking-wider text-right text-gray-500 uppercase"
                >Actions</th
              >
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each filteredStudents as student}
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  {#if student.photo_url}
                    <img
                      src={student.photo_url}
                      alt={student.name}
                      class="object-cover w-12 h-12 rounded-full"
                    />
                  {:else}
                    <div
                      class="flex items-center justify-center w-12 h-12 text-white bg-gray-400 rounded-full"
                    >
                      {student.name.charAt(0).toUpperCase()}
                    </div>
                  {/if}
                </td>
                <td
                  class="px-6 py-4 text-sm font-medium text-gray-900 whitespace-nowrap"
                  >{student.name}</td
                >
                <td class="px-6 py-4 text-sm text-gray-500 whitespace-nowrap"
                  >{student.registration_number}</td
                >
                <td class="px-6 py-4 text-sm text-gray-500 whitespace-nowrap">
                  {#if student.gender === "L"}
                    <span
                      class="px-2 py-1 text-xs font-semibold text-blue-800 bg-blue-100 rounded-full"
                      >Laki-Laki</span
                    >
                  {:else if student.gender === "P"}
                    <span
                      class="px-2 py-1 text-xs font-semibold text-pink-800 bg-pink-100 rounded-full"
                      >Perempuan</span
                    >
                  {:else}
                    <span class="text-gray-400">-</span>
                  {/if}
                </td>
                <td class="px-6 py-4 text-sm text-gray-500 whitespace-nowrap">
                  {#if student.classroom}
                    {student.classroom.name} ({student.classroom
                      .start_year}/{student.classroom.end_year})
                  {:else}
                    <span class="text-gray-400">Not assigned</span>
                  {/if}
                </td>
                <td
                  class="px-6 py-4 space-x-2 text-sm font-medium text-right whitespace-nowrap"
                >
                  <Button
                    variant="link"
                    class="text-blue-600 hover:text-blue-900"
                    on:click={() => openEditModal(student)}
                  >
                    Edit
                  </Button>
                  <Button
                    variant="link"
                    class="text-red-600 hover:text-red-900"
                    on:click={() => handleDelete(student)}
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
    class="fixed inset-0 z-50 flex items-center justify-center p-4 overflow-y-auto bg-black bg-opacity-50"
  >
    <div class="w-full max-w-md p-6 my-8 bg-white rounded-lg shadow-xl">
      <h2 class="mb-4 text-2xl font-bold text-gray-800">
        {editingStudent ? "Edit Siswa" : "Tambah Siswa"}
      </h2>

      <form on:submit|preventDefault={handleSubmit} class="space-y-4">
        <!-- Photo Upload -->
        <div>
          <label class="block mb-2 text-sm font-medium text-gray-700">
            Student Photo
          </label>
          {#if photoPreview}
            <div class="mb-2 text-center">
              <img
                src={photoPreview}
                alt="Preview"
                class="object-cover w-32 h-32 mx-auto rounded-lg shadow-md"
              />
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
          <p class="mt-1 text-xs text-gray-500">
            Image will be automatically compressed to ~70KB
          </p>
        </div>

        <div>
          <label
            for="studentName"
            class="block mb-2 text-sm font-medium text-gray-700"
          >
            Nama Siswa *
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
          <label
            for="regNumber"
            class="block mb-2 text-sm font-medium text-gray-700"
          >
            NIS * (max 20 digits)
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
          <label
            for="gender"
            class="block mb-2 text-sm font-medium text-gray-700"
          >
            Jenis Kelamin
          </label>
          <select
            id="gender"
            bind:value={formData.gender}
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="">Pilih jenis kelamin</option>
            <option value="L">Laki-Laki</option>
            <option value="P">Perempuan</option>
          </select>
        </div>

        <div>
          <label
            for="classroom"
            class="block mb-2 text-sm font-medium text-gray-700"
          >
            Ruang Kelas
          </label>
          <select
            id="classroom"
            bind:value={formData.class_room_id}
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="">Pilih ruang kelas</option>
            {#each classrooms as classroom}
              <option value={classroom.id}
                >{classroom.name} ({classroom.start_year}/{classroom.end_year})</option
              >
            {/each}
          </select>
        </div>

        {#if error}
          <div
            class="p-3 text-sm text-red-700 bg-red-100 border border-red-400 rounded"
          >
            {error}
          </div>
        {/if}

        <div class="flex justify-end space-x-3">
          <Button
            type="button"
            variant="secondary"
            on:click={closeModal}
            disabled={uploadingPhoto}
          >
            Cancel
          </Button>
          <Button
            type="submit"
            disabled={uploadingPhoto}
            loading={uploadingPhoto}
          >
            {uploadingPhoto
              ? "Uploading..."
              : editingStudent
                ? "Update"
                : "Add"}
          </Button>
        </div>
      </form>
    </div>
  </div>
{/if}

<!-- Import Modal -->
{#if showImportModal}
  <div
    class="fixed inset-0 z-50 flex items-center justify-center p-4 overflow-y-auto bg-black bg-opacity-50"
  >
    <div class="w-full max-w-4xl p-6 my-8 bg-white rounded-lg shadow-xl">
      <h2 class="mb-4 text-2xl font-bold text-gray-800">
        Import Siswa dari Excel
      </h2>

      <div class="space-y-4">
        <!-- Instructions -->
        <div class="p-4 border-l-4 border-blue-500 bg-blue-50">
          <h3 class="mb-2 font-semibold text-blue-900">Excel File:</h3>
          <ul class="text-sm text-blue-800 list-disc list-inside">
            <li>
              Column headers: <strong>name</strong>, <strong>gender</strong>,
              <strong>registration_number</strong>
            </li>
            <li>Gender values: "L" (Laki-Laki) or "P" (Perempuan)</li>
            <!-- <li>Alternative column names accepted: nama, nis, nomor_induk, jenis_kelamin</li> -->
            <li>Nomor Induk Siswa (NIS) max 20 karakter</li>
          </ul>
        </div>

        <!-- Classroom Selection -->
        <div>
          <label
            for="importClassroom"
            class="block mb-2 text-sm font-medium text-gray-700"
          >
            Pilih ruang kelas * (Data siswa yang diimpor akan dimasukkan ke
            dalam ruang kelas ini)
          </label>
          <select
            id="importClassroom"
            bind:value={importClassroomId}
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
            required
          >
            <option value="">-- Pilih ruang kelas --</option>
            {#each classrooms as classroom}
              <option value={classroom.id}
                >{classroom.name} ({classroom.start_year}/{classroom.end_year})</option
              >
            {/each}
          </select>
        </div>

        <!-- File Upload -->
        <div>
          <label
            for="importFile"
            class="block mb-2 text-sm font-medium text-gray-700"
          >
            Upload Excel File (.xlsx, .xls)
          </label>
          <input
            type="file"
            id="importFile"
            accept=".xlsx,.xls"
            on:change={handleFileUpload}
            class="w-full px-4 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
            disabled={!importClassroomId}
          />
          {#if !importClassroomId}
            <p class="mt-1 text-xs text-gray-500">
              Mohon pilih ruang kelas terlebih dahulu.
            </p>
          {/if}
        </div>

        {#if importError}
          <div
            class="p-3 text-sm text-red-700 bg-red-100 border border-red-400 rounded"
          >
            {importError}
          </div>
        {/if}

        <!-- Preview Table -->
        {#if showPreview && importPreview.length > 0}
          <div class="mt-4">
            <h3 class="mb-2 font-semibold text-gray-800">
              Preview (showing {importPreview.length} of {importData.length} rows)
            </h3>
            <div class="overflow-x-auto border border-gray-300 rounded-lg">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th
                      class="px-4 py-2 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                      >Row</th
                    >
                    <th
                      class="px-4 py-2 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                      >Name</th
                    >
                    <th
                      class="px-4 py-2 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                      >Registration Number</th
                    >
                    <th
                      class="px-4 py-2 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                      >Gender</th
                    >
                    <th
                      class="px-4 py-2 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                      >Status</th
                    >
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  {#each importPreview as row}
                    <tr class={row.valid ? "" : "bg-red-50"}>
                      <td
                        class="px-4 py-2 text-sm text-gray-500 whitespace-nowrap"
                        >{row.rowNumber}</td
                      >
                      <td
                        class="px-4 py-2 text-sm text-gray-900 whitespace-nowrap"
                        >{row.name}</td
                      >
                      <td
                        class="px-4 py-2 text-sm text-gray-900 whitespace-nowrap"
                        >{row.registration_number}</td
                      >
                      <td
                        class="px-4 py-2 text-sm text-gray-900 whitespace-nowrap"
                      >
                        {#if row.gender === "L"}
                          <span
                            class="px-2 py-1 text-xs font-semibold text-blue-800 bg-blue-100 rounded-full"
                            >Laki-Laki</span
                          >
                        {:else if row.gender === "P"}
                          <span
                            class="px-2 py-1 text-xs font-semibold text-pink-800 bg-pink-100 rounded-full"
                            >Perempuan</span
                          >
                        {:else}
                          <span class="text-gray-400">-</span>
                        {/if}
                      </td>
                      <td class="px-4 py-2 text-sm whitespace-nowrap">
                        {#if row.valid}
                          <span
                            class="px-2 py-1 text-xs font-semibold text-green-800 bg-green-100 rounded-full"
                            >✓ Valid</span
                          >
                        {:else}
                          <span
                            class="px-2 py-1 text-xs font-semibold text-red-800 bg-red-100 rounded-full"
                            >✗ Invalid</span
                          >
                          <div class="mt-1 text-xs text-red-600">
                            {#each row.errors as error}
                              <div>• {error}</div>
                            {/each}
                          </div>
                        {/if}
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
            <p class="mt-2 text-sm text-gray-600">
              Total: {importData.length} rows | Valid: {importData.filter(
                (d) => d.valid,
              ).length} | Invalid: {importData.filter((d) => !d.valid).length}
            </p>
          </div>
        {/if}

        <!-- Action Buttons -->
        <div class="flex justify-end space-x-3">
          <button
            type="button"
            on:click={closeImportModal}
            class="px-4 py-2 text-gray-700 transition-colors bg-gray-200 rounded-lg hover:bg-gray-300"
            disabled={importing}
          >
            Cancel
          </button>
          {#if showPreview && importData.filter((d) => d.valid).length > 0}
            <button
              type="button"
              on:click={handleImport}
              class="px-4 py-2 font-semibold text-white transition-colors bg-green-600 rounded-lg hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
              disabled={importing}
            >
              {importing
                ? "Importing..."
                : `Import ${importData.filter((d) => d.valid).length} Student(s)`}
            </button>
          {/if}
        </div>
      </div>
    </div>
  </div>
{/if}
