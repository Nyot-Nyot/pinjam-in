User Analytics (Task 3.1.1) - Local TODO

Completed:

-   [x] Create `lib/screens/admin/analytics/user_analytics_screen.dart`
-   [x] Add key metrics cards (Total Users, Active Users, Inactive Users, New Today)
-   [x] User growth chart — Line chart and selectable period (7/30/90)
-   [x] Top active users list
-   [x] Recently registered users list
-   [x] Inactive users list (limited)
-   [x] Quick Export CSV button (placeholder) - UI only
-   [x] Widget test to ensure the UI renders and shows metrics

Open items / follow-ups (optional):

-   [ ] Implement actual CSV export functionality (server-side or client-side)
-   [ ] Add more advanced charts (New users per day/week/month, Active users trend split)
-   [ ] Add pagination to recently registered and inactive lists
-   [ ] Add filters and search on top users and recently registered lists
-   [ ] Add performance tests for large datasets

Notes:

-   The UI uses `AdminProvider` for data (dashboard stats, user growth, top users, recently registered, inactive users).
-   `AdminProvider` now supports setting `userGrowthDays` and will fetch a different window when changed.
