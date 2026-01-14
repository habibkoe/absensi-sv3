<script lang="ts">
  import Navigation from "$lib/components/Navigation.svelte";
  import Button from "$lib/components/Button.svelte";
  import Input from "$lib/components/Input.svelte";
  import { supabase } from "$lib/supabaseClient";
  import type { Student, Classroom, Attendance } from "$lib/types";
  import { AttendanceStatus } from "$lib/types";
  import { onMount } from "svelte";

  let classrooms: Classroom[] = [];
  let students: Student[] = [];
  let selectedClassroom = "";
  let selectedDate = new Date().toISOString().split("T")[0];
  let studentFilter = "";
  let attendanceRecords: Map<string, number> = new Map();
  let autoScoreRecords: Map<string, boolean> = new Map();
  let scoreNominalRecords: Map<string, number> = new Map();
  let loading = false;
  let saving = false;
  let error = "";
  let success = "";

  // Time-based validation for editing
  function isEditingAllowed(selectedDate: string): boolean {
    const now = new Date(); // Already in Asia/Makassar timezone (GMT+8)
    const selected = new Date(selectedDate + "T00:00:00");
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const selectedDay = new Date(
      selected.getFullYear(),
      selected.getMonth(),
      selected.getDate(),
    );

    // If selected date is in the future, allow editing
    if (selectedDay > today) {
      return true;
    }

    // If selected date is today, check if time is before 12:00 PM
    if (selectedDay.getTime() === today.getTime()) {
      const currentHour = now.getHours();
      return currentHour < 12;
    }

    // If selected date is in the past, block editing
    return false;
  }

  // Reactive variable to check if editing is allowed for the selected date
  $: canEdit = isEditingAllowed(selectedDate);

  // Get appropriate warning message
  $: warningMessage = !canEdit ? getWarningMessage(selectedDate) : "";

  function getWarningMessage(date: string): string {
    const now = new Date();
    const selected = new Date(date + "T00:00:00");
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const selectedDay = new Date(
      selected.getFullYear(),
      selected.getMonth(),
      selected.getDate(),
    );

    if (selectedDay.getTime() === today.getTime()) {
      return `Waktu edit telah berakhir. Absensi untuk tanggal ${date} sudah final karena telah melewati pukul 12:00.`;
    } else {
      return `Absensi untuk tanggal ${date} sudah final dan tidak dapat diubah.`;
    }
  }

  onMount(async () => {
    await loadClassrooms();
  });

  async function loadClassrooms() {
    const { data } = await supabase
      .from("master_class_room")
      .select("*")
      .order("start_year", { ascending: true });
    classrooms = data || [];
  }

  async function loadStudents() {
    if (!selectedClassroom) return;

    loading = true;
    error = "";

    try {
      // Load students for the selected classroom
      const { data: studentsData, error: studentsError } = await supabase
        .from("students")
        .select("*")
        .eq("class_room_id", selectedClassroom)
        .order("name", { ascending: true });

      if (studentsError) throw studentsError;

      students = studentsData || [];

      // Load existing attendance records for the selected date
      const { data: attendanceData, error: attendanceError } = await supabase
        .from("attendance")
        .select("*")
        .eq("class_room_id", selectedClassroom)
        .eq("date", selectedDate);

      if (attendanceError) throw attendanceError;

      // Populate attendance map and score data
      attendanceRecords = new Map();
      autoScoreRecords = new Map();
      scoreNominalRecords = new Map();

      if (attendanceData) {
        attendanceData.forEach((record: Attendance) => {
          attendanceRecords.set(record.student_id, record.attendance_status);
          if (record.is_auto_score !== undefined) {
            autoScoreRecords.set(record.student_id, record.is_auto_score);
          }
          if (record.score_nominal !== undefined) {
            scoreNominalRecords.set(record.student_id, record.score_nominal);
          }
        });
      }

      // Initialize with Hadir (Present) status for students without records
      students.forEach((student) => {
        if (!attendanceRecords.has(student.id)) {
          attendanceRecords.set(student.id, AttendanceStatus.Hadir);
        }
      });

      // Trigger reactivity
      attendanceRecords = attendanceRecords;
      autoScoreRecords = autoScoreRecords;
      scoreNominalRecords = scoreNominalRecords;
    } catch (err) {
      console.error("Error loading data:", err);
      error = "Failed to load students and attendance records";
    }

    loading = false;
  }

  function setAttendance(studentId: string, status: number) {
    attendanceRecords.set(studentId, status);

    // Clear score data if not Tugas
    if (status !== AttendanceStatus.Tugas) {
      autoScoreRecords.delete(studentId);
      scoreNominalRecords.delete(studentId);
    }

    attendanceRecords = attendanceRecords;
  }

  function toggleAutoScore(studentId: string, value: boolean) {
    autoScoreRecords.set(studentId, value);
    if (value) {
      scoreNominalRecords.set(studentId, 100);
    }
    autoScoreRecords = autoScoreRecords;
    scoreNominalRecords = scoreNominalRecords;
  }

  function updateScoreNominal(studentId: string, value: number) {
    scoreNominalRecords.set(studentId, value);
    scoreNominalRecords = scoreNominalRecords;
  }

  function markAllAs(status: number) {
    students.forEach((student) => {
      attendanceRecords.set(student.id, status);
    });
    attendanceRecords = attendanceRecords;
  }

  async function saveAttendance() {
    if (!selectedClassroom || students.length === 0) {
      error = "Please select a classroom with students";
      return;
    }

    saving = true;
    error = "";

    try {
      // Prepare attendance records with score data
      const records = students.map((student) => {
        const status =
          attendanceRecords.get(student.id) || AttendanceStatus.Hadir;
        const record: any = {
          student_id: student.id,
          class_room_id: selectedClassroom,
          attendance_status: status,
          date: selectedDate,
        };

        // Add score data only if status is Tugas
        if (status === AttendanceStatus.Tugas) {
          const isAutoScore = autoScoreRecords.get(student.id) || false;
          record.is_auto_score = isAutoScore;

          if (isAutoScore) {
            record.score_nominal = 100;
          } else {
            const manualScore = scoreNominalRecords.get(student.id);
            record.score_nominal =
              manualScore !== undefined ? manualScore : null;
          }
        } else {
          record.is_auto_score = false;
          record.score_nominal = null;
        }

        return record;
      });

      // Delete existing records for this classroom and date
      const { error: deleteError } = await supabase
        .from("attendance")
        .delete()
        .eq("class_room_id", selectedClassroom)
        .eq("date", selectedDate);

      if (deleteError) throw deleteError;

      // Insert new records
      const { error: insertError } = await supabase
        .from("attendance")
        .insert(records);

      if (insertError) throw insertError;

      success = "Attendance saved successfully!";
      setTimeout(() => (success = ""), 3000);
    } catch (err: any) {
      console.error("Error saving attendance:", err);
      error = err.message || "Failed to save attendance";
    }

    saving = false;
  }

  function getStatusColor(status: number): string {
    switch (status) {
      case AttendanceStatus.Hadir:
        return "bg-green-100 text-green-800 border-green-300";
      case AttendanceStatus.Alpa:
        return "bg-red-100 text-red-800 border-red-300";
      case AttendanceStatus.Sakit:
        return "bg-yellow-100 text-yellow-800 border-yellow-300";
      case AttendanceStatus.Izin:
        return "bg-blue-100 text-blue-800 border-blue-300";
      case AttendanceStatus.Bolos:
        return "bg-orange-100 text-orange-800 border-orange-300";
      case AttendanceStatus.Tugas:
        return "bg-purple-100 text-purple-800 border-purple-300";
      case AttendanceStatus.Telat:
        return "bg-amber-100 text-amber-800 border-amber-300";
      default:
        return "bg-gray-100 text-gray-800 border-gray-300";
    }
  }

  function getStatusText(status: number): string {
    switch (status) {
      case AttendanceStatus.Hadir:
        return "✓ Hadir";
      case AttendanceStatus.Alpa:
        return "✗ Alpa";
      case AttendanceStatus.Sakit:
        return "🤒 Sakit";
      case AttendanceStatus.Izin:
        return "📋 Izin";
      case AttendanceStatus.Bolos:
        return "🚫 Bolos";
      case AttendanceStatus.Tugas:
        return "📝 Tugas";
      default:
        return "Unknown";
    }
  }

  // Filter students based on search term
  $: filteredStudents = students.filter((student) => {
    if (!studentFilter.trim()) return true;
    const searchTerm = studentFilter.toLowerCase();
    return (
      student.name.toLowerCase().includes(searchTerm) ||
      student.registration_number.toLowerCase().includes(searchTerm)
    );
  });

  // Check if "Tugas semua" button should be visible
  // Only show if all students are either Hadir or Tugas
  $: canShowTugasSemua = students.every((student) => {
    const status = attendanceRecords.get(student.id);
    return (
      status === AttendanceStatus.Hadir || status === AttendanceStatus.Tugas
    );
  });

  $: if (selectedClassroom || selectedDate) {
    loadStudents();
  }
