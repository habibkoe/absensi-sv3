<script lang="ts">
  import Navigation from "$lib/components/Navigation.svelte";
  import Button from "$lib/components/Button.svelte";
  import { supabase } from "$lib/supabaseClient";
  import type { Student, Classroom } from "$lib/types";
  import { AttendanceStatus } from "$lib/types";
  import { onMount } from "svelte";
  import * as XLSX from "xlsx";

  let classrooms: Classroom[] = [];
  let students: Student[] = [];
  let selectedClassroom = "";
  let selectedStudent = "";
  let startDate = "";
  let endDate = "";
  let reportType: "classroom" | "student" = "classroom";
  let reportData: any[] = [];
  let loading = false;
  let error = "";
  let currentUserEmail = "";
  let currentUserName = "";

  onMount(async () => {
    await loadClassrooms();

    // Fetch current user info
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user?.email) {
      currentUserEmail = user.email;
      // Extract name from email (part before @)
      currentUserName = user.email.split("@")[0];
    }

    // Set default date range (last 30 days)
    const today = new Date();
    endDate = today.toISOString().split("T")[0];
    const thirtyDaysAgo = new Date(today.setDate(today.getDate() - 30));
    startDate = thirtyDaysAgo.toISOString().split("T")[0];
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

    const { data } = await supabase
      .from("students")
      .select("*")
      .eq("class_room_id", selectedClassroom)
      .order("name", { ascending: true });
    students = data || [];
  }

  async function generateReport() {
    if (reportType === "classroom" && !selectedClassroom) {
      error = "Please select a classroom";
      return;
    }

    if (reportType === "student" && !selectedStudent) {
      error = "Please select a student";
      return;
    }

    if (!startDate || !endDate) {
      error = "Please select date range";
      return;
    }

    loading = true;
    error = "";
    reportData = [];

    try {
      if (reportType === "classroom") {
        await generateClassroomReport();
      } else {
        await generateStudentReport();
      }
    } catch (err) {
      console.error("Error generating report:", err);
      error = "Failed to generate report";
    }

    loading = false;
  }

  async function generateClassroomReport() {
    // Get all students in the classroom
    const { data: studentsData, error: studentsError } = await supabase
      .from("students")
      .select("*")
      .eq("class_room_id", selectedClassroom)
      .order("name", { ascending: true });

    if (studentsError) throw studentsError;

    // Get attendance records for the date range
    const { data: attendanceData, error: attendanceError } = await supabase
      .from("attendance")
      .select("*")
      .eq("class_room_id", selectedClassroom)
      .gte("date", startDate)
      .lte("date", endDate);

    if (attendanceError) throw attendanceError;

    // Calculate statistics for each student
    reportData = (studentsData || []).map((student) => {
      const studentAttendance = (attendanceData || []).filter(
        (a: any) => a.student_id === student.id,
      );

      const totalDays = studentAttendance.length;
      const presentDays = studentAttendance.filter(
        (a: any) => a.attendance_status === AttendanceStatus.Hadir || 
                    a.attendance_status === AttendanceStatus.Tugas,
      ).length;
      const absentDays = studentAttendance.filter(
        (a: any) => a.attendance_status === AttendanceStatus.Alpa,
      ).length;
      const sickDays = studentAttendance.filter(
        (a: any) => a.attendance_status === AttendanceStatus.Sakit,
      ).length;
      const excusedDays = studentAttendance.filter(
        (a: any) => a.attendance_status === AttendanceStatus.Izin,
      ).length;
      const truantDays = studentAttendance.filter(
        (a: any) => a.attendance_status === AttendanceStatus.Bolos,
      ).length;
      const onDutyDays = studentAttendance.filter(
        (a: any) => a.attendance_status === AttendanceStatus.Tugas,
      ).length;
      const lateDays = studentAttendance.filter(
        (a: any) => a.attendance_status === AttendanceStatus.Telat,
      ).length;

      const attendanceRate =
        totalDays > 0
          ? (((presentDays + lateDays) / totalDays) * 100).toFixed(1)
          : "0";

      // Calculate average score for Tugas status
      const tugasWithScore = studentAttendance.filter(
        (a: any) =>
          a.attendance_status === AttendanceStatus.Tugas &&
          a.score_nominal !== null,
      );
      const avgScore =
        tugasWithScore.length > 0
          ? (
              tugasWithScore.reduce(
                (sum: number, a: any) => sum + (a.score_nominal || 0),
                0,
              ) / tugasWithScore.length
            ).toFixed(2)
          : "-";

      return {
        Nis: student.registration_number,
        NamaSiswa: student.name,
        JenisKelamin:
          student.gender === "L"
            ? "Laki-laki"
            : student.gender === "P"
              ? "Perempuan"
              : "-",
        TotalHari: totalDays,
        Hadir: presentDays,
        Alpa: absentDays,
        Sakit: sickDays,
        Izin: excusedDays,
        Bolos: truantDays,
        Telat: lateDays,
        Tugas: onDutyDays,
        Nilai: avgScore,
        PersentaseKehadiran: `${attendanceRate}%`,
      };
    });
  }

  async function generateStudentReport() {
    // Get student details
    const { data: studentData, error: studentError } = await supabase
      .from("students")
      .select("*, classroom:master_class_room(*)")
      .eq("id", selectedStudent)
      .single();

    if (studentError) throw studentError;

    // Get attendance records for the date range
    const { data: attendanceData, error: attendanceError } = await supabase
      .from("attendance")
      .select("*")
      .eq("student_id", selectedStudent)
      .gte("date", startDate)
      .lte("date", endDate)
      .order("date", { ascending: false });

    if (attendanceError) throw attendanceError;

    // Format attendance data
    reportData = (attendanceData || []).map((record: any) => ({
      registrationNumber: studentData.registration_number,
      studentName: studentData.name,
      date: new Date(record.date).toLocaleDateString(),
      status: getStatusText(record.attendance_status),
      score:
        record.attendance_status === AttendanceStatus.Tugas &&
        record.score_nominal !== null
          ? record.score_nominal
          : "-",
      autoScore: record.is_auto_score ? "Yes" : "No",
      gender:
        studentData.gender === "L"
          ? "Laki-laki"
          : studentData.gender === "P"
            ? "Perempuan"
            : "-",
      classroom: studentData.classroom?.name || "N/A",
    }));
  }

  function getStatusText(status: number): string {
    switch (status) {
      case AttendanceStatus.Hadir:
        return "Hadir (Present)";
      case AttendanceStatus.Alpa:
        return "Alpa (Absent)";
      case AttendanceStatus.Sakit:
        return "Sakit (Sick)";
      case AttendanceStatus.Izin:
        return "Izin (Excused)";
      case AttendanceStatus.Bolos:
        return "Bolos (Truant)";
      case AttendanceStatus.Telat:
        return "Telat (Late)";
      case AttendanceStatus.Tugas:
        return "Tugas (On Duty)";
      default:
        return "Unknown";
    }
  }

  async function exportToExcel() {
    if (reportData.length === 0) {
      error = "No data to export. Please generate a report first.";
      return;
    }

    try {
      // Get classroom name
      const classroomName =
        classrooms.find((c) => c.id === selectedClassroom)?.name || "N/A";

      // Format date range
      const formattedStartDate = new Date(startDate).toLocaleDateString(
        "id-ID",
      );
      const formattedEndDate = new Date(endDate).toLocaleDateString("id-ID");
      const periode = `${formattedStartDate} - ${formattedEndDate}`;

      // Create header rows
      const headerRows = [
        ["Ruang Kelas:", classroomName],
        ["Guru:", currentUserName || currentUserEmail || "N/A"],
        ["Periode:", periode],
        [], // blank row
      ];

      // Add numbering to data
      const dataWithNumbers = reportData.map((row, index) => ({
        No: index + 1,
        ...row,
      }));

      // Create worksheet with header rows
      const ws = XLSX.utils.aoa_to_sheet(headerRows);

      // Append data table to worksheet (starting from row 5)
      XLSX.utils.sheet_add_json(ws, dataWithNumbers, { origin: "A5" });

      // Create workbook
      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, ws, "Report");

      // Generate filename
      const timestamp = new Date().toISOString().split("T")[0];
      const filename = `${reportType}_${classroomName}_${timestamp}.xlsx`;

      // Save file
      XLSX.writeFile(wb, filename);
    } catch (err) {
      console.error("Error exporting to Excel:", err);
      error = "Failed to export to Excel";
    }
  }

  $: if (selectedClassroom) {
    loadStudents();
  }
