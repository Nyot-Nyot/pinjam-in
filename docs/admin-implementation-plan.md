# Admin Implementation Plan - Pinjam In

**Tanggal**: 2 Desember 2025
**Branch**: feature/admin-role-design
**Estimasi Total**: 6-8 minggu (1.5-2 bulan)
**Status**: Planning Phase

> 📋 **Catatan**: Setiap task memiliki checkbox untuk tracking progress. Update checklist secara berkala setiap task selesai.

## Overview Fase Implementasi

Implementasi dibagi menjadi 4 fase utama yang dilakukan secara iteratif dan incremental. Setiap fase menghasilkan deliverable yang dapat diuji dan di-demo.

```
Phase 0: Foundation       → Week 1-2   (Database & Auth foundation)
Phase 1: Core Features    → Week 3-4   (User & Items Management)
Phase 2: Storage & Media  → Week 5     (Storage management)
Phase 3: Analytics & Launch → Week 6-8 (Dashboard, Analytics & Testing)
```

---

## Phase 0: Foundation & Infrastructure (Week 1-2)

**Goal**: Setup database schema, RLS policies, dan basic admin authentication

**Estimasi**: 2 minggu
**Priority**: Critical (Required untuk fase selanjutnya)

### 0.1 Database Schema Setup (3 hari)

#### Task 0.1.1: Create Audit Logs Table

-   [x] Buat migration file `001_create_audit_logs.sql`
-   [x] Define schema untuk `audit_logs`:
    -   `id` (UUID, primary key)
    -   `admin_user_id` (UUID, references profiles.id)
    -   `action_type` (TEXT: 'create', 'update', 'delete', 'view')
    -   `table_name` (TEXT: nama tabel yang di-affect)
    -   `record_id` (UUID: ID record yang di-affect, nullable)
    -   `old_values` (JSONB: nilai lama sebelum update, nullable)
    -   `new_values` (JSONB: nilai baru setelah update, nullable)
    -   `metadata` (JSONB: additional info seperti timestamp detail)
    -   `created_at` (TIMESTAMPTZ)
-   [x] Tambahkan indexes: `admin_user_id`, `action_type`, `table_name`, `created_at`
-   [x] Create RLS policy: admin can read
-   [x] Test migration di dev environment
-   [x] Dokumentasi schema di SCHEMA_DOCS.md

#### Task 0.1.2: Update Profiles Table

-   [x] Buat migration file `002_update_profiles_admin.sql`
-   [x] Add/update columns:
    -   `role` (TEXT: 'user' atau 'admin') - sudah ada
    -   `status` (TEXT: 'active', 'inactive', 'suspended')
    -   `last_login` (TIMESTAMPTZ)
-   [x] Update RLS policies untuk support admin access
-   [x] Create function `update_last_login()` trigger
-   [x] Test migration

### 0.2 RLS Policies for Admin (3 hari)

#### Task 0.2.1: Create Admin RLS Bypass Policies

-   [x] Buat migration file `004_admin_rls_policies.sql`
-   [x] Update RLS untuk `items` table:
    -   [x] Policy: "Admin can view all items" (SELECT untuk role='admin')
    -   [x] Policy: "Admin can update all items" (UPDATE untuk role='admin')
    -   [x] Policy: "Admin can delete all items" (DELETE untuk role='admin')
-   [x] Update RLS untuk `profiles` table:
    -   [x] Policy: "Admin can view all profiles"
    -   [x] Policy: "Admin can update all profiles"
    -   [x] Policy: "Admin can insert profiles"
    -   [x] Policy: "Admin can delete profiles"
-   [x] Update storage policies:
    -   [x] Policy: "Admin can view all files"
    -   [x] Policy: "Admin can update all files"
    -   [x] Policy: "Admin can delete all files"
-   [x] Create is_admin() SECURITY DEFINER function
-   [x] Fix infinite recursion issue with migration 007
-   [x] Test policies dengan different user roles
-   [x] Dokumentasi policies

#### Task 0.2.2: Test RLS Security

-   [x] Buat test users: regular user, admin
-   [x] Test regular user tidak bisa akses data user lain
-   [x] Test admin bisa akses semua data
-   [x] Create smoke test script (test_rls_smoke.sql)
-   [x] Verify no infinite recursion errors
-   [x] Dokumentasi test results
-   [x] Fix security issues jika ditemukan

**Status**: ✅ **COMPLETED** - All RLS policies implemented and tested successfully

### 0.3 Database Functions (4 hari)

#### Task 0.3.1: User Management Functions

-   [x] Buat migration file `008_admin_functions_users.sql`
-   [x] Create function `admin_get_all_users()`:
    -   Returns: user list dengan stats (item count, last login)
    -   Include: role, status, created_at
    -   Filters: role, status, search (name/email)
    -   Pagination: limit, offset
-   [x] Create function `admin_get_user_details(user_id UUID)`:
    -   Returns: complete user info + activity metrics
    -   Includes: overdue items, storage files count
-   [x] Create function `admin_update_user_role(user_id UUID, new_role TEXT)`:
    -   Update role dengan validation
    -   Prevent self-demotion
    -   Create audit log
-   [x] Create function `admin_update_user_status(user_id UUID, new_status TEXT, reason TEXT)`:
    -   Update status dengan validation
    -   Prevent self-deactivation
    -   Create audit log with reason
-   [x] Create function `admin_delete_user(user_id UUID, hard_delete BOOLEAN)`:
    -   Soft delete: set status='inactive'
    -   Hard delete: cascade delete items, files, logs
    -   Prevent self-deletion
    -   Create audit log
