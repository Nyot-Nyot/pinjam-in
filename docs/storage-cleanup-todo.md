Storage Cleanup TODO (Task 2.3.2)

Completed:

-   Implemented Storage Cleanup UI in `lib/screens/admin/storage/storage_cleanup_screen.dart`
-   Wired 'Run cleanup' button in `StorageDashboard` to navigate to cleanup screen
-   Implemented listing of orphaned files using RPC `admin_list_orphaned_storage_files`
-   Added UI selection, bulk delete, per-item delete
-   Used `AdminService.deleteStorageObjects()` for deletion with audit
-   Added Estimate of storage freed and summary SnackBars
-   Added widget test `test/screens/admin/storage/storage_cleanup_screen_test.dart`
-   Marked task as done in `docs/admin-implementation-plan.md`

Remaining (possible follow-ups):

-   Add a background worker to run cleanup automatically (scheduled job)
-   Implement pagination and lazy loading for very large buckets
-   Add more robust error handling for partial deletes with per-item logs
-   Show individual delete progress in the UI (per-item progress indicators)
-   UI: Add a preview modal for images (larger preview) before delete
-   Performance: Add a limit or ignore large pagination sizes to avoid client OOM

Notes:

-   This implementation relies on `admin_list_orphaned_storage_files` RPC and `AdminService.deleteStorageObjects` existing on the backend and properly authorized. If server RLS blocks operations, ensure migration `013_admin_update_delete_policy.sql` is applied.