</script>

<svelte:head>
  <title>Absensi Siswa - Proses Absensi</title>
  <meta name="description" content="Absensi siswa" />
</svelte:head>
<Navigation />

<div class="min-h-screen bg-gray-100">
  <div class="container px-4 py-8 mx-auto">
    <h1 class="mb-8 text-3xl font-bold text-gray-800">Absensi</h1>

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

    {#if !canEdit && selectedClassroom && students.length > 0}
      <div
        class="p-4 mb-4 text-orange-700 bg-orange-100 border border-orange-400 rounded"
      >
        <div class="flex items-center">
          <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
            <path
              fill-rule="evenodd"
              d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
              clip-rule="evenodd"
            />
          </svg>
          <span class="font-semibold">{warningMessage}</span>
        </div>
      </div>
    {/if}

    <!-- Selection Panel -->
    <div class="p-6 mb-6 bg-white rounded-lg shadow-md">
      <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
        <div>
          <label
            for="classroom"
            class="block mb-2 text-sm font-medium text-gray-700"
          >
            Ruang Kelas *
          </label>
          <select
            id="classroom"
            bind:value={selectedClassroom}
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="">pilih ruang kelas</option>
            {#each classrooms as classroom}
              <option value={classroom.id}
                >{classroom.name} ({classroom.start_year}/{classroom.end_year})</option
              >
            {/each}
          </select>
        </div>

        <Input
          type="date"
          id="date"
          label="Tanggal *"
          bind:value={selectedDate}
        />
      </div>
    </div>

    {#if loading}
      <div class="text-center">
        <div
          class="w-12 h-12 mx-auto border-b-2 border-blue-600 rounded-full animate-spin"
        ></div>
        <p class="mt-4 text-gray-600">Loading siswa...</p>
      </div>
    {:else if selectedClassroom && students.length === 0}
      <div class="p-8 text-center bg-white rounded-lg shadow-md">
        <p class="text-gray-600">
          Siswa tidak ditemukan di kelas ini. Tolong tambah dulu.
        </p>
        <a
          href="/students"
          class="inline-block px-4 py-2 mt-4 text-white bg-blue-600 rounded-lg hover:bg-blue-700"
        >
          Siswa
        </a>
      </div>
    {:else if selectedClassroom && students.length > 0}
      <!-- Quick Actions -->
      <div class="p-4 mb-6 bg-white rounded-lg shadow-md">
        <h2 class="mb-3 text-lg font-semibold text-gray-800">Aksi cepat</h2>
        <div class="flex flex-wrap gap-2">
          <Button
            on:click={() => markAllAs(AttendanceStatus.Hadir)}
            disabled={!canEdit}
            variant="success"
            size="sm"
          >
            Hadir semua
          </Button>
          <Button
            on:click={() => markAllAs(AttendanceStatus.Alpa)}
            disabled={!canEdit}
            variant="danger"
            size="sm"
          >
            Alpa semua
          </Button>
          <Button
            on:click={() => markAllAs(AttendanceStatus.Sakit)}
            disabled={!canEdit}
            variant="warning"
            size="sm"
          >
            Sakit semua
          </Button>
          <Button
            on:click={() => markAllAs(AttendanceStatus.Izin)}
            disabled={!canEdit}
            variant="info"
            size="sm"
          >
            Izin semua
          </Button>
          <Button
            on:click={() => markAllAs(AttendanceStatus.Bolos)}
            disabled={!canEdit}
            variant="warning"
            size="sm"
            class="text-white bg-orange-600 hover:bg-orange-700 focus:ring-orange-500"
          >
            Bolos semua
          </Button>
          <Button
            on:click={() => markAllAs(AttendanceStatus.Telat)}
            disabled={!canEdit}
            variant="warning"
            size="sm"
            class="text-white bg-amber-600 hover:bg-amber-700 focus:ring-amber-500"
          >
            Telat semua
          </Button>
          {#if canShowTugasSemua}
            <Button
              on:click={() => markAllAs(AttendanceStatus.Tugas)}
              disabled={!canEdit}
              variant="primary"
              size="sm"
              class="text-white bg-purple-600 hover:bg-purple-700 focus:ring-purple-500"
            >
              Tugas semua
            </Button>
          {/if}
        </div>
      </div>

      <!-- Students List -->
      <div class="p-6 mb-6 bg-white rounded-lg shadow-md">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold text-gray-800">
            Siswa ({filteredStudents.length} dari {students.length})
          </h2>
        </div>

        <!-- Student Filter/Search -->
        <div class="mb-4">
          <div class="relative">
            <input
              type="text"
              bind:value={studentFilter}
              placeholder="Cari siswa berdasarkan nama atau nomor registrasi..."
              class="w-full px-4 py-2 pl-10 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
            <svg
              class="absolute w-5 h-5 text-gray-400 left-3 top-2.5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
              />
            </svg>
            {#if studentFilter}
              <button
                on:click={() => (studentFilter = "")}
                class="absolute text-gray-400 right-3 top-2.5 hover:text-gray-600"
                type="button"
              >
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                    clip-rule="evenodd"
                  />
                </svg>
              </button>
            {/if}
          </div>
        </div>

        <div class="space-y-3">
          {#each filteredStudents as student}
            <div
              class="p-4 border border-gray-200 rounded-lg hover:bg-gray-50"
            >
              <!-- Student Info and Tugas Score (Desktop Layout) -->
              <div class="flex flex-col items-start justify-between gap-4 md:flex-row md:items-center">
                <!-- Left: Student Photo and Name -->
                <div class="flex items-center space-x-3">
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
                <div>
                  <p class="font-medium text-gray-900">{student.name}</p>
                  <p class="text-sm text-gray-500">
                    {student.registration_number}
                  </p>
                </div>
              </div>
                
                <!-- Right: Score Input UI for Tugas Status (Desktop only) -->
                {#if attendanceRecords.get(student.id) === AttendanceStatus.Tugas}
                  <div class="items-center hidden gap-4 md:flex">
                    <div class="flex items-center">
                      <input
                        type="checkbox"
                        id="auto-score-{student.id}"
                        checked={autoScoreRecords.get(student.id) || false}
                        on:change={(e) =>
                          toggleAutoScore(
                            student.id,
                            (e.currentTarget as HTMLInputElement).checked,
                          )}
                        disabled={!canEdit}
                        class="w-4 h-4 text-purple-600 border-gray-300 rounded focus:ring-purple-500 disabled:opacity-50 disabled:cursor-not-allowed"
                      />
                      <label
                        for="auto-score-{student.id}"
                        class="ml-2 text-sm font-medium text-gray-700"
                      >
                        Auto Score
                      </label>
                    </div>

                    {#if !autoScoreRecords.get(student.id)}
                      <div class="w-32">
                        <input
                          type="number"
                          id="score-{student.id}-desktop"
                          min="0"
                          max="100"
                          step="0.5"
                          value={scoreNominalRecords.get(student.id) || ""}
                          on:input={(e) => {
                            const target = e.target as HTMLInputElement;
                            updateScoreNominal(
                              student.id,
                              parseFloat(target.value) || 0,
                            );
                          }}
                          disabled={!canEdit}
                          placeholder="Nilai..."
                          class="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent disabled:opacity-50 disabled:cursor-not-allowed"
                        />
                      </div>
                    {:else}
                      <div
                        class="px-3 py-2 text-sm font-semibold text-purple-900 bg-purple-200 rounded-lg"
                      >
                        Nilai: 100
                      </div>
                    {/if}
                  </div>
                {/if}
              </div>

              <!-- Attendance Buttons (Below Student Name) -->
              <div class="flex flex-wrap gap-2 mt-3">
                <button
                  on:click={() =>
                    setAttendance(student.id, AttendanceStatus.Hadir)}
                  disabled={!canEdit}
                  class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg disabled:opacity-50 disabled:cursor-not-allowed {attendanceRecords.get(
                    student.id,
                  ) === AttendanceStatus.Hadir ||
                  attendanceRecords.get(student.id) === AttendanceStatus.Tugas
                    ? 'bg-green-600 text-white border-green-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-green-50'}"
                >
                  <span class="md:hidden">H</span>
                  <span class="hidden md:inline">Hadir</span>
                </button>
                <button
                  on:click={() =>
                    setAttendance(student.id, AttendanceStatus.Sakit)}
                  disabled={!canEdit}
                  class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg disabled:opacity-50 disabled:cursor-not-allowed {attendanceRecords.get(
                    student.id,
                  ) === AttendanceStatus.Sakit
                    ? 'bg-yellow-600 text-white border-yellow-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-yellow-50'}"
                >
                  <span class="md:hidden">S</span>
                  <span class="hidden md:inline">Sakit</span>
                </button>
                <button
                  on:click={() =>
                    setAttendance(student.id, AttendanceStatus.Izin)}
                  disabled={!canEdit}
                  class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg disabled:opacity-50 disabled:cursor-not-allowed {attendanceRecords.get(
                    student.id,
                  ) === AttendanceStatus.Izin
                    ? 'bg-blue-600 text-white border-blue-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-blue-50'}"
                >
                  <span class="md:hidden">I</span>
                  <span class="hidden md:inline">Izin</span>
                </button>
                <button
                  on:click={() =>
                    setAttendance(student.id, AttendanceStatus.Alpa)}
                  disabled={!canEdit}
                  class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg disabled:opacity-50 disabled:cursor-not-allowed {attendanceRecords.get(
                    student.id,
                  ) === AttendanceStatus.Alpa
                    ? 'bg-red-600 text-white border-red-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-red-50'}"
                >
                  <span class="md:hidden">A</span>
                  <span class="hidden md:inline">Alpa</span>
                </button>
                <button
                  on:click={() =>
                    setAttendance(student.id, AttendanceStatus.Bolos)}
                  disabled={!canEdit}
                  class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg disabled:opacity-50 disabled:cursor-not-allowed {attendanceRecords.get(
                    student.id,
                  ) === AttendanceStatus.Bolos
                    ? 'bg-orange-600 text-white border-orange-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-orange-50'}"
                >
                  <span class="md:hidden">B</span>
                  <span class="hidden md:inline">Bolos</span>
                </button>
                <button
                  on:click={() =>
                    setAttendance(student.id, AttendanceStatus.Telat)}
                  disabled={!canEdit}
                  class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg disabled:opacity-50 disabled:cursor-not-allowed {attendanceRecords.get(
                    student.id,
                  ) === AttendanceStatus.Telat
                    ? 'bg-amber-600 text-white border-amber-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-amber-50'}"
                >
                  <span class="md:hidden">T</span>
                  <span class="hidden md:inline">Telat</span>
                </button>
                {#if attendanceRecords.get(student.id) === AttendanceStatus.Hadir || attendanceRecords.get(student.id) === AttendanceStatus.Tugas}
                  <button
                    on:click={() =>
                      setAttendance(student.id, AttendanceStatus.Tugas)}
                    disabled={!canEdit}
                    class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg disabled:opacity-50 disabled:cursor-not-allowed {attendanceRecords.get(
                      student.id,
                    ) === AttendanceStatus.Tugas
                      ? 'bg-purple-600 text-white border-purple-600'
                      : 'bg-white text-gray-700 border-gray-300 hover:bg-purple-50'}"
                  >
                    Tugas
                  </button>
                {/if}
              </div>

              <!-- Score Input UI for Tugas Status (Mobile only - below buttons) -->
              {#if attendanceRecords.get(student.id) === AttendanceStatus.Tugas}
                <div
                  class="p-4 mt-3 border-l-4 border-purple-500 rounded-r-lg bg-purple-50 md:hidden"
                >
                  <h3 class="mb-3 text-sm font-semibold text-purple-900">
                    Nilai Tugas
                  </h3>

                  <div class="flex items-center mb-3">
                    <input
                      type="checkbox"
                      id="auto-score-mobile-{student.id}"
                      checked={autoScoreRecords.get(student.id) || false}
                      on:change={(e) =>
                        toggleAutoScore(
                          student.id,
                          (e.currentTarget as HTMLInputElement).checked,
                        )}
                      disabled={!canEdit}
                      class="w-4 h-4 text-purple-600 border-gray-300 rounded focus:ring-purple-500 disabled:opacity-50 disabled:cursor-not-allowed"
                    />
                    <label
                      for="auto-score-mobile-{student.id}"
                      class="ml-2 text-sm font-medium text-gray-700"
                    >
                      Auto Score
                    </label>
                  </div>

                  {#if !autoScoreRecords.get(student.id)}
                    <div>
                      <Input
                        type="number"
                        id="score-{student.id}-mobile"
                        label="Masukkan Nilai (0-100)"
                        min="0"
                        max="100"
                        step="0.5"
                        value={scoreNominalRecords.get(student.id) || ""}
                        on:input={(e) => {
                          const target = e.target as HTMLInputElement;
                          updateScoreNominal(
                            student.id,
                            parseFloat(target.value) || 0,
                          );
                        }}
                        disabled={!canEdit}
                        placeholder="Masukkan nilai..."
                      />
                    </div>
                  {:else}
                    <div
                      class="px-3 py-2 text-sm font-semibold text-purple-900 bg-purple-200 rounded-lg"
                    >
                      Nilai: 100 (Otomatis)
                    </div>
                  {/if}
                </div>
              {/if}
            </div>
          {/each}
        </div>
      </div>

      <!-- Save Button -->
      <div class="flex justify-end">
        <Button
          on:click={saveAttendance}
          disabled={saving || !canEdit}
          size="lg"
          {saving}
        >
          {saving ? "Menyimpan..." : "Simpan absensi"}
        </Button>
      </div>
    {:else}
      <div class="p-8 text-center bg-white rounded-lg shadow-md">
        <p class="text-gray-600">
          Pilih kelas dan tanggal untuk memulai absensi.
        </p>
      </div>
    {/if}
  </div>
</div>
