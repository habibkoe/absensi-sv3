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
      .order('year_of_study', { ascending: true });
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

      // Initialize absent status for students without records
      students.forEach(student => {
        if (!attendanceRecords.has(student.id)) {
          attendanceRecords.set(student.id, AttendanceStatus.Absent);
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
        attendance_status: attendanceRecords.get(student.id) || AttendanceStatus.Absent,
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
      case AttendanceStatus.Present:
        return 'bg-green-100 text-green-800 border-green-300';
      case AttendanceStatus.Absent:
        return 'bg-red-100 text-red-800 border-red-300';
      case AttendanceStatus.Late:
        return 'bg-yellow-100 text-yellow-800 border-yellow-300';
      case AttendanceStatus.Excused:
        return 'bg-blue-100 text-blue-800 border-blue-300';
      default:
        return 'bg-gray-100 text-gray-800 border-gray-300';
    }
  }

  function getStatusText(status: number): string {
    switch (status) {
      case AttendanceStatus.Present:
        return '✓ Present';
      case AttendanceStatus.Absent:
        return '✗ Absent';
      case AttendanceStatus.Late:
        return '⏰ Late';
      case AttendanceStatus.Excused:
        return '📋 Excused';
      default:
        return 'Unknown';
    }
  }

  $: if (selectedClassroom || selectedDate) {
    loadStudents();
  }
</script>

<Navigation />

<div class="min-h-screen bg-gray-100">
  <div class="container px-4 py-8 mx-auto">
    <h1 class="mb-8 text-3xl font-bold text-gray-800">Take Attendance</h1>

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
            Select Classroom *
          </label>
          <select
            id="classroom"
            bind:value={selectedClassroom}
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="">Choose a classroom</option>
            {#each classrooms as classroom}
              <option value={classroom.id}>{classroom.name} (Year {classroom.year_of_study})</option>
            {/each}
          </select>
        </div>

        <div>
          <label for="date" class="block mb-2 text-sm font-medium text-gray-700">
            Select Date *
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
        <p class="mt-4 text-gray-600">Loading students...</p>
      </div>
    {:else if selectedClassroom && students.length === 0}
      <div class="p-8 text-center bg-white rounded-lg shadow-md">
        <p class="text-gray-600">No students found in this classroom. Please add students first.</p>
        <a href="/students" class="inline-block px-4 py-2 mt-4 text-white bg-blue-600 rounded-lg hover:bg-blue-700">
          Go to Students
        </a>
      </div>
    {:else if selectedClassroom && students.length > 0}
      <!-- Quick Actions -->
      <div class="p-4 mb-6 bg-white rounded-lg shadow-md">
        <h2 class="mb-3 text-lg font-semibold text-gray-800">Quick Actions</h2>
        <div class="flex flex-wrap gap-2">
          <button
            on:click={() => markAllAs(AttendanceStatus.Present)}
            class="px-4 py-2 text-white transition-colors bg-green-600 rounded-lg hover:bg-green-700"
          >
            Mark All Present
          </button>
          <button
            on:click={() => markAllAs(AttendanceStatus.Absent)}
            class="px-4 py-2 text-white transition-colors bg-red-600 rounded-lg hover:bg-red-700"
          >
            Mark All Absent
          </button>
          <button
            on:click={() => markAllAs(AttendanceStatus.Late)}
            class="px-4 py-2 text-white transition-colors bg-yellow-600 rounded-lg hover:bg-yellow-700"
          >
            Mark All Late
          </button>
          <button
            on:click={() => markAllAs(AttendanceStatus.Excused)}
            class="px-4 py-2 text-white transition-colors bg-blue-600 rounded-lg hover:bg-blue-700"
          >
            Mark All Excused
          </button>
        </div>
      </div>

      <!-- Students List -->
      <div class="p-6 mb-6 bg-white rounded-lg shadow-md">
        <h2 class="mb-4 text-lg font-semibold text-gray-800">
          Students ({students.length})
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

              <div class="flex gap-2">
                <button
                  on:click={() => setAttendance(student.id, AttendanceStatus.Present)}
                  class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg {attendanceRecords.get(student.id) === AttendanceStatus.Present
                    ? 'bg-green-600 text-white border-green-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-green-50'}"
                >
                  Present
                </button>
                <button
                  on:click={() => setAttendance(student.id, AttendanceStatus.Absent)}
                  class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg {attendanceRecords.get(student.id) === AttendanceStatus.Absent
                    ? 'bg-red-600 text-white border-red-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-red-50'}"
                >
                  Absent
                </button>
                <button
                  on:click={() => setAttendance(student.id, AttendanceStatus.Late)}
                  class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg {attendanceRecords.get(student.id) === AttendanceStatus.Late
                    ? 'bg-yellow-600 text-white border-yellow-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-yellow-50'}"
                >
                  Late
                </button>
                <button
                  on:click={() => setAttendance(student.id, AttendanceStatus.Excused)}
                  class="px-3 py-2 text-sm font-medium transition-colors border rounded-lg {attendanceRecords.get(student.id) === AttendanceStatus.Excused
                    ? 'bg-blue-600 text-white border-blue-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-blue-50'}"
                >
                  Excused
                </button>
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
        <p class="text-gray-600">Select a classroom and date to start taking attendance.</p>
      </div>
    {/if}
  </div>
</div>
