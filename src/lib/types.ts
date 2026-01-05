// Database Types
export interface Classroom {
  id: string;
  name: string;
  start_year: number;
  end_year: number;
  created_at: string;
  updated_at: string;
}

export interface Student {
  id: string;
  name: string;
  registration_number: string;
  gender: 'L' | 'P' | null;
  photo_url: string | null;
  class_room_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface Attendance {
  id: string;
  student_id: string;
  class_room_id: string;
  attendance_status: number;
  date: string;
  is_auto_score?: boolean;
  score_nominal?: number;
  created_at: string;
}

// Joined Types for queries
export interface StudentWithClassroom extends Student {
  classroom?: Classroom;
}

export interface AttendanceWithStudent extends Attendance {
  student?: Student;
}

// Attendance Status Enum (Indonesian School System)
export enum AttendanceStatus {
  Hadir = 1,    // Present - DEFAULT
  Alpa = 2,     // Absent without permission
  Sakit = 3,    // Sick
  Izin = 4,     // Excused/Permission
  Bolos = 5,    // Truant/Skip
  Tugas = 6     // On Assignment/Duty
}

// Form Types
export interface ClassroomFormData {
  name: string;
  start_year: number;
  end_year: number;
}

export interface StudentFormData {
  name: string;
  registration_number: string;
  class_room_id: string;
  photo?: File;
}

export interface AttendanceFormData {
  student_id: string;
  class_room_id: string;
  attendance_status: number;
  date: string;
}
