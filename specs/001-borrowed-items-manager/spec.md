# Feature Specification: Borrowed items manager

**Feature Branch**: `001-borrowed-items-manager`
**Created**: 2025-10-21
**Status**: Draft
**Input**: User description: "Buat aplikasi manajemen barang yang pernah dipinjam. banyak orang lupa dengan barang yang pernah dia pinjamkan dan berujung pada hilangnya barang tersebut tanpa tau ke siapa barang tersebut pergi. dengan ini user bisa menyimpan, mengedit, dan menghapus barang yg dipinjam dan pernah dipinjam. user bisa menyimpan foto barang, nama barang, nama peminjam, dan mungkin kontak peminjam (opsional) integrasi dengan contact picker di mobile. tanggal kembali (opsional) bisa kosong atau ada tanggalnya, dan juga notes untuk mencatat hal penting mengenai kejadian, keputusan, ciri ciri barang, atau ciri ciri peminjam dan notes ini opsional juga. di homepage user bisa melihat list barang yg pernah dipinjam, dan hanya dengan sekali swipe saja pada widget yg disediakan maka barang sudah langsung dianggap selesai dipinjam."

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Quick mark returned (Priority: P1)

Sebagai pengguna, saya ingin melihat daftar barang yang pernah dipinjam pada halaman utama dan menandai sebuah barang sebagai "kembali" hanya dengan satu kali swipe, sehingga saya dapat menandai pengembalian dengan cepat tanpa navigasi tambahan.

**Why this priority**: Ini adalah fungsi inti aplikasi — menandai kembali mengurangi risiko kehilangan barang dan menyediakan nilai langsung.

**Independent Test**: Pada perangkat nyata atau emulator, buka homepage, lakukan swipe pada entri, dan verifikasi status berubah ke "kembali" dan item dipindahkan/ditandai sesuai desain.

**Acceptance Scenarios**:

1. **Given** daftar berisi item belum kembali, **When** pengguna men-swipe item ke arah yang disepakati, **Then** item ditandai sebagai "kembali" dan waktu pengembalian dicatat (opsional).
2. **Given** item sudah ditandai kembali, **When** pengguna melihat daftar, **Then** item ditampilkan di bagian history atau dengan label "kembali" sesuai desain.

---

### User Story 2 - Add / Edit / Delete item (Priority: P2)

Sebagai pengguna, saya ingin menambahkan barang baru yang dipinjam (dengan foto, nama barang, nama peminjam, dan optional kontak), mengubah informasi tersebut, dan menghapus entri sehingga data tetap akurat.

**Why this priority**: Menyimpan metadata barang adalah fungsi pembangun nilai; tanpa ini, daftar tidak berguna.

**Independent Test**: Tambah entri baru lengkap, tutup aplikasi, buka kembali, dan verifikasi data tersimpan; edit kolom lalu verifikasi update; hapus entri dan verifikasi penghapusan.

**Acceptance Scenarios**:

1. **Given** form penambahan barang, **When** pengguna mengisi nama barang, nama peminjam, (opsional) pilih kontak dari contact picker, (opsional) tambahkan foto dan notes lalu submit, **Then** entri baru muncul di daftar utama.
2. **Given** entri ada, **When** pengguna membuka layar edit dan mengubah informasi, **Then** perubahan disimpan dan tercermin di daftar.
3. **Given** entri ada, **When** pengguna memilih hapus dan mengonfirmasi, **Then** entri dihapus dari penyimpanan dan tidak muncul kembali.

---

### User Story 3 - History, Search & Filters (Priority: P3)

Sebagai pengguna, saya ingin melihat riwayat barang yang pernah dipinjam, mencari dan memfilter daftar berdasarkan nama barang, nama peminjam, atau status (dipinjam/kembali), sehingga saya dapat menemukan entri lama dengan mudah.

**Why this priority**: Berguna untuk manajemen jangka panjang dan menemukan data lama ketika diperlukan.

**Independent Test**: Tambah beberapa item dengan variasi data, gunakan pencarian dan filter, dan verifikasi hasil sesuai kriteria.

**Acceptance Scenarios**:

1. **Given** banyak entri, **When** pengguna mengetik kata kunci, **Then** daftar difilter dan menampilkan hanya entri yang cocok.

---

### Edge Cases

