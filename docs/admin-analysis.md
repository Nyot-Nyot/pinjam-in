# Analisis Halaman Admin - Pinjam In

**Tanggal**: 2 Desember 2025
**Branch**: feature/admin-role-design
**Status**: Planning & Design Phase

## Executive Summary

Halaman admin Pinjam In akan menjadi control panel yang memberikan kendali penuh terhadap manajemen user dan items dalam aplikasi. Admin akan memiliki akses superior yang melampaui batasan RLS (Row Level Security) normal user, dengan fokus pada operasi CRUD, monitoring, dan analytics.

## Prinsip Desain

1. **Separation of Concerns**: UI admin sepenuhnya terpisah dari UI user biasa
2. **Data Management Focus**: Admin dapat mengelola semua user dan items data
3. **Security First**: Menggunakan RLS policies khusus admin
4. **Audit Trail**: Semua aksi admin dicatat untuk tracking dan accountability
5. **Analytics & Monitoring**: Dashboard menampilkan statistik dan insight yang berguna
6. **Safe Operations**: Operasi destruktif memerlukan konfirmasi

## Analisis Fungsi & Kendali Admin

### 1. User Management (Manajemen User)

#### 1.1 User CRUD Operations

-   **View All Users**: Melihat daftar lengkap semua user dengan filter & search

    -   Display: email, full name, role, status, created date, last login
    -   Filter: by role, status (active/inactive), registration date range
    -   Search: by name, email, user ID

-   **View User Details**: Detail lengkap profil user

    -   Personal info: email, full name, phone (jika ada)
    -   Account info: user ID, role, created date, updated date
    -   Activity metrics: total items borrowed, total items returned, active loans
    -   Login history: last login, login count, device info

-   **Create User**: Membuat user baru dari admin panel

    -   Input: email, password, full name, role
    -   Options: send email verification, force password change on first login

-   **Update User**: Mengubah data user

    -   Editable: full name, email, role, status
    -   Actions: reset password, force logout, verify email manually

-   **Delete User**: Menghapus user (soft delete & hard delete)

    -   Soft delete: tandai sebagai inactive, data tetap ada
    -   Hard delete: hapus permanen termasuk semua loan items
    -   Safety: konfirmasi + password admin untuk hard delete

-   **User Roles Management**: Mengatur role user
    -   Upgrade: user → admin
    -   Downgrade: admin → user
    -   Custom roles (future): moderator, readonly_admin

#### 1.2 User Authentication Control

-   **Lock/Unlock Account**: Suspend akses user sementara
-   **Force Password Reset**: Paksa user ganti password
-   **Session Management**: Lihat dan terminate active sessions
-   **Email Verification Override**: Verify email secara manual

#### 1.3 User Activity Monitoring

-   **Login History**: Track login attempts (success & failed)
-   **Action Logs**: Audit trail semua aksi user (create, update, delete items)
-   **Device Tracking**: Device dan platform yang digunakan user

### 2. Items Management (Manajemen Barang Pinjaman)

#### 2.1 Global Items View

-   **View All Items**: Melihat semua loan items dari semua user

    -   Filter: by status, user, date range, overdue
    -   Sort: by date, status, user, item name
    -   Search: by item name, borrower name, notes
    -   Bulk actions: bulk status update, bulk delete

-   **View Item Details**: Detail lengkap item dari user manapun
    -   Item info: name, photo, borrower details, dates, status, notes
    -   Owner info: user ID, user name, user email
    -   Timeline: created date, borrow date, due date, return date
    -   History: edit history, status changes

#### 2.2 Items CRUD Operations (Cross-User)

-   **Create Item (for any user)**: Buat item atas nama user lain
-   **Update Item (any item)**: Edit item dari user manapun
-   **Delete Item (any item)**: Hapus item dari user manapun
    -   Soft delete option
    -   Cascade delete untuk cleanup

#### 2.3 Items Analytics

-   **Overdue Items**: Daftar items yang melewati due date
-   **Most Borrowed Items**: Statistik items yang sering dipinjamkan
-   **Return Rate**: Persentase items yang dikembalikan tepat waktu
-   **User Borrowing Patterns**: Analisis perilaku peminjaman per user

### 3. Storage Management (Manajemen File & Media)

#### 3.1 Storage Overview

-   **Storage Usage**: Total storage used, per user breakdown
-   **File Browser**: Browse semua files di bucket `item_photos`
-   **Orphaned Files Detection**: File yang tidak terkait dengan item manapun

#### 3.2 Storage Operations

-   **View File Details**: metadata, size, upload date, owner
-   **Download Files**: Download foto items untuk backup
-   **Delete Files**: Hapus file individual atau bulk delete
-   **Storage Cleanup**: Automated cleanup orphaned files
-   **Storage Policies**: Atur limit per user, allowed file types

#### 3.3 Storage Analytics

-   **Upload Statistics**: Jumlah upload per hari/minggu/bulan
-   **File Type Distribution**: PNG vs JPG usage
-   **Top Storage Users**: User dengan storage usage tertinggi

### 4. Analytics & Reporting (Analitik & Laporan)

#### 4.1 Dashboard Metrics

-   **User Metrics**:

    -   Total users
    -   New users (today, this week, this month)
    -   Active users (last 7/30 days)
    -   User growth chart

-   **Items Metrics**:

    -   Total items
    -   Items borrowed vs returned
    -   Overdue items count
    -   Items created (today, this week, this month)