-   [x] Create helper function `create_admin_audit_log()`:
    -   Reusable audit logging
    -   Consistent across all admin operations
-   [x] Create test script `test_admin_user_functions.sql`
-   [x] Handle error cases with validation and RAISE EXCEPTION
-   [x] Update SCHEMA_DOCS.md with function documentation
-   [x] Update admin-implementation-plan.md with completed tasks

**Status**: ✅ **COMPLETED** - All user management functions created and documented

#### Task 0.3.2: Items Management Functions

-   [x] Buat migration file `009_admin_functions_items.sql`
-   [x] Create function `admin_get_all_items(limit INT, offset INT)`:
    -   Returns: items dengan user info
    -   Support pagination
    -   Support filtering by status, owner, and search
-   [x] Create function `admin_get_item_details(item_id UUID)`:
    -   Returns: item + owner info + history
    -   Includes computed fields (is_overdue, days_borrowed, days_overdue)
-   [x] Create function `admin_update_item_status(item_id UUID, new_status TEXT)`:
    -   Update status dengan audit
    -   Validates status values
    -   Records reason in metadata
-   [x] Create function `admin_delete_item(item_id UUID)`:
    -   Delete dengan audit log
    -   Supports soft delete (default) and hard delete
    -   Note: Hard delete does not remove photo from storage
-   [x] Create test helper functions in 009b_admin_functions_items_test_helpers.sql
-   [x] Create test script quick_test_admin_items.sql with 16 automated tests
-   [x] Update SCHEMA_DOCS.md with complete function documentation
-   [x] Update admin-implementation-plan.md with completed tasks

**Status**: ✅ **COMPLETED** - All items management functions created, tested, and documented

#### Task 0.3.3: Analytics Functions

-   [x] Buat migration file `010_admin_functions_analytics.sql`
-   [x] Create function `admin_get_dashboard_stats()`:
    -   Returns: total_users, active_users, inactive_users, admin_users, total_items, borrowed_items, returned_items, overdue_items, total_storage_files, new_users_today, new_items_today (11 metrics)
-   [x] Create function `admin_get_user_growth(days INT)`:
    -   Returns: date, new_users, cumulative_users
    -   Uses generate_series() for complete date coverage
    -   Parameter validation: 1-365 days
-   [x] Create function `admin_get_item_statistics()`:
    -   Returns: total_items, borrowed_items, returned_items, overdue_items, borrowed_percentage, returned_percentage, overdue_percentage, avg_loan_duration_days, total_completed_loans, items_never_returned (10 metrics)
-   [x] Create function `admin_get_top_users(limit INT)`:
    -   Returns: user_id, full_name, email, total_items, borrowed_items, returned_items, overdue_items
    -   Ranked by total_items descending
    -   Parameter validation: 1-100 limit
-   [x] Create test helper functions in 010b_admin_functions_analytics_test_helpers.sql
-   [x] Create test script quick_test_admin_analytics.sql with 14 automated tests
-   [x] Update SCHEMA_DOCS.md with complete function documentation and performance notes
-   [x] Update admin-implementation-plan.md with completed tasks

**Status**: ✅ **COMPLETED** - All analytics functions created, tested, and documented with comprehensive performance guidelines

#### Task 0.3.4: Audit & Utility Functions

-   [x] Buat migration file `011_admin_functions_audit.sql`
-   [x] Create function `admin_create_audit_log()`:
    -   [x] Parameters: action_type, table_name, record_id, old_values, new_values, metadata
    -   [x] Returns: created audit log with admin info
    -   [x] Validates action_type (CREATE, UPDATE, DELETE, STATUS_CHANGE, ROLE_CHANGE, CUSTOM)
    -   [x] Validates required parameters (not NULL/empty)
-   [x] Create function `admin_get_audit_logs(filters JSONB)`:
    -   [x] Filter by: user_id, action_type, table_name, date_from, date_to
    -   [x] Pagination support (limit: 1-200, offset: >= 0)
    -   [x] Returns audit logs with admin name and email
    -   [x] Ordered by created_at DESC (newest first)
-   [x] Create function `admin_get_storage_stats()`:
    -   [x] Returns: total_files, total_size (bytes/MB), items_with_photos
    -   [x] Returns: orphaned_files count, avg/largest/smallest file sizes
    -   [x] Queries storage.objects with SECURITY DEFINER
    -   [x] Detects orphaned files by cross-referencing items.photo_url
-   [x] Create test helper functions in 011b_admin_functions_audit_test_helpers.sql
-   [x] Create comprehensive test script quick_test_admin_audit.sql with 16 automated tests
-   [x] Update SCHEMA_DOCS.md with complete function documentation, examples, and performance notes
-   [x] Update admin-implementation-plan.md with completed tasks

**Status**: ✅ **COMPLETED** - All audit and utility functions created, tested, and documented

### 0.4 Admin Authentication (2 hari)

#### Task 0.4.1: Update Auth Provider

-   [x] Extend `lib/providers/auth_provider.dart`
-   [x] Add getter `isAdmin` (checks role == 'admin')
-   [x] Add method `hasPermission(String permission)` (future use)
-   [x] Update `loadProfile()` untuk load admin fields
-   [x] Update `lib/models/user_profile.dart` dengan admin fields (status, created_at, updated_at, last_login)
-   [x] Create test file `test/providers/auth_provider_test.dart` dengan 8 tests
-   [x] Test auth provider changes - all 8 tests passed

