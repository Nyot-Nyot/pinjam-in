# Specification: Borrowed Items Manager

**Created**: 2025-10-21
**Last Updated**: 2025-10-21
**Version**: 1.0

## 1. Feature Description

Users need an application to manage items they have lent to others. Many people forget about items they have lent out, leading to the items being lost without knowing who has them. This feature will allow users to save, edit, and delete records of borrowed items. Users can store a photo of the item, the item's name, the borrower's name, and optionally, the borrower's contact information (integrating with a mobile contact picker). A return date can be set, but it is optional. There is also an optional "notes" field for important details about the transaction, item, or borrower. The homepage will display a list of borrowed items, and a simple swipe gesture on an item will mark it as returned. The application will also feature a dashboard with interesting statistics.

## 2. User Scenarios

### 2.1. Adding a New Borrowed Item

As a user, I want to record a new item that I have lent to someone so that I don't forget about it.

-   I open the app and navigate to the "add item" screen.
-   I can take a new photo of the item or select one from my gallery.
-   I enter the name of the item (e.g., "Book - The Hobbit").
-   I enter the name of the person who borrowed it (e.g., "John Doe").
-   I have the option to select John Doe's contact from my phone's contact list.
-   I can optionally set a return date.
-   I can optionally add notes, such as "He borrowed it for his book report."
-   I save the item, and it appears on my list of currently borrowed items.

### 2.2. Viewing the List of Borrowed Items

As a user, I want to see all the items I have lent out on the main screen so I can quickly track them.

-   I open the app and see a list of all items currently on loan.
-   Each item in the list displays the item's photo, name, and the borrower's name.

### 2.3. Marking an Item as Returned

As a user, I want to easily mark an item as returned when I get it back.

-   From the homepage list, I find the item that has been returned.
-   I swipe on the item's widget.
-   The item is marked as "returned" and moved from the active list to a history or completed list.

### 2.4. Editing an Existing Item

As a user, I want to be able to edit the details of a borrowed item in case I made a mistake or need to update information.

-   I find the item in the list and select it to view its details.
-   I choose to edit the item.
-   I can change the item name, borrower, return date, or notes.
-   I save the changes.

### 2.5. Deleting a Borrowed Item Record

As a user, I want to be able to delete a record entirely if it was created by mistake or is no longer relevant.

-   I find the item in the list and select it.
-   I choose the delete option and confirm the action.
-   The item record is permanently removed from the application.

### 2.6. Viewing Statistics

As a user, I want to see interesting statistics about my lending habits.

-   I navigate to the statistics or dashboard screen.
-   I can see data such as the total number of items lent, the most frequent borrower, or items that are overdue.

## 3. Functional Requirements

### 3.1. Item Management

-   The system must allow users to create, read, update, and delete (CRUD) records of borrowed items.
-   Each item record must have a field for the item name (required) and borrower name (required).
-   Each item record must support storing one photo.
-   Each item record must have an optional field for a return date.
-   Each item record must have an optional field for notes.
-   Each item record must have a status (e.g., "borrowed," "returned").

### 3.2. Homepage / Main List

-   The application's main screen must display a list of all items with the "borrowed" status.
-   The list must be searchable by item name and borrower name.
-   Users must be able to mark an item as "returned" using a swipe gesture on the list item.

### 3.3. Contact Integration

-   The system should provide an option to link a borrower to a contact from the user's native contact list (Android/iOS). This is an optional feature.

### 3.4. Statistics Dashboard

-   The system must provide a screen that displays statistics related to borrowing activities.
-   The statistics must include at least:
    -   Total items lent.
    -   Number of items currently on loan vs. returned.
    -   A list of overdue items. An item is considered "overdue" if it has a return date set and that date is in the past.

### 3.5. Data Persistence

-   All data must be stored locally on the user's device.

## 4. Non-Functional Requirements

### 4.1. Usability

-   The user interface should be intuitive and easy to navigate.
-   Key actions like adding an item and marking it as returned should be quick and require minimal steps.

### 4.2. Performance

-   The application should load quickly.
-   The list of borrowed items should scroll smoothly, even with a large number of entries and images.

## 5. Success Criteria

-   **Task Completion Rate**: 95% of new users can successfully add a new item and mark it as returned without assistance.
-   **Time on Task**: A user can add a new borrowed item in under 60 seconds.
-   **Time on Task**: A user can mark an item as returned in under 5 seconds from opening the app.
-   **User Satisfaction**: The app achieves an average rating of 4.5 stars or higher in app stores after the first 1,000 reviews.
-   **Adoption**: The optional "contact picker" feature is used by at least 30% of users when adding a new item.

## 6. Key Entities

-   **Item**:
    -   `id`: Unique Identifier
    -   `name`: String
    -   `photo_url`: String (local path)
    -   `borrower_name`: String
    -   `borrower_contact_id`: String (optional)
    -   `borrow_date`: Date
    -   `return_date`: Date (optional)
    -   `status`: Enum (e.g., 'borrowed', 'returned')
    -   `notes`: String (optional)

## 7. Assumptions

-   Users are on mobile devices (iOS or Android) where contact and camera integration is possible.
-   For the initial version, data will be stored locally. Cloud sync is not in scope.
-   The "statistics" will be simple and based on the locally stored data.

## 8. Out of Scope

-   User accounts and authentication.
-   Cloud synchronization of data between multiple devices.
-   Social features or sharing.
-   Automated reminders or notifications for return dates. (This may be considered for a future version).
-   Web or desktop version of the application.
