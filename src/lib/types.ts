// Database Types
export interface Classroom {
  id: string;
  name: string;
  year_of_study: number;
  created_at: string;
  updated_at: string;
}

export interface Student {
  id: string;
  name: string;
  registration_number: string;
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
  created_at: string;
}

// Joined Types for queries
export interface StudentWithClassroom extends Student {
  classroom?: Classroom;
}

export interface AttendanceWithStudent extends Attendance {
  student?: Student;
}

// Attendance Status Enum
export enum AttendanceStatus {
  Absent = 0,
  Present = 1,
  Late = 2,
  Excused = 3
}

// Form Types
export interface ClassroomFormData {
  name: string;
  year_of_study: number;
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
