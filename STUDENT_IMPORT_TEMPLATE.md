# Student Import Template Guide

## Excel File Format

To import students in bulk, prepare an Excel file (.xlsx or .xls) with the following columns:

### Required Columns

| Column Name | Description | Example | Notes |
|-------------|-------------|---------|-------|
| **name** | Student's full name | John Doe | Required, cannot be empty |
| **registration_number** | Student ID/NIS | 2024001 | Required, max 20 characters |
| **gender** | Student's gender | L or P | Optional: L = Laki-Laki (Male), P = Perempuan (Female) |

### Alternative Column Names (Case-Insensitive)

The system accepts these alternative column names:
- **name**: `nama`
- **registration_number**: `nis`, `nomor_induk`
- **gender**: `jenis_kelamin`, `jenis kelamin`

### Gender Values Accepted

The system will automatically normalize these values:
- **Male (L)**: L, LAKI-LAKI, LAKI, M, MALE
- **Female (P)**: P, PEREMPUAN, F, FEMALE

### Sample Excel Structure

```
| name          | registration_number | gender |
|---------------|---------------------|--------|
| Ahmad Wijaya  | 2024001            | L      |
| Siti Aminah   | 2024002            | P      |
| Budi Santoso  | 2024003            | L      |
| Dewi Lestari  | 2024004            | P      |
```

## Import Process

1. **Navigate** to the Students page
2. Click the **"📥 Import Students"** button (green button)
3. **Select a classroom** from the dropdown (all imported students will be assigned to this classroom)
4. **Upload your Excel file**
5. **Review the preview** - the system will show the first 10 rows and validate all data
6. Check for any validation errors highlighted in red
7. Click **"Import X Student(s)"** to complete the import

## Validation Rules

The system validates:
- ✅ Name is required and not empty
- ✅ Registration number is required and not empty
- ✅ Registration number does not exceed 20 characters
- ✅ Gender is either "L", "P", or empty
- ✅ Classroom is selected before import

## Tips

- The first row of your Excel file should contain the column headers
- Column names are **case-insensitive**
- You can leave the gender column empty if not available
- All students in one import will be assigned to the same classroom
- Invalid rows will be highlighted in red with specific error messages
- Only valid rows will be imported - invalid rows will be skipped

## Example Download

You can create a simple Excel file with this structure in Microsoft Excel, Google Sheets, or LibreOffice Calc.

### Basic Template:
```
name	registration_number	gender
Ahmad Wijaya	2024001	L
Siti Aminah	2024002	P
```

Save as `.xlsx` format and use it to import students.