**Status**: ✅ **COMPLETED** - Auth provider updated with admin features:

-   Added `isAdmin` getter that returns true if profile.role == 'admin'
-   Added `hasPermission(String permission)` method - admin has all permissions, placeholder for future granular permissions
-   Updated `UserProfile` model with admin fields: status, created_at, updated_at, last_login
-   `loadProfile()` automatically loads all admin fields from profiles table
-   Created comprehensive test suite with 8 tests covering isAdmin logic, hasPermission logic, and UserProfile serialization

#### Task 0.4.2: Create Admin Guard

-   [x] Buat `lib/utils/admin_guard.dart`
-   [x] Implement `requireAdmin()` → throws jika bukan admin
-   [x] Implement `requirePermission()` → throws jika tidak punya permission
-   [x] Add widget `AdminGuardWidget` untuk wrap admin routes
-   [x] Create custom exceptions: `UnauthorizedException`, `ForbiddenException`
-   [x] Create `UnauthorizedScreen` untuk non-admin users
-   [x] Create test file `test/utils/admin_guard_test.dart` dengan 11 tests
-   [x] Test guards dengan different roles - all 11 tests passed

**Status**: ✅ **COMPLETED** - Admin guard system implemented:

-   **AdminGuard utility class** with two static methods:
    -   `requireAdmin()`: Throws UnauthorizedException if not authenticated, ForbiddenException if not admin
    -   `requirePermission(permission)`: Check specific permission (admin has all, others need explicit grant)
-   **AdminGuardWidget**: Widget wrapper for admin routes
    -   Redirects to login if not authenticated
    -   Shows UnauthorizedScreen if authenticated but not admin
    -   Shows child content if admin
-   **Custom Exceptions** (lib/utils/exceptions.dart):
    -   UnauthorizedException: For unauthenticated access attempts
    -   ForbiddenException: For authenticated but insufficient permissions
-   **UnauthorizedScreen** (lib/screens/unauthorized_screen.dart):
    -   User-friendly access denied message
    -   Shows current user email
    -   "Go Back" button to return to previous screen
    -   "Logout" button to switch accounts
-   **Comprehensive testing**: 11 tests covering all guard scenarios, exception handling, and permission checks

---

## Phase 1: Core Admin Features (Week 3-4)

**Goal**: Implementasi User Management dan Items Management lengkap

**Estimasi**: 2 minggu
**Priority**: Critical

### 1.1 Admin Dashboard Main (3 hari)

#### Task 1.1.1: Create Admin Layout

-   [x] Buat `lib/screens/admin/admin_layout.dart`
-   [x] Design sidebar navigation:
    -   [x] Dashboard
    -   [x] Users
    -   [x] Items
    -   [x] Storage
    -   [x] Analytics
    -   [x] Audit Logs
-   [x] Implement responsive layout (drawer for mobile)
-   [x] Add breadcrumbs widget
-   [x] Add user profile dropdown (admin name, logout)
-   [x] Add theme toggle (light/dark)
-   [x] Test layout di berbagai screen sizes

**Status**: ✅ **COMPLETED** - Admin layout created with:

-   **AdminLayout widget** (`lib/screens/admin/admin_layout.dart`):
    -   Sidebar navigation with 6 menu items (Dashboard, Users, Items, Storage, Analytics, Audit Logs)
    -   Responsive design: permanent sidebar on desktop (≥768px), drawer on mobile
    -   Integrated breadcrumbs support for navigation paths
    -   AppBar with app title, theme toggle, and user profile menu
    -   Protected with AdminGuardWidget - requires admin authentication
-   **Breadcrumbs widget** (`lib/widgets/admin/breadcrumbs.dart`):
    -   Display navigation path with clickable links
    -   Chevron separators between items
    -   Last item non-clickable (current page)
-   **ThemeProvider** (`lib/providers/theme_provider.dart`):
    -   Toggle between light/dark mode
    -   Persists theme preference in SharedPreferences
    -   Integrated with MaterialApp themeMode
-   **User Profile Menu**:
    -   Shows admin name, email, and "ADMIN" badge
    -   Logout action
-   **Test file**: `test/screens/admin/admin_layout_test.dart` with comprehensive widget tests

#### Task 1.1.2: Create Dashboard Home

