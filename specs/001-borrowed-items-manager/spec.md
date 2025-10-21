# Specification: Borrowed Items Manager

**Created**: 2025-10-21
**Last Updated**: 2025-10-21
**Version**: 1.1

## 1. Feature Description

Users need an application to manage items they have lent to others. This feature allows authenticated users to save, edit, and delete records of borrowed items, with data stored securely in the cloud. Users can store the item's name, the borrower's name, and optionally, a photo of the item and the borrower's contact information. A return date can be set, but it is optional. The homepage will display a list of borrowed items, and a simple swipe gesture on an item will mark it as returned. The application will also feature a dashboard with interesting statistics.

## 2. User Scenarios

### 2.1. User Registration & Login

As a new user, I want to create an account so I can securely save my data.

-   I open the app and choose to sign up.
-   I provide my email and a password.
-   I log in to the app and can start using the features.

### 2.2. Adding a New Borrowed Item

As a user, I want to record a new item that I have lent to someone so that I don't forget about it.

-   I open the app and navigate to the "add item" screen.
-   I can optionally take a new photo of the item or select one from my gallery.
-   I enter the name of the item (e.g., "Book - The Hobbit").
-   I enter the name of the person who borrowed it (e.g., "John Doe").
-   I have the option to select John Doe's contact from my phone's contact list.
-   I can optionally set a return date.
-   I can optionally add notes.
-   I save the item, and it appears on my list of currently borrowed items.

### 2.3. Viewing the List of Borrowed Items

As a user, I want to see all the items I have lent out on the main screen.

-   I open the app and see a list of all items currently on loan.
-   Each item in the list displays the item's name, and the borrower's name.
-   If a photo was added, it is displayed. Otherwise, a default box icon is shown.

### 2.4. Marking an Item as Returned

As a user, I want to easily mark an item as returned when I get it back.

-   From the homepage list, I find the item that has been returned.
-   I swipe on the item's widget.
-   The item is marked as "returned" and moved from the active list to a history or completed list.

### 2.5. Editing an Existing Item

As a user, I want to be able to edit the details of a borrowed item.

-   I find the item in the list and select it to view its details.
-   I choose to edit the item and can change its details.
-   I save the changes.

### 2.6. Deleting a Borrowed Item Record

As a user, I want to be able to delete a record entirely.

-   I find the item in the list and select it.
-   I choose the delete option and confirm the action.
-   The item record is permanently removed.

### 2.7. Viewing Statistics

As a user, I want to see interesting statistics about my lending habits.

-   I navigate to the dashboard screen.
-   I can see data such as the total number of items lent, the most frequent borrower, or items that are overdue.

## 3. Functional Requirements

### 3.1. User Authentication

-   The system must allow users to sign up and log in using an email and password.
-   All user data must be associated with their account.

### 3.2. Item Management

-   The system must allow users to create, read, update, and delete (CRUD) records of borrowed items.
-   Each item record must have a field for the item name (required) and borrower name (required).
-   Each item record must support storing an optional photo. If no photo is provided, the value should be null.
-   Each item record must have an optional field for a return date.
-   Each item record must have an optional field for notes.
-   Each item record must have a status (e.g., "borrowed," "returned").

### 3.3. Homepage / Main List

-   The application's main screen must display a list of all items with the "borrowed" status belonging to the logged-in user.
-   The list must be searchable by item name and borrower name.
-   Users must be able to mark an item as "returned" using a swipe gesture.

### 3.4. Contact Integration

-   The system should provide an optional field for the borrower's contact information.
-   On mobile platforms that support it, this should be implemented using a native contact picker.

### 3.5. Statistics Dashboard

-   The system must provide a screen that displays statistics based on the user's borrowing activities.
-   Statistics must include total items lent, items on loan vs. returned, and overdue items.

### 3.6. Data Persistence

-   All data must be persisted in a cloud database (Supabase) and associated with the user's account.

## 4. Non-Functional Requirements

### 4.1. Usability

-   The user interface should be intuitive and easy to navigate.
-   Key actions should be quick and require minimal steps.

### 4.2. Performance

-   The application should load quickly and feel responsive.
-   The list of borrowed items should scroll smoothly.

### 4.3. Security

-   User passwords must be stored securely (handled by Supabase Auth).
-   Users must only be able to access their own data.

## 5. Success Criteria

-   **Task Completion Rate**: 95% of new users can successfully sign up, add an item, and mark it as returned without assistance.
-   **Time on Task**: A user can add a new borrowed item in under 60 seconds.
-   **User Satisfaction**: The app achieves an average rating of 4.5 stars or higher.

## 6. Edge Cases & Assumptions

### 6.1. Edge Cases

-   **Permission Denied**: The app should gracefully handle cases where camera, gallery, or contact permissions are denied.
-   **No Data**: The app should display a clear empty state on screens when no items have been added.
-   **Invalid Input**: The app must validate required fields and prevent saving if they are empty.
-   **Network Error**: The app should display a user-friendly message if it cannot connect to the backend.

### 6.2. Assumptions

-   An active internet connection is required for most operations.
-   Users are on mobile devices where contact and camera integration is possible.

## 7. Out of Scope

-   Offline-first mode (data access without an internet connection).
-   Social features or sharing.
-   Automated reminders or notifications for return dates.
-   Web or desktop version of the application.

## 8. Key Entities

### 8.1. Item Entity

| Field                 | Type          | Constraints                             | Description                                   |
| :-------------------- | :------------ | :-------------------------------------- | :-------------------------------------------- |
| `id`                  | `UUID`        | Primary Key, Not Null                   | Unique identifier for the item record.        |
| `user_id`             | `UUID`        | Foreign Key (to `auth.users`), Not Null | The user who owns this item record.           |
| `name`                | `TEXT`        | Not Null, Min 3 chars                   | The name of the borrowed item.                |
| `photo_url`           | `TEXT`        | Nullable                                | URL to the item's photo in Supabase Storage.  |
| `borrower_name`       | `TEXT`        | Not Null, Min 3 chars                   | The name of the person who borrowed the item. |
| `borrower_contact_id` | `TEXT`        | Nullable                                | Contact identifier or manual entry.           |
| `borrow_date`         | `TIMESTAMPTZ` | Not Null, Default `NOW()`               | The date the item was lent out.               |
| `return_date`         | `DATE`        | Nullable                                | The expected return date.                     |
| `status`              | `TEXT`        | Not Null, Default `'borrowed'`          | Current status: `'borrowed'` or `'returned'`. |
| `notes`               | `TEXT`        | Nullable                                | Optional notes about the transaction.         |
| `created_at`          | `TIMESTAMPTZ` | Not Null, Default `NOW()`               | Timestamp of when the record was created.     |

### 8.2. User Entity (Supabase Auth)

This entity is managed by Supabase Authentication.
| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` | Primary Key, managed by Supabase. |
| `email` | `TEXT` | User's email address. |