-   Item tanpa foto: form harus menerima entri tanpa foto.
-   Tanggal kembali kosong: entri boleh tidak memiliki tanggal kembali.
-   Kontak eksternal tidak tersedia: contact picker gagal atau pengguna menolak izin — pengguna masih dapat menyimpan nama peminjam sebagai teks biasa.
-   Duplikasi entri: jika pengguna menambahkan entri mirip, sistem tidak otomatis menggabungkan; deteksi duplikat adalah tambahan.

## Requirements _(mandatory)_

### Functional Requirements

-   **FR-001**: System MUST allow users to create a borrowed-item entry with fields: item name, borrower name, optional contact, optional return date, optional notes, and optional photo.
-   **FR-002**: System MUST persist entries locally so that data survives app restarts.
-   **FR-003**: System MUST allow users to edit existing entries and save changes.
-   **FR-004**: System MUST allow users to delete entries (with a confirmation step).
-   **FR-005**: System MUST allow marking an item as returned via a single swipe action on the list view.
-   **FR-006**: System SHOULD allow selecting a contact from the device contact picker (optional integration). If the contact picker is used, storing contact details MUST be optional and comply with user consent.
-   **FR-007**: System MUST provide a searchable and filterable list by item name, borrower name, and status.

_Notes on unclear scope and assumptions are recorded below._

### Key Entities _(include if feature involves data)_

-   **BorrowedItem**: id, item_name, borrower_name, photo_ref, contact_ref (optional), return_date (optional), notes (optional), status (borrowed/returned), created_at, returned_at
-   **Contact**: id (platform reference), display_name, phone/email (stored only with consent)
-   **Note**: free-form text attached to a BorrowedItem

## Success Criteria _(mandatory)_

### Measurable Outcomes

-   **SC-001**: 95% of users in a small usability test (N>=20) can mark an item as returned using a single swipe within their first session.
-   **SC-002**: A typical user can add a new borrowed item (including taking/attaching a photo) in under 60 seconds.
-   **SC-003**: Data persistence: items remain available after app restart for at least 1000 stored entries without data loss.
-   **SC-004**: Search/filter returns relevant results for queries of at least 3 characters with acceptable latency for a mobile device (perceived instant by user).
-   **SC-005**: Privacy: optional contact data can be removed by the user and is not transmitted off-device without explicit opt-in.

## Assumptions

-   The app WILL support multi-device sync and requires user authentication (account-based) to enable sync and cloud backup. (You requested auth + sync.)
-   Photo storage WILL use cloud storage (not local) as requested; ensure privacy and storage limits are defined in implementation.
-   Contact picker behavior: Android-only contact picker is supported. On Android, when a contact is selected the app WILL store contact details (display name and phone number) but ONLY with explicit user consent. On non-Android platforms, the UI MUST present a phone-number input field as fallback.

## Sync & Data Handling Decisions (resolved)

-   Sync model: Full sync with account-based authentication is REQUIRED. This implies server-side components, authentication flows, and a migration/backup plan. See new requirements FR-008 and FR-009.
-   Photo storage: Cloud-hosting for photos is REQUIRED. Photos uploaded by the user are backed up to cloud storage tied to the user's account.
-   Contact handling: Android contact picker integration is supported; saved contact details require explicit consent and a deletion UI.

---

### User Story 4 - Statistics & Insights (Priority: P3)

Sebagai pengguna, saya ingin melihat statistik ringkasan (mis. jumlah item dipinjam, jumlah item kembali, items per borrower, trending notes) sehingga saya dapat memahami pola peminjaman dan menemukan anomali.

**Why this priority**: Menambah nilai dengan memberikan wawasan; berguna untuk power users dan pencegahan kehilangan barang.

**Independent Test**: Setelah beberapa entri dibuat, buka layar Statistik dan verifikasi angka-angka agregat berjumlah benar sesuai data sumber.

**Acceptance Scenarios**:

1. **Given** dataset berisi entri, **When** pengguna membuka halaman Statistik, **Then** ditampilkan ringkasan jumlah total dipinjam, jumlah kembali, top borrowers, dan grafik sederhana per waktu.

---

## Additional Functional Requirements (new)

-   **FR-008**: System MUST support account-based authentication to enable cross-device sync.
-   **FR-009**: System MUST support cloud backup/sync of item data and photos tied to the user's account; sync operations MUST be opt-in per account and respect user privacy settings.
-   **FR-010**: System MUST provide a deletion UI for stored contact PII and obey user consent choices.

**End of spec**
