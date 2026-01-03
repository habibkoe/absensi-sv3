<script lang="ts">
  import Navigation from '$lib/components/Navigation.svelte';
  import { supabase } from '$lib/supabaseClient';
  import { onMount } from 'svelte';

  let stats = {
    totalClassrooms: 0,
    totalStudents: 0,
    todayAttendance: 0,
    presentToday: 0
  };
  let loading = true;

  onMount(async () => {
    await loadStats();
  });

  async function loadStats() {
    loading = true;
    try {
      // Get total classrooms
      const { count: classroomsCount } = await supabase
        .from('master_class_room')
        .select('*', { count: 'exact', head: true });

      // Get total students
      const { count: studentsCount } = await supabase
        .from('students')
        .select('*', { count: 'exact', head: true });

      // Get today's attendance
      const today = new Date().toISOString().split('T')[0];
      const { count: attendanceCount } = await supabase
        .from('attendance')
        .select('*', { count: 'exact', head: true })
        .eq('date', today);

      // Get present count today
      const { count: presentCount } = await supabase
        .from('attendance')
        .select('*', { count: 'exact', head: true })
        .eq('date', today)
        .eq('attendance_status', 1);

      stats = {
        totalClassrooms: classroomsCount || 0,
        totalStudents: studentsCount || 0,
        todayAttendance: attendanceCount || 0,
        presentToday: presentCount || 0
      };
    } catch (err) {
      console.error('Error loading stats:', err);
    }
    loading = false;
  }
</script>

<Navigation />

<div class="min-h-screen bg-gray-100">
  <div class="container px-4 py-8 mx-auto">
    <h1 class="mb-8 text-3xl font-bold text-gray-800">Dashboard</h1>

    {#if loading}
      <div class="text-center">
        <div class="w-12 h-12 mx-auto border-b-2 border-blue-600 rounded-full animate-spin"></div>
        <p class="mt-4 text-gray-600">Loading statistics...</p>
      </div>
    {:else}
      <div class="grid grid-cols-1 gap-6 mb-8 md:grid-cols-2 lg:grid-cols-4">
        <div class="p-6 bg-white rounded-lg shadow-md">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-600">Total Classrooms</p>
              <p class="mt-2 text-3xl font-bold text-blue-600">{stats.totalClassrooms}</p>
            </div>
            <div class="p-3 bg-blue-100 rounded-full">
              <svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"></path>
              </svg>
            </div>
          </div>
        </div>

        <div class="p-6 bg-white rounded-lg shadow-md">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-600">Total Students</p>
              <p class="mt-2 text-3xl font-bold text-green-600">{stats.totalStudents}</p>
            </div>
            <div class="p-3 bg-green-100 rounded-full">
              <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"></path>
              </svg>
            </div>
          </div>
        </div>

        <div class="p-6 bg-white rounded-lg shadow-md">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-600">Today's Attendance</p>
              <p class="mt-2 text-3xl font-bold text-purple-600">{stats.todayAttendance}</p>
            </div>
            <div class="p-3 bg-purple-100 rounded-full">
              <svg class="w-8 h-8 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"></path>
              </svg>
            </div>
          </div>
        </div>

        <div class="p-6 bg-white rounded-lg shadow-md">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-600">Present Today</p>
              <p class="mt-2 text-3xl font-bold text-orange-600">{stats.presentToday}</p>
            </div>
            <div class="p-3 bg-orange-100 rounded-full">
              <svg class="w-8 h-8 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              </svg>
            </div>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div class="p-6 bg-white rounded-lg shadow-md">
          <h2 class="mb-4 text-xl font-semibold text-gray-800">Quick Actions</h2>
          <div class="space-y-3">
            <a href="/attendance" class="block px-4 py-3 text-white transition-colors bg-blue-600 rounded-lg hover:bg-blue-700">
              📝 Take Attendance
            </a>
            <a href="/students" class="block px-4 py-3 text-white transition-colors bg-green-600 rounded-lg hover:bg-green-700">
              👨‍🎓 Manage Students
            </a>
            <a href="/classrooms" class="block px-4 py-3 text-white transition-colors bg-purple-600 rounded-lg hover:bg-purple-700">
              🏫 Manage Classrooms
            </a>
            <a href="/reports" class="block px-4 py-3 text-white transition-colors bg-orange-600 rounded-lg hover:bg-orange-700">
              📊 View Reports
            </a>
          </div>
        </div>

        <div class="p-6 bg-white rounded-lg shadow-md">
          <h2 class="mb-4 text-xl font-semibold text-gray-800">System Information</h2>
          <div class="space-y-3 text-gray-700">
            <p><strong>Today:</strong> {new Date().toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</p>
            <p><strong>Total Records Taken:</strong> {stats.todayAttendance} today</p>
            <p><strong>Attendance Rate:</strong> {stats.todayAttendance > 0 ? ((stats.presentToday / stats.todayAttendance) * 100).toFixed(1) : 0}% present</p>
          </div>
        </div>
      </div>
    {/if}
  </div>
</div>