-   [ ] Buat `lib/screens/admin/dashboard_home.dart`
-   [ ] Implement metrics cards:
    -   [ ] Total Users (dengan growth %)
    -   [ ] Total Items (dengan today's count)
    -   [ ] Active Loans
    -   [ ] Overdue Items (dengan warning badge)
    -   [ ] Storage Usage (dengan progress bar)
-   [ ] Implement quick actions section:
    -   [ ] Create User
    -   [ ] View All Items
    -   [ ] View Audit Logs
-   [ ] Add recent activity feed (last 10 actions)
-   [ ] Add charts:
    -   [ ] User growth line chart (last 30 days)
    -   [ ] Items status pie chart
-   [ ] Connect to backend analytics functions
-   [ ] Test dashboard loading & error states

#### Task 1.1.3: Admin State Management

-   [ ] Buat `lib/providers/admin_provider.dart`
-   [ ] Add state:
    -   `dashboardStats`
    -   `loading`
    -   `error`
-   [ ] Add methods:
    -   `loadDashboardStats()`
    -   `refreshStats()`
-   [ ] Implement auto-refresh (every 30 seconds)
-   [ ] Add error handling & retry
-   [ ] Test provider

### 1.2 User Management UI (5 hari)

#### Task 1.2.1: Users List Screen

-   [ ] Buat `lib/screens/admin/users/users_list_screen.dart`
-   [ ] Implement data table dengan columns:
    -   [ ] Avatar/Initial
    -   [ ] Name
    -   [ ] Email
    -   [ ] Role (dengan badge)
    -   [ ] Status (dengan badge)
    -   [ ] Items Count
    -   [ ] Created Date
    -   [ ] Actions (view, edit, delete)
-   [ ] Add search bar (search by name, email)
-   [ ] Add filters:
    -   [ ] Filter by role (all, user, admin)
    -   [ ] Filter by status (all, active, inactive, suspended)
-   [ ] Add sort options (by name, date, items count)
-   [ ] Implement pagination (20 users per page)
-   [ ] Add bulk actions:
    -   [ ] Bulk status update
    -   [ ] Bulk delete (dengan confirmation)
-   [ ] Test dengan large dataset

#### Task 1.2.2: User Detail Screen

-   [ ] Buat `lib/screens/admin/users/user_detail_screen.dart`
-   [ ] Section: Basic Info
    -   [ ] Display: name, email, user ID, role, status
    -   [ ] Edit button → navigate to edit form
-   [ ] Section: Account Info
    -   [ ] Created date, updated date, last login
-   [ ] Section: Activity Metrics
    -   [ ] Total items borrowed
    -   [ ] Total items returned
    -   [ ] Active loans count
    -   [ ] Overdue items count
-   [ ] Section: User Items
    -   [ ] List user's items (last 10)
    -   [ ] Button: View all items
-   [ ] Section: Actions
    -   [ ] Reset password
    -   [ ] Lock/Unlock account
    -   [ ] Change role
    -   [ ] Delete user
-   [ ] Test detail screen

#### Task 1.2.3: Create User Form

-   [ ] Buat `lib/screens/admin/users/create_user_screen.dart`
-   [ ] Form fields:
    -   [ ] Email (required, validation)
    -   [ ] Password (required, strength indicator)
    -   [ ] Full Name (optional)
    -   [ ] Role (dropdown: user, admin)
    -   [ ] Status (dropdown: active, inactive)
-   [ ] Checkboxes:
    -   [ ] Send verification email
-   [ ] Implement form validation
-   [ ] Submit handler:
    -   [ ] Call Supabase Auth create user
    -   [ ] Create profile record
    -   [ ] Create audit log
    -   [ ] Show success message
    -   [ ] Navigate to user detail
-   [ ] Error handling
-   [ ] Test create user flow

#### Task 1.2.4: Edit User Form

-   [ ] Buat `lib/screens/admin/users/edit_user_screen.dart`
-   [ ] Load user data
-   [ ] Form fields:
    -   [ ] Email (editable)
    -   [ ] Full Name
    -   [ ] Role (dropdown)
    -   [ ] Status (dropdown)
-   [ ] Update handler:
    -   [ ] Call admin update function
    -   [ ] Update profile
    -   [ ] Create audit log
    -   [ ] Show success message
-   [ ] Validation
-   [ ] Test edit flow

#### Task 1.2.5: Delete User Functionality

-   [ ] Buat confirmation dialog `lib/widgets/admin/delete_user_dialog.dart`
-   [ ] Options:
    -   [ ] Soft delete (set inactive)
    -   [ ] Hard delete (permanent)
-   [ ] Hard delete requires:
    -   [ ] Admin password re-entry
    -   [ ] Type "DELETE" confirmation
-   [ ] Show warning tentang consequences
-   [ ] Implement delete:
    -   [ ] Call `admin_delete_user()` function
    -   [ ] Show progress
    -   [ ] Handle errors
    -   [ ] Create audit log
    -   [ ] Show success, navigate back
-   [ ] Test delete flow (soft & hard)

#### Task 1.2.6: User Actions

-   [ ] Implement reset password:
    -   [ ] Send reset email via Supabase Auth
    -   [ ] Show confirmation
-   [ ] Implement lock/unlock account:
    -   [ ] Update status
    -   [ ] Create audit log
    -   [ ] Show confirmation
-   [ ] Implement change role:
    -   [ ] Confirmation dialog
    -   [ ] Update role via function
    -   [ ] Audit log
    -   [ ] Show success
-   [ ] Test semua actions

### 1.3 Items Management UI (4 hari)

#### Task 1.3.1: Items List Screen

-   [ ] Buat `lib/screens/admin/items/items_list_screen.dart`
-   [ ] Implement data table:
    -   [ ] Photo thumbnail
    -   [ ] Item name
    -   [ ] Owner name (linkable ke user detail)
    -   [ ] Borrower name
    -   [ ] Status (badge)
    -   [ ] Borrow date
    -   [ ] Due date
    -   [ ] Actions (view, edit, delete)
-   [ ] Add search (by item name, borrower, notes)
-   [ ] Add filters:
    -   [ ] By status (borrowed, returned, overdue)
    -   [ ] By user (dropdown)
    -   [ ] By date range
-   [ ] Add sort options
-   [ ] Implement pagination (20 items per page)
-   [ ] Add bulk actions:
    -   [ ] Bulk status update
    -   [ ] Bulk delete
    -   [ ] Export to CSV
-   [ ] Highlight overdue items (red)
-   [ ] Test dengan large dataset

#### Task 1.3.2: Item Detail Screen

-   [ ] Buat `lib/screens/admin/items/item_detail_screen.dart`
-   [ ] Section: Item Info
    -   [ ] Photo (full size)
    -   [ ] Name
    -   [ ] Status
    -   [ ] Notes
-   [ ] Section: Borrower Info
    -   [ ] Borrower name
    -   [ ] Contact info (jika ada)
-   [ ] Section: Dates
    -   [ ] Borrow date
    -   [ ] Due date
    -   [ ] Return date (jika returned)
    -   [ ] Days overdue (jika overdue)
-   [ ] Section: Owner Info
    -   [ ] Owner name (linkable ke user detail)
    -   [ ] Owner email
-   [ ] Section: History
    -   [ ] Created date
    -   [ ] Last updated
-   [ ] Section: Actions
    -   [ ] Edit item
    -   [ ] Mark as returned
    -   [ ] Delete item
    -   [ ] View photo full screen
-   [ ] Test detail screen

#### Task 1.3.3: Create Item (for User)

-   [ ] Buat `lib/screens/admin/items/create_item_screen.dart`
-   [ ] Select user (dropdown atau search)
-   [ ] Form fields:
    -   [ ] Item name
    -   [ ] Photo upload
    -   [ ] Borrower name
    -   [ ] Borrower contact (optional)
    -   [ ] Borrow date
    -   [ ] Due date
    -   [ ] Notes
-   [ ] Submit handler:
    -   [ ] Upload photo
    -   [ ] Create item
    -   [ ] Create audit log
    -   [ ] Show success
-   [ ] Test create flow

#### Task 1.3.4: Edit Item

-   [ ] Buat `lib/screens/admin/items/edit_item_screen.dart`
-   [ ] Load item data
-   [ ] Form dengan semua fields editable
-   [ ] Update photo option
-   [ ] Update handler:
    -   [ ] Save old values untuk audit
    -   [ ] Update item
    -   [ ] Create audit log
    -   [ ] Show success
-   [ ] Test edit flow

#### Task 1.3.5: Delete Item

-   [ ] Confirmation dialog
-   [ ] Options:
    -   [ ] Delete item only
    -   [ ] Delete item + photo
-   [ ] Delete handler:
    -   [ ] Delete photo dari storage
    -   [ ] Delete item record
    -   [ ] Create audit log
    -   [ ] Show success
-   [ ] Test delete

### 1.4 Admin Services (2 hari)

#### Task 1.4.1: Create Admin Service

-   [ ] Buat `lib/services/admin_service.dart`
-   [ ] Implement methods:
    -   [ ] `getDashboardStats()`
    -   [ ] `getAllUsers({filters, pagination})`
    -   [ ] `getUserDetails(userId)`
    -   [ ] `createUser(userData)`
    -   [ ] `updateUser(userId, userData)`
    -   [ ] `deleteUser(userId, hardDelete)`
    -   [ ] `getAllItems({filters, pagination})`
    -   [ ] `getItemDetails(itemId)`
    -   [ ] `createItem(userId, itemData)`
    -   [ ] `updateItem(itemId, itemData)`
    -   [ ] `deleteItem(itemId)`
-   [ ] Add error handling
-   [ ] Add retry logic
-   [ ] Test service methods

#### Task 1.4.2: Create Audit Service

-   [ ] Buat `lib/services/audit_service.dart`
-   [ ] Implement methods:
    -   [ ] `createAuditLog(actionType, tableName, recordId, oldValues, newValues, metadata)`
    -   [ ] `getAuditLogs({filters, pagination})`
    -   [ ] `getUserAuditLogs(userId)`
    -   [ ] `getTableAuditLogs(tableName)`
-   [ ] Auto-capture metadata (timestamp, dll)
-   [ ] Test audit service

---

## Phase 2: Storage Management (Week 5)

**Goal**: Implementasi management files dan storage

**Estimasi**: 1 minggu
**Priority**: High

### 2.1 Storage Overview (2 hari)

#### Task 2.1.1: Storage Dashboard

-   [ ] Buat `lib/screens/admin/storage/storage_dashboard.dart`
-   [ ] Metrics cards:
    -   [ ] Total storage used
    -   [ ] Number of files
    -   [ ] Storage by user (top 10)
    -   [ ] Orphaned files count
-   [ ] Chart:
    -   [ ] Storage usage trend (last 30 days)
    -   [ ] File type distribution (pie chart)
-   [ ] Actions:
    -   [ ] Run cleanup
    -   [ ] View all files
-   [ ] Test dashboard

#### Task 2.1.2: Storage Analytics Function

-   [ ] Implement function `admin_get_storage_stats()` (sudah di Phase 0)
-   [ ] Test function returns correct data
-   [ ] Connect to UI

### 2.2 File Browser (2 hari)

#### Task 2.2.1: File Browser UI

-   [ ] Buat `lib/screens/admin/storage/file_browser_screen.dart`
-   [ ] Implement file list:
    -   [ ] Thumbnail preview
    -   [ ] File name (path)
    -   [ ] Size
    -   [ ] Upload date
    -   [ ] Owner
    -   [ ] Actions (view, download, delete)
-   [ ] Add search by filename
-   [ ] Add filters:
    -   [ ] By user
    -   [ ] By date range
    -   [ ] Orphaned only
-   [ ] Pagination
-   [ ] Bulk selection & actions
-   [ ] Test file browser

#### Task 2.2.2: File Detail View

-   [ ] Buat `lib/screens/admin/storage/file_detail_screen.dart`
-   [ ] Display file preview (image)
-   [ ] File metadata:
    -   [ ] Path
    -   [ ] Size
    -   [ ] Type
    -   [ ] Upload date
    -   [ ] Owner info
    -   [ ] Related item (jika ada)
-   [ ] Actions:
    -   [ ] Download file
    -   [ ] Delete file
    -   [ ] View full size
-   [ ] Test detail view

#### Task 2.2.3: File Operations

-   [ ] Implement download functionality
    -   [ ] Generate signed URL
    -   [ ] Download to device
    -   [ ] Show progress
-   [ ] Implement delete
    -   [ ] Confirmation dialog
    -   [ ] Bulk delete support
    -   [ ] Update related items (set photo_url = null)
    -   [ ] Create audit log
-   [ ] Test operations

### 2.3 Storage Cleanup (1 hari)

#### Task 2.3.1: Orphaned Files Detection

-   [ ] Implement function untuk detect orphaned files
-   [ ] Query files di storage bucket
-   [ ] Cross-check dengan items.photo_url
-   [ ] Return list orphaned files
-   [ ] Test detection

#### Task 2.3.2: Storage Cleanup Tool

-   [ ] Buat cleanup interface
-   [ ] Show orphaned files list dengan preview
-   [ ] Estimate storage to be freed
-   [ ] Confirmation dialog
-   [ ] Execute cleanup:
    -   [ ] Delete orphaned files
    -   [ ] Create audit log
    -   [ ] Show result (files deleted, space freed)
-   [ ] Test cleanup

---

## Phase 3: Analytics & Testing (Week 6-8)

**Goal**: Dashboard analytics lengkap dan comprehensive testing

**Estimasi**: 3 minggu
**Priority**: Medium-High

### 3.1 Advanced Analytics (4 hari)

#### Task 3.1.1: User Analytics Screen

-   [ ] Buat `lib/screens/admin/analytics/user_analytics_screen.dart`
-   [ ] Charts:
    -   [ ] User growth line chart (selectable period: 7d, 30d, 90d)
    -   [ ] New users per day/week/month
    -   [ ] Active users trend
-   [ ] Metrics:
    -   [ ] Total users
    -   [ ] Active users (last 7/30 days)
    -   [ ] Inactive users
    -   [ ] Growth rate %
-   [ ] Tables:
    -   [ ] Top active users (most items)
    -   [ ] Recently registered
    -   [ ] Inactive users (no activity 30+ days)
-   [ ] Export report button (CSV)
-   [ ] Test analytics

#### Task 3.1.2: Items Analytics Screen

-   [ ] Buat `lib/screens/admin/analytics/items_analytics_screen.dart`
-   [ ] Charts:
    -   [ ] Items created per day/week/month
    -   [ ] Borrowed vs Returned trend
    -   [ ] Overdue items trend
    -   [ ] Average loan duration
-   [ ] Metrics:
    -   [ ] Total items
    -   [ ] Currently borrowed
    -   [ ] Returned
    -   [ ] Overdue
    -   [ ] Return rate %
-   [ ] Tables:
    -   [ ] Most borrowed items (by count)
    -   [ ] Longest loans (active)
    -   [ ] Users with most overdue
-   [ ] Export report button
-   [ ] Test analytics

#### Task 3.1.3: Analytics Backend Integration

-   [ ] Connect charts to database functions
-   [ ] Implement data aggregation
-   [ ] Add loading states
-   [ ] Add error handling
-   [ ] Test with real data

### 3.2 Report Generation (3 hari)

#### Task 3.2.1: Simple Report Builder

-   [ ] Buat `lib/screens/admin/reports/report_screen.dart`
-   [ ] Pre-defined report types:
    -   [ ] User Summary Report
    -   [ ] Items Summary Report
    -   [ ] Overdue Items Report
-   [ ] Configure parameters:
    -   [ ] Date range selector
    -   [ ] Basic filters
-   [ ] Preview report data
-   [ ] Export options (CSV, PDF)
-   [ ] Test report builder

#### Task 3.2.2: Export to CSV

-   [ ] Install package: `csv`
-   [ ] Implement CSV export:
    -   [ ] User data
    -   [ ] Items data
    -   [ ] Analytics data
-   [ ] Download files
-   [ ] Test exports

#### Task 3.2.3: Export to PDF (Optional)

-   [ ] Install package: `pdf` dan `printing`
-   [ ] Implement basic PDF generator
-   [ ] Design simple PDF layout:
    -   [ ] Header (title, date)
    -   [ ] Summary section
    -   [ ] Data tables
-   [ ] Generate & download PDF
-   [ ] Test PDF export

### 3.3 Audit Logs UI (2 hari)

#### Task 3.3.1: Audit Logs Screen

-   [ ] Buat `lib/screens/admin/audit/audit_logs_screen.dart`
-   [ ] List audit logs:
    -   [ ] Timestamp
    -   [ ] Admin user (name)
    -   [ ] Action type (badge dengan color)
    -   [ ] Table/Resource
    -   [ ] Record ID (linkable jika memungkinkan)
    -   [ ] Summary (e.g., "Updated user role from 'user' to 'admin'")
    -   [ ] Actions (view details)
-   [ ] Filters:
    -   [ ] By admin user
    -   [ ] By action type
    -   [ ] By table
    -   [ ] By date range
-   [ ] Search by record ID
-   [ ] Pagination (50 logs per page)
-   [ ] Test logs screen

#### Task 3.3.2: Audit Log Detail

-   [ ] Buat `lib/screens/admin/audit/audit_log_detail_screen.dart`
-   [ ] Show full details:
    -   [ ] Admin user info
    -   [ ] Action type
    -   [ ] Table name
    -   [ ] Record ID
    -   [ ] Old values (JSON formatted)
    -   [ ] New values (JSON formatted)
    -   [ ] Diff view (highlight changes)
    -   [ ] Metadata
    -   [ ] Timestamp
-   [ ] Test detail view

#### Task 3.3.3: Audit Export

-   [ ] Export audit logs to CSV
-   [ ] Filter export (same filters as screen)
-   [ ] Include all details
-   [ ] Test export

### 3.4 Real-time Features (2 hari)

#### Task 3.4.1: Live Activity Feed

-   [ ] Buat widget `lib/widgets/admin/live_activity_feed.dart`
-   [ ] Subscribe ke Realtime changes:
    -   [ ] New users registered
    -   [ ] New items created
    -   [ ] Items returned
    -   [ ] Admin actions
-   [ ] Display feed dengan:
    -   [ ] Icon based on activity type
    -   [ ] Description
    -   [ ] Timestamp (relative: "2 min ago")
    -   [ ] User/admin who did action
-   [ ] Auto-scroll ke latest
-   [ ] Limit feed to last 20 activities
-   [ ] Test real-time updates

#### Task 3.4.2: Live Metrics

-   [ ] Subscribe ke changes di tables
-   [ ] Auto-update metrics cards:
    -   [ ] Total users (increment on insert)
    -   [ ] Total items
    -   [ ] Active loans
-   [ ] Show live indicator (green dot)
-   [ ] Test real-time metrics

### 3.5 Comprehensive Testing (5 hari)

#### Task 3.5.1: Unit Tests

-   [ ] Write unit tests untuk:
    -   [ ] Admin models
    -   [ ] Admin services
    -   [ ] Admin providers
    -   [ ] Utility functions
-   [ ] Target: 70%+ code coverage
-   [ ] Run tests: `flutter test`
-   [ ] Fix failing tests

#### Task 3.5.2: Widget Tests

-   [ ] Write widget tests untuk:
    -   [ ] Admin dashboard
    -   [ ] Users list screen
    -   [ ] Items list screen
    -   [ ] Key admin widgets
-   [ ] Test user interactions
-   [ ] Test loading & error states
-   [ ] Run widget tests
-   [ ] Fix issues

#### Task 3.5.3: Integration Tests

-   [ ] Write integration tests:
    -   [ ] Admin login flow
    -   [ ] Create user flow (end-to-end)
    -   [ ] Edit user flow
    -   [ ] Delete user flow
    -   [ ] Create item flow
    -   [ ] Audit log creation
-   [ ] Run integration tests
-   [ ] Fix issues

#### Task 3.5.4: Manual Testing

-   [ ] Test all admin screens manually
-   [ ] Test dengan different roles (user, admin)
-   [ ] Test edge cases:
    -   [ ] Empty states
    -   [ ] Large datasets (100+ users, 500+ items)
    -   [ ] Slow network
    -   [ ] Error scenarios
-   [ ] Create bug list
-   [ ] Fix critical bugs

#### Task 3.5.5: Security Testing

-   [ ] Test RLS policies:
    -   [ ] Regular user tidak bisa akses admin functions
    -   [ ] Admin bisa akses all user data
    -   [ ] Storage access properly controlled
-   [ ] Test authentication:
    -   [ ] Admin route guards
    -   [ ] Session management
-   [ ] Test audit logging (all actions logged)
-   [ ] Fix security issues

### 3.6 UI/UX Polish (3 hari)

#### Task 3.6.1: UI Consistency

-   [ ] Review all admin screens untuk consistency:
    -   [ ] Colors (follow AppTheme)
    -   [ ] Typography (font sizes, weights)
    -   [ ] Spacing (padding, margins)
    -   [ ] Button styles
    -   [ ] Card styles
-   [ ] Fix inconsistencies

#### Task 3.6.2: Loading & Error States

-   [ ] Add loading indicators untuk:
    -   [ ] Screen initial load (skeleton/shimmer)
    -   [ ] Button actions (spinner in button)
    -   [ ] Form submissions
    -   [ ] Data refresh
-   [ ] Standardize error messages
-   [ ] User-friendly error text
-   [ ] Error toast/snackbar styling
-   [ ] Retry mechanisms
-   [ ] Test loading & error states

#### Task 3.6.3: Empty States

-   [ ] Design empty states untuk:
    -   [ ] No users
    -   [ ] No items
    -   [ ] No audit logs
    -   [ ] No search results
-   [ ] Add illustrations atau icons
-   [ ] Add helpful text & call-to-action
-   [ ] Test empty states

#### Task 3.6.4: Responsive Design

-   [ ] Test admin UI di berbagai screen sizes:
    -   [ ] Desktop (large screens)
    -   [ ] Tablet (medium)
    -   [ ] Mobile (small)
-   [ ] Fix layout issues
-   [ ] Ensure usability di all sizes
-   [ ] Test navigation (sidebar vs drawer)

### 3.7 Performance Optimization (2 hari)

#### Task 3.7.1: Performance Audit

-   [ ] Run Flutter performance profiling
-   [ ] Identify bottlenecks:
    -   [ ] Slow renders
    -   [ ] Heavy computations
    -   [ ] Large rebuilds
-   [ ] Fix performance issues

#### Task 3.7.2: Optimization Implementation

-   [ ] Ensure all lists use pagination
-   [ ] Implement lazy loading untuk images
-   [ ] Limit initial data fetch
-   [ ] Add caching where appropriate:
    -   [ ] Dashboard stats (cache 5 min)
    -   [ ] User list (cache 2 min)
-   [ ] Invalidate cache on updates
-   [ ] Test with large datasets

### 3.8 Documentation (2 hari)

#### Task 3.8.1: Admin User Guide

-   [ ] Buat `docs/admin-user-guide.md`
-   [ ] Sections:
    -   [ ] Admin login
    -   [ ] Dashboard overview
    -   [ ] User management guide
    -   [ ] Items management guide
    -   [ ] Storage management
    -   [ ] Analytics & reports
    -   [ ] Audit logs
-   [ ] Tips & best practices

#### Task 3.8.2: Developer Documentation

-   [ ] Update `SCHEMA_DOCS.md` dengan admin tables
-   [ ] Dokumentasi admin RLS policies
-   [ ] Dokumentasi admin functions
-   [ ] Code comments untuk complex logic

#### Task 3.8.3: Migration Guide

-   [ ] Buat `docs/admin-migration-guide.md`
-   [ ] Steps to apply migrations:
    -   [ ] Connect to Supabase
    -   [ ] Run migration files in order
    -   [ ] Create initial admin user
    -   [ ] Verify RLS policies
    -   [ ] Test admin login
-   [ ] Troubleshooting section

### 3.9 Deployment Preparation (2 hari)

#### Task 3.9.1: Production Database Setup

-   [ ] Apply all migrations ke production Supabase
-   [ ] Verify RLS policies
-   [ ] Create initial admin account
-   [ ] Test production database connections
-   [ ] Backup production database

#### Task 3.9.2: Environment Configuration

-   [ ] Review environment variables
-   [ ] Production Supabase URL & keys correct
-   [ ] Test configuration
-   [ ] Document environment setup

#### Task 3.9.3: Build & Release

-   [ ] Run `flutter analyze` (zero issues)
-   [ ] Run all tests (all passing)
-   [ ] Build release APK/IPA:
    -   [ ] `flutter build apk --release`
    -   [ ] `flutter build ipa --release` (jika perlu)
-   [ ] Test release builds
-   [ ] Prepare release notes
-   [ ] Upload to distribution channel

---

## Post-Launch Tasks (Ongoing)

### Monitoring & Maintenance

#### Task: Setup Monitoring

-   [ ] Monitor admin usage patterns
-   [ ] Monitor performance metrics
-   [ ] Setup alerts untuk critical errors
-   [ ] Regular database backups

#### Task: Regular Reviews

-   [ ] Weekly: Review audit logs
-   [ ] Monthly: Review user feedback
-   [ ] Monthly: Performance review
-   [ ] Quarterly: Security review

### Future Enhancements (Nice to Have)

#### Enhancement: Advanced Features

-   [ ] Bulk import users (CSV)
-   [ ] Advanced search with multiple criteria
-   [ ] Saved filters/views
-   [ ] Custom dashboard widgets
-   [ ] Email notifications untuk admin events
-   [ ] Two-factor authentication for admin accounts

---

## Checklist Summary by Phase

### Phase 0: Foundation ✅

-   [ ] Database schema (audit_logs, profiles update)
-   [ ] RLS policies (admin bypass)
-   [ ] Database functions (12 functions)
-   [ ] Admin authentication

**Total Tasks**: 10
**Estimated Completion**: Week 2

### Phase 1: Core Features ✅

-   [ ] Admin dashboard & layout
-   [ ] User management (CRUD + actions)
-   [ ] Items management (CRUD)
-   [ ] Admin services

**Total Tasks**: 18
**Estimated Completion**: Week 4

### Phase 2: Storage ✅

-   [ ] Storage dashboard
-   [ ] File browser
-   [ ] Storage cleanup

**Total Tasks**: 7
**Estimated Completion**: Week 5

### Phase 3: Analytics & Launch ✅

-   [ ] Advanced analytics (users, items)
-   [ ] Report generation
-   [ ] Audit logs UI
-   [ ] Real-time features
-   [ ] Comprehensive testing
-   [ ] UI/UX polish
-   [ ] Performance optimization
-   [ ] Documentation
-   [ ] Deployment

**Total Tasks**: 30
**Estimated Completion**: Week 8

---

## Progress Tracking

**Overall Progress**: 0/65 tasks completed (0%)

### Weekly Goals

**Week 1**: Database Schema, RLS Policies
**Week 2**: Database Functions, Admin Auth
**Week 3**: Admin Layout, Dashboard, User Management (List, Detail)
**Week 4**: User Management (Forms, Actions), Items Management, Services
**Week 5**: Storage Management (Dashboard, Browser, Cleanup)
**Week 6**: Analytics (Users, Items), Reports, Audit Logs UI
**Week 7**: Real-time Features, Testing (Unit, Widget, Integration)
**Week 8**: Manual Testing, UI Polish, Performance, Documentation, Deployment

---

## Notes & Best Practices

1. **Always test after each task**: Jangan tunggu sampai akhir fase
2. **Create audit logs for all admin actions**: Critical untuk security dan compliance
3. **Use transactions for destructive operations**: Prevent partial failures
4. **Implement confirmation dialogs untuk destructive actions**: Delete, bulk operations
5. **Keep UI responsive**: Use pagination, lazy loading, caching
6. **Write tests as you go**: Jangan tumpuk testing di akhir
7. **Document as you build**: Update docs setiap selesai feature
8. **Regular code reviews**: Review sendiri atau dengan tim
9. **Backup before major changes**: Backup database sebelum migrate

---

**Document Owner**: Development Team
**Last Updated**: 2 Desember 2025
**Version**: 2.0 (Simplified)
**Status**: Ready for Implementation 🚀
