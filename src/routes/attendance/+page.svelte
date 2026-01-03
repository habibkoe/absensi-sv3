<script lang="ts">
  import Navigation from '$lib/components/Navigation.svelte';
  import { supabase } from '$lib/supabaseClient';
  import type { Student, Classroom, Attendance } from '$lib/types';
  import { AttendanceStatus } from '$lib/types';
  import { onMount } from 'svelte';

  let classrooms: Classroom[] = [];
  let students: Student[] = [];
  let selectedClassroom = '';
  let selectedDate = new Date().toISOString().split('T')[0];
  let attendanceRecords: Map<string, number> = new Map();
  let loading = false;
  let saving = false;
  let error = '';
  let success = '';

  onMount(async () => {
    await loadClassrooms();
  });

  async function loadClassrooms() {
    const { data } = await supabase
      .from('master_class_room')
      .select('*')
      .order('start_year', { ascending: true });
    classrooms = data || [];
  }

  async function loadStudents() {
    if (!selectedClassroom) return;

    loading = true;
    error = '';

    try {
      // Load students for the selected classroom
      const { data: studentsData, error: studentsError } = await supabase
        .from('students')
        .select('*')
        .eq('class_room_id', selectedClassroom)
        .order('name', { ascending: true });

      if (studentsError) throw studentsError;

      students = studentsData || [];

      // Load existing attendance records for the selected date
      const { data: attendanceData, error: attendanceError } = await supabase
        .from('attendance')
        .select('*')
        .eq('class_room_id', selectedClassroom)
        .eq('date', selectedDate);

      if (attendanceError) throw attendanceError;

      // Populate attendance map
      attendanceRecords = new Map();
      if (attendanceData) {
        attendanceData.forEach((record: Attendance) => {
          attendanceRecords.set(record.student_id, record.attendance_status);
        });
      }

      // Initialize with Hadir (Present) status for students without records
      students.forEach(student => {
        if (!attendanceRecords.has(student.id)) {
          attendanceRecords.set(student.id, AttendanceStatus.Hadir);
        }
      });

      // Trigger reactivity
      attendanceRecords = attendanceRecords;
    } catch (err) {
      console.error('Error loading data:', err);
      error = 'Failed to load students and attendance records';
    }

    loading = false;
  }

  function setAttendance(studentId: string, status: number) {
    attendanceRecords.set(studentId, status);
    attendanceRecords = attendanceRecords;
  }

  function markAllAs(status: number) {
    students.forEach(student => {
      attendanceRecords.set(student.id, status);
    });
    attendanceRecords = attendanceRecords;
  }

  async function saveAttendance() {
    if (!selectedClassroom || students.length === 0) {
      error = 'Please select a classroom with students';
      return;
    }

    saving = true;
    error = '';

    try {
      // Prepare attendance records
      const records = students.map(student => ({
        student_id: student.id,
        class_room_id: selectedClassroom,
        attendance_status: attendanceRecords.get(student.id) || AttendanceStatus.Hadir,
        date: selectedDate
      }));

      // Delete existing records for this classroom and date
      const { error: deleteError } = await supabase
        .from('attendance')
        .delete()
        .eq('class_room_id', selectedClassroom)
        .eq('date', selectedDate);

      if (deleteError) throw deleteError;

      // Insert new records
      const { error: insertError } = await supabase
        .from('attendance')
        .insert(records);

      if (insertError) throw insertError;

      success = 'Attendance saved successfully!';
      setTimeout(() => (success = ''), 3000);
    } catch (err: any) {
      console.error('Error saving attendance:', err);
      error = err.message || 'Failed to save attendance';
    }

    saving = false;
  }

  function getStatusColor(status: number): string {
    switch (status) {
      case AttendanceStatus.Hadir:
        return 'bg-green-100 text-green-800 border-green-300';
      case AttendanceStatus.Alpa:
        return 'bg-red-100 text-red-800 border-red-300';
      case AttendanceStatus.Sakit:
        return 'bg-yellow-100 text-yellow-800 border-yellow-300';
      case AttendanceStatus.Izin:
        return 'bg-blue-100 text-blue-800 border-blue-300';
      case AttendanceStatus.Bolos:
        return 'bg-orange-100 text-orange-800 border-orange-300';
      case AttendanceStatus.Tugas:
        return 'bg-purple-100 text-purple-800 border-purple-300';
      default:
        return 'bg-gray-100 text-gray-800 border-gray-300';
    }
  }

  function getStatusText(status: number): string {
    switch (status) {
      case AttendanceStatus.Hadir:
        return '✓ Hadir';
      case AttendanceStatus.Alpa:
        return '✗ Alpa';
      case AttendanceStatus.Sakit:
        return '🤒 Sakit';
      case AttendanceStatus.Izin:
        return '📋 Izin';
      case AttendanceStatus.Bolos:
        return '🚫 Bolos';
      case AttendanceStatus.Tugas:
        return '📝 Tugas';
      default:
        return 'Unknown';
    }
  }


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
      <div class="p-4 mb-4 text-green-700 bg-green-100 border border-green-400 rounded">
        {success}
      </div>
    {/if}

    {#if error}
      <div class="p-4 mb-4 text-red-700 bg-red-100 border border-red-400 rounded">
        {error}
      </div>
    {/if}

    <!-- Selection Panel -->
    <div class="p-6 mb-6 bg-white rounded-lg shadow-md">
      <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
        <div>
          <label for="classroom" class="block mb-2 text-sm font-medium text-gray-700">
            Ruang Kelas *
          </label>
          <select
            id="classroom"
            bind:value={selectedClassroom}
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="">pilih ruang kelas</option>
            {#each classrooms as classroom}
              <option value={classroom.id}>{classroom.name} ({classroom.start_year}/{classroom.end_year})</option>
            {/each}
          </select>
        </div>

        <div>
          <label for="date" class="block mb-2 text-sm font-medium text-gray-700">
            Tanggal *
          </label>
          <input
            type="date"
            id="date"
            bind:value={selectedDate}
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>
      </div>
    </div>

    {#if loading}
      <div class="text-center">
        <div class="w-12 h-12 mx-auto border-b-2 border-blue-600 rounded-full animate-spin"></div>
        <p class="mt-4 text-gray-600">Loading siswa...</p>
      </div>
    {:else if selectedClassroom && students.length === 0}
      <div class="p-8 text-center bg-white rounded-lg shadow-md">
        <p class="text-gray-600">Siswa tidak ditemukan di kelas ini. Tolong tambah dulu.</p>
        <a href="/students" class="inline-block px-4 py-2 mt-4 text-white bg-blue-600 rounded-lg hover:bg-blue-700">
          Siswa
        </a>
      </div>
    {:else if selectedClassroom && students.length > 0}
      <!-- Quick Actions -->
      <div class="p-4 mb-6 bg-white rounded-lg shadow-md">
        <h2 class="mb-3 text-lg font-semibold text-gray-800">Aksi cepat</h2>
        <div class="flex flex-wrap gap-2">
          <button
            on:click={() => markAllAs(AttendanceStatus.Hadir)}
            class="px-4 py-2 text-white transition-colors bg-green-600 rounded-lg hover:bg-green-700"
          >
            Hadir semua
          </button>
          <button
            on:click={() => markAllAs(AttendanceStatus.Alpa)}
            class="px-4 py-2 text-white transition-colors bg-red-600 rounded-lg hover:bg-red-700"
          >
            Alpa semua
          </button>
          <button
            on:click={() => markAllAs(AttendanceStatus.Sakit)}
            class="px-4 py-2 text-white transition-colors bg-yellow-600 rounded-lg hover:bg-yellow-700"
          >
            Sakit semua
          </button>
          <button
            on:click={() => markAllAs(AttendanceStatus.Izin)}
            class="px-4 py-2 text-white transition-colors bg-blue-600 rounded-lg hover:bg-blue-700"
          >
            Izin semua
          </button>
          <button
            on:click={() => markAllAs(AttendanceStatus.Bolos)}
            class="px-4 py-2 text-white transition-colors bg-orange-600 rounded-lg hover:bg-orange-700"
          >
            Bolos semua
          </button>
          <button
            on:click={() => markAllAs(AttendanceStatus.Tugas)}
            class="px-4 py-2 text-white transition-colors bg-purple-600 rounded-lg hover:bg-purple-700"
          >
            Tugas semua
          </button>
        </div>
      </div>

      <!-- Students List -->
      <div class="p-6 mb-6 bg-white rounded-lg shadow-md">
        <h2 class="mb-4 text-lg font-semibold text-gray-800">
          Siswa ({students.length})
        </h2>
        <div class="space-y-3">
          {#each students as student}
            <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:bg-gray-50">
              <div class="flex items-center space-x-3">
                {#if student.photo_url}
                  <img src={student.photo_url} alt={student.name} class="object-cover w-12 h-12 rounded-full" />
                {:else}
                  <div class="flex items-center justify-center w-12 h-12 text-white bg-gray-400 rounded-full">
                    {student.name.charAt(0).toUpperCase()}
                  </div>
                {/if}
                <div>
                  <p class="font-medium text-gray-900">{student.name}</p>
                  <p class="text-sm text-gray-500">{student.registration_number}</p>
                </div>
              </div>

              <div class="flex flex-wrap gap-2">
                <button
                  on:click={() => setAttendance(student.id, AttendanceStatus.Hadir)}
                  class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg {attendanceRecords.get(student.id) === AttendanceStatus.Hadir
                    ? 'bg-green-600 text-white border-green-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-green-50'}"
                >
                  Hadir
                </button>
                <button
                  on:click={() => setAttendance(student.id, AttendanceStatus.Alpa)}
                  class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg {attendanceRecords.get(student.id) === AttendanceStatus.Alpa
                    ? 'bg-red-600 text-white border-red-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-red-50'}"
                >
                  Alpa
                </button>
                <button
                  on:click={() => setAttendance(student.id, AttendanceStatus.Sakit)}
                  class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg {attendanceRecords.get(student.id) === AttendanceStatus.Sakit
                    ? 'bg-yellow-600 text-white border-yellow-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-yellow-50'}"
                >
                  Sakit
                </button>
                <button
                  on:click={() => setAttendance(student.id, AttendanceStatus.Izin)}
                  class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg {attendanceRecords.get(student.id) === AttendanceStatus.Izin
                    ? 'bg-blue-600 text-white border-blue-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-blue-50'}"
                >
                  Izin
                </button>
                <button
                  on:click={() => setAttendance(student.id, AttendanceStatus.Bolos)}
                  class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg {attendanceRecords.get(student.id) === AttendanceStatus.Bolos
                    ? 'bg-orange-600 text-white border-orange-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-orange-50'}"
                >
                  Bolos
                </button>
                {#if !attendanceRecords.get(student.id) || attendanceRecords.get(student.id) === AttendanceStatus.Hadir}
                  <button
                    on:click={() => setAttendance(student.id, AttendanceStatus.Tugas)}
                    class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg {attendanceRecords.get(student.id) === AttendanceStatus.Tugas
                      ? 'bg-purple-600 text-white border-purple-600'
                      : 'bg-white text-gray-700 border-gray-300 hover:bg-purple-50'}"
                  >
                    Tugas
                  </button>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      </div>

      <!-- Save Button -->
      <div class="flex justify-end">
        <button
          on:click={saveAttendance}
          disabled={saving}
          class="px-6 py-3 text-lg font-semibold text-white transition-colors bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {saving ? 'Saving...' : 'Save Attendance'}
        </button>
      </div>
    {:else}
      <div class="p-8 text-center bg-white rounded-lg shadow-md">
        <p class="text-gray-600">Pilih kelas dan tanggal untuk memulai absensi.</p>
      </div>
    {/if}
  </div>
</div>