-   **System Metrics**:
    -   Storage usage
    -   Total files

#### 4.2 Reports Generation

-   **User Reports**: User activity, growth, retention
-   **Items Reports**: Borrowing patterns, return rates, overdue analysis
-   **Export Reports**: PDF, Excel, CSV format

#### 4.3 Real-time Analytics

-   **Live Activity Feed**: Real-time feed of user actions (last 20 activities)
-   **Live Metrics**: Auto-refresh dashboard metrics

### 5. Audit & Compliance (Audit & Kepatuhan)

#### 5.1 Audit Logs

-   **Admin Actions Log**: Semua aksi yang dilakukan admin

    -   Who: admin user ID & name
    -   What: action type (create, update, delete, view)
    -   When: timestamp
    -   Where: table/resource affected
    -   Details: old values, new values

-   **User Actions Log**: Semua aksi user (untuk compliance)

#### 5.2 Compliance Tools

-   **Data Export (GDPR)**: Export user data untuk GDPR compliance
-   **Data Deletion**: Complete user data deletion
-   **Access Reports**: Who accessed what data, when

## Kebutuhan Teknis

### Backend Requirements

1. **Database Schema Updates**:

    - Tabel `profiles` dengan field `role` (sudah ada)
    - Tabel `audit_logs` untuk tracking admin actions

2. **RLS Policies**:

    - Admin bypass policies untuk tables: `items`, `profiles`
    - Audit log policies (admin read-only)

3. **Database Functions**:

    - `admin_get_all_items()`: Get items bypassing RLS
    - `admin_get_all_users()`: Get users dengan details
    - `admin_delete_user(user_id)`: Safe user deletion dengan cleanup
    - `admin_create_audit_log()`: Create audit entry
    - `admin_get_statistics()`: Get dashboard metrics
    - `admin_cleanup_storage()`: Remove orphaned files

### Frontend Requirements

1. **Routing & Navigation**:

    - Separate route tree untuk admin (`/admin/*`)
    - Admin layout dengan sidebar navigation
    - Role-based route guards

2. **State Management**:

    - `AdminProvider`: State management untuk admin data
    - `AdminAnalyticsProvider`: Real-time analytics

3. **UI Components**:

    - Data tables dengan sorting, filtering, pagination
    - Charts dan graphs (using fl_chart)
    - Modals untuk confirmations
    - Toast notifications
    - Loading states dan error handling

4. **Services**:
    - `AdminService`: API calls untuk admin operations
    - `AuditService`: Audit logging
    - `AnalyticsService`: Metrics collection

### Security Requirements

1. **Authentication**:

    - Admin role verification di setiap request
    - Session management

2. **Authorization**:

    - Permission checks di frontend dan backend
    - Admin bypass RLS untuk read/write operations

3. **Audit Trail**:
    - Log semua admin actions dengan details
    - Immutable audit logs

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Admin Flutter App                     │
│  ┌────────────┐  ┌──────────────┐  ┌─────────────────┐ │
│  │   Admin    │  │   Admin      │  │    Admin        │ │
│  │  Provider  │──│  Services    │──│  Repositories   │ │
│  └────────────┘  └──────────────┘  └─────────────────┘ │
│         │                                    │           │
└─────────┼────────────────────────────────────┼───────────┘
          │                                    │
          └─────────┬──────────────────────────┘
                    │
         ┌──────────▼──────────────────────────────────┐
         │         Supabase Backend                    │
         │  ┌─────────────────▼──────────────────────┐│
         │  │      PostgreSQL Database               ││
         │  │  ┌──────────┐  ┌──────────────────┐   ││
         │  │  │  Items   │  │   Profiles       │   ││
         │  │  └──────────┘  └──────────────────┘   ││
         │  │  ┌──────────┐                         ││
         │  │  │Audit Logs│                         ││
         │  │  └──────────┘                         ││
         │  │          RLS Policies                  ││
         │  │      (Admin Bypass Rules)              ││
         │  └────────────────────────────────────────┘│
         │                    │                        │
         │  ┌─────────────────▼──────────────────────┐│
         │  │         Storage (item_photos)          ││
         │  │    Admin: Full Access to All Files     ││
         │  └────────────────────────────────────────┘│
         └─────────────────────────────────────────────┘
```

## Success Metrics

1. **Functionality**: Admin dapat melakukan semua operasi CRUD user dan items
2. **Security**: Zero unauthorized access ke admin functions
3. **Performance**: Dashboard load < 2 detik, operations < 1 detik
4. **Usability**: Admin dapat menyelesaikan task dengan mudah
5. **Audit**: Semua admin actions tercatat di audit log

## Risk Assessment

| Risk                              | Impact   | Probability | Mitigation                             |
| --------------------------------- | -------- | ----------- | -------------------------------------- |
| RLS misconfiguration              | High     | Medium      | Comprehensive testing, security review |
| Performance degradation           | Medium   | Medium      | Pagination, lazy loading, caching      |
| Data corruption from admin error  | High     | Medium      | Soft deletes, confirmations            |
| Unauthorized privilege escalation | Critical | Low         | Multi-layer auth checks, audit logging |

## Next Steps

Lihat `admin-implementation-plan.md` untuk breakdown detail implementasi per fase dengan tasks dan checklist.

---

**Document Owner**: Development Team
**Last Updated**: 2 Desember 2025
**Version**: 2.0 (Simplified)