</script>

<svelte:head>
  <title>Absensi Siswa - Master Report</title>
  <meta name="description" content="Absensi siswa" />
</svelte:head>

<Navigation />

<div class="min-h-screen bg-gray-100">
  <div class="container px-4 py-8 mx-auto">
    <h1 class="mb-8 text-3xl font-bold text-gray-800">Report Absensi</h1>

    {#if error}
      <div
        class="p-4 mb-4 text-red-700 bg-red-100 border border-red-400 rounded"
      >
        {error}
      </div>
    {/if}

    <!-- Report Configuration -->
    <div class="p-6 mb-6 bg-white rounded-lg shadow-md">
      <h2 class="mb-4 text-xl font-semibold text-gray-800">
        Report Configuration
      </h2>

      <div class="space-y-4">
        <!-- Report Type -->
        <div>
          <label class="block mb-2 text-sm font-medium text-gray-700"
            >Report Type</label
          >
          <div class="flex gap-4">
            <label class="flex items-center">
              <input
                type="radio"
                bind:group={reportType}
                value="classroom"
                class="mr-2"
              />
              <span>Report per kelas</span>
            </label>
            <label class="flex items-center">
              <input
                type="radio"
                bind:group={reportType}
                value="student"
                class="mr-2"
              />
              <span>Report per siswa</span>
            </label>
          </div>
        </div>

        <!-- Date Range -->
        <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
          <div>
            <label
              for="startDate"
              class="block mb-2 text-sm font-medium text-gray-700"
            >
              Tanggal awal *
            </label>
            <input
              type="date"
              id="startDate"
              bind:value={startDate}
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>
          <div>
            <label
              for="endDate"
              class="block mb-2 text-sm font-medium text-gray-700"
            >
              Tanggal akhir *
            </label>
            <input
              type="date"
              id="endDate"
              bind:value={endDate}
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>
        </div>

        <!-- Classroom Selection -->
        <div>
          <label
            for="classroom"
            class="block mb-2 text-sm font-medium text-gray-700"
          >
            Pilih ruang kelas *
          </label>
          <select
            id="classroom"
            bind:value={selectedClassroom}
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

        <!-- Student Selection (only for student report) -->
        {#if reportType === "student"}
          <div>
            <label
              for="student"
              class="block mb-2 text-sm font-medium text-gray-700"
            >
              Pilih siswa *
            </label>
            <select
              id="student"
              bind:value={selectedStudent}
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              disabled={!selectedClassroom}
            >
              <option value="">Pilih siswa</option>
              {#each students as student}
                <option value={student.id}
                  >{student.name} - {student.registration_number}</option
                >
              {/each}
            </select>
          </div>
        {/if}

        <!-- Action Buttons -->
        <div class="flex gap-3">
          <Button on:click={generateReport} {loading} disabled={loading}>
            {loading ? "Generating..." : "Generate Report"}
          </Button>
          {#if reportData.length > 0}
            <Button on:click={exportToExcel} variant="success">
              📥 Export to Excel
            </Button>
          {/if}
        </div>
      </div>
    </div>

    <!-- Report Results -->
    {#if loading}
      <div class="text-center">
        <div
          class="w-12 h-12 mx-auto border-b-2 border-blue-600 rounded-full animate-spin"
        ></div>
        <p class="mt-4 text-gray-600">Generating report...</p>
      </div>
    {:else if reportData.length > 0}
      <div class="overflow-hidden bg-white rounded-lg shadow-md">
        <div class="p-4 border-b border-gray-200 bg-gray-50">
          <h3 class="text-lg font-semibold text-gray-800">
            {reportType === "classroom"
              ? "Classroom Attendance Summary"
              : "Student Attendance History"}
          </h3>
          <p class="text-sm text-gray-600">
            Period: {new Date(startDate).toLocaleDateString()} - {new Date(
              endDate,
            ).toLocaleDateString()}
          </p>
        </div>

        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                {#if reportType === "classroom"}
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-center text-gray-500 uppercase"
                    >No</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                    >NIS</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                    >Nama Siswa</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                    >Jenis Kelamin</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-center text-gray-500 uppercase"
                    >Total Hari</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-center text-gray-500 uppercase"
                    >Hadir</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-center text-gray-500 uppercase"
                    >Alpa</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-center text-gray-500 uppercase"
                    >Sakit</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-center text-gray-500 uppercase"
                    >Izin</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-center text-gray-500 uppercase"
                    >Bolos</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-center text-gray-500 uppercase"
                    >Telat</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-center text-gray-500 uppercase"
                    >Tugas</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-center text-gray-500 uppercase"
                    >Avg Score</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-center text-gray-500 uppercase"
                    >Rate</th
                  >
                {:else}
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-center text-gray-500 uppercase"
                    >No</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                    >NIS</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                    >Nama Siswa</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                    >Tanggal</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                    >Status</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-center text-gray-500 uppercase"
                    >Score</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-center text-gray-500 uppercase"
                    >Auto Score</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                    >Jenis Kelamin</th
                  >
                  <th
                    class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase"
                    >Ruang kelas</th
                  >
                {/if}
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              {#each reportData as row, index}
                <tr class="hover:bg-gray-50">
                  {#if reportType === "classroom"}
                    <td
                      class="px-6 py-4 text-sm text-center text-gray-900 whitespace-nowrap"
                      >{index + 1}</td
                    >
                    <td
                      class="px-6 py-4 text-sm text-gray-500 whitespace-nowrap"
                      >{row.Nis}</td
                    >
                    <td
                      class="px-6 py-4 text-sm font-medium text-gray-900 whitespace-nowrap"
                      >{row.NamaSiswa}</td
                    >
                    <td
                      class="px-6 py-4 text-sm text-gray-500 whitespace-nowrap"
                      >{row.JenisKelamin}</td
                    >
                    <td
                      class="px-6 py-4 text-sm text-center text-gray-500 whitespace-nowrap"
                      >{row.TotalHari}</td
                    >
                    <td
                      class="px-6 py-4 text-sm text-center text-green-600 whitespace-nowrap"
                      >{row.Hadir}</td
                    >
                    <td
                      class="px-6 py-4 text-sm text-center text-red-600 whitespace-nowrap"
                      >{row.Alpa}</td
                    >
                    <td
                      class="px-6 py-4 text-sm text-center text-orange-600 whitespace-nowrap"
                      >{row.Sakit}</td
                    >
                    <td
                      class="px-6 py-4 text-sm text-center text-blue-600 whitespace-nowrap"
                      >{row.Izin}</td
                    >
                    <td
                      class="px-6 py-4 text-sm text-center text-purple-600 whitespace-nowrap"
                      >{row.Bolos}</td
                    >
                    <td
                      class="px-6 py-4 text-sm text-center text-amber-600 whitespace-nowrap"
                      >{row.Telat}</td
                    >
                    <td
                      class="px-6 py-4 text-sm text-center text-yellow-600 whitespace-nowrap"
                      >{row.Tugas}</td
                    >
                    <td
                      class="px-6 py-4 text-sm text-center font-semibold whitespace-nowrap {row.Nilai !==
                      '-'
                        ? 'text-indigo-600'
                        : 'text-gray-400'}">{row.Nilai}</td
                    >
                    <td
                      class="px-6 py-4 text-sm font-semibold text-center text-gray-900 whitespace-nowrap"
                      >{row.PersentaseKehadiran}</td
                    >
                  {:else}
                    <td
                      class="px-6 py-4 text-sm text-center text-gray-900 whitespace-nowrap"
                      >{index + 1}</td
                    >
                    <td
                      class="px-6 py-4 text-sm text-gray-500 whitespace-nowrap"
                      >{row.registrationNumber}</td
                    >
                    <td
                      class="px-6 py-4 text-sm font-medium text-gray-900 whitespace-nowrap"
                      >{row.studentName}</td
                    >
                    <td
                      class="px-6 py-4 text-sm text-gray-900 whitespace-nowrap"
                      >{row.date}</td
                    >
                    <td class="px-6 py-4 text-sm whitespace-nowrap">
                      <span
                        class="px-2 py-1 text-xs font-medium rounded-full {row.status.includes(
                          'Hadir',
                        )
                          ? 'bg-green-100 text-green-800'
                          : row.status.includes('Alpa')
                            ? 'bg-red-100 text-red-800'
                            : row.status.includes('Sakit')
                              ? 'bg-orange-100 text-orange-800'
                              : row.status.includes('Izin')
                                ? 'bg-blue-100 text-blue-800'
                                : row.status.includes('Bolos')
                                  ? 'bg-purple-100 text-purple-800'
                                  : row.status.includes('Tugas')
                                    ? 'bg-yellow-100 text-yellow-800'
                                    : 'bg-gray-100 text-gray-800'}"
                      >
                        {row.status}
                      </span>
                    </td>
                    <td
                      class="px-6 py-4 text-sm text-center font-semibold whitespace-nowrap {row.score !==
                      '-'
                        ? 'text-indigo-600'
                        : 'text-gray-400'}">{row.score}</td
                    >
                    <td
                      class="px-6 py-4 text-sm text-center text-gray-600 whitespace-nowrap"
                      >{row.autoScore}</td
                    >
                    <td
                      class="px-6 py-4 text-sm text-gray-500 whitespace-nowrap"
                      >{row.gender}</td
                    >
                    <td
                      class="px-6 py-4 text-sm text-gray-500 whitespace-nowrap"
                      >{row.classroom}</td
                    >
                  {/if}
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </div>
    {/if}
  </div>
</div>
