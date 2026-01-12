# MonoLog Testing Guide

Manual testing checklist for MonoLog features. Execute each test and verify expected behavior.

---

## 1. Notebook Management

### 1.1 Create Notebook
- [ ] Tap FAB (+) button on home screen
- [ ] Enter notebook name "Test Notebook"
- [ ] Select a color (e.g., red)
- [ ] Tap "Create"
- [ ] **Expected**: Notebook appears in the grid with correct name and color

### 1.2 Pin Notebook
- [ ] Long-press on a notebook
- [ ] Select "Pin"
- [ ] **Expected**: Notebook moves to "PINNED" section with pin icon

### 1.3 Edit Notebook
- [ ] Long-press on a notebook → "Edit"
- [ ] Change name and color
- [ ] Tap "Save"
- [ ] **Expected**: Changes reflected immediately

### 1.4 Archive Notebook
- [ ] Long-press on a notebook → "Archive"
- [ ] **Expected**: Notebook moves to collapsed "ARCHIVED" section
- [ ] Tap "ARCHIVED" to expand and verify notebook is there
- [ ] Long-press → "Unarchive" to restore

### 1.5 Delete Notebook (Soft Delete)
- [ ] Long-press on a notebook → "Delete"
- [ ] Confirm deletion
- [ ] **Expected**: Dialog says "moved to trash" not "permanently deleted"
- [ ] **Expected**: Notebook disappears from home screen

---

## 2. Entry Management

### 2.1 Create Text Entry
- [ ] Open a notebook
- [ ] Type "Hello World" in input bar
- [ ] Tap send button
- [ ] **Expected**: Entry appears with timestamp

### 2.2 Create Image Entry
- [ ] Tap camera icon in input bar
- [ ] Select an image from gallery
- [ ] Add optional caption "Photo caption"
- [ ] Tap send
- [ ] **Expected**: Entry shows image thumbnail and text

### 2.3 View Full-Screen Image
- [ ] Tap on an entry's image thumbnail
- [ ] **Expected**: Image opens in full-screen viewer with zoom/pan

### 2.4 Star Entry
- [ ] Long-press on an entry → "Add Star"
- [ ] **Expected**: Star icon appears on entry
- [ ] Long-press → "Remove Star"
- [ ] **Expected**: Star icon disappears

### 2.5 Edit Entry
- [ ] Tap on an entry to open edit screen
- [ ] Modify text content
- [ ] Tap save (checkmark)
- [ ] **Expected**: Changes saved and visible

### 2.6 Edit Entry Time (Separate Time/Date)
- [ ] Tap on an entry to edit
- [ ] Tap "Time" box → select new time only
- [ ] Tap "Date" box → select new date only
- [ ] Save
- [ ] **Expected**: Entry reorders based on new display time

### 2.7 Custom Time Before Sending
- [ ] In notebook, tap clock icon next to input field
- [ ] Select a time/date
- [ ] Type a message and send
- [ ] **Expected**: Entry has selected time, not current time

### 2.8 Delete Entry
- [ ] Long-press on entry → "Delete"
- [ ] **Expected**: Entry removed with "moved to trash" message

### 2.9 Move Entry to Another Notebook
- [ ] Long-press on entry → "Move to..."
- [ ] Select a different notebook
- [ ] **Expected**: Entry moved, confirmation shown

---

## 3. Timestamp Display

### 3.1 All Entries Show Time
- [ ] Create multiple entries
- [ ] **Expected**: EVERY entry shows its timestamp

---

## 4. Entry Color Tint

### 4.1 Notebook Color on Entries
- [ ] Create a notebook with a distinctive color (e.g., orange)
- [ ] Add entries
- [ ] **Expected**: Entry bubbles have subtle color tint matching notebook

---

## 5. Trash Functionality

### 5.1 View Trash
- [ ] Go to Settings → Trash
- [ ] **Expected**: See "Notebooks" and "Entries" sections if items deleted

### 5.2 Restore Notebook from Trash
- [ ] In trash, find a deleted notebook
- [ ] Tap restore icon or swipe right
- [ ] Go back to home screen
- [ ] **Expected**: Notebook appears in home screen immediately (no restart needed)

### 5.3 Restore Entry from Trash
- [ ] In trash, find a deleted entry
- [ ] Tap restore icon
- [ ] Open original notebook
- [ ] **Expected**: Entry is back in notebook

### 5.4 Permanently Delete
- [ ] In trash, tap delete forever icon on an item
- [ ] Confirm deletion
- [ ] **Expected**: Item removed permanently

### 5.5 Empty Trash
- [ ] Tap trash can icon in app bar (when trash has items)
- [ ] Confirm "Empty Trash"
- [ ] **Expected**: All items permanently deleted

---

## 6. Search

### 6.1 Global Search
- [ ] On home screen, tap search icon
- [ ] Type a word that exists in an entry
- [ ] **Expected**: Results from all notebooks appear
- [ ] **Expected**: Search term highlighted

### 6.2 Local Search (Within Notebook)
- [ ] Open a notebook
- [ ] Tap search icon in header
- [ ] Type search term
- [ ] **Expected**: Only entries from current notebook shown

### 6.3 Search Result Navigation
- [ ] From global search, tap a result
- [ ] **Expected**: Navigate to entry in its notebook

---

## 7. Jump to Date

- [ ] Open a notebook with entries on multiple days
- [ ] Tap calendar icon
- [ ] Select a date that has entries
- [ ] **Expected**: View scrolls to that date's entries
- [ ] Select a date with no entries
- [ ] **Expected**: Message shows "no entries" or jumps to nearest

---

## 8. Export/Import

### 8.1 Export All Data
- [ ] Go to Settings → Export All Data
- [ ] **Expected**: Share sheet appears with ZIP file
- [ ] Save/share the file
- [ ] **Expected**: ZIP contains data.json and images folder

### 8.2 Image Naming in Export
- [ ] Export data with images
- [ ] Open ZIP and check images folder
- [ ] **Expected**: Images named as NotebookName_Date_Time.ext

### 8.3 Import Data
- [ ] Go to Settings → Import Data
- [ ] Select a valid backup ZIP
- [ ] Choose "Merge" or "Replace"
- [ ] **Expected**: Data restored correctly

---

## 9. Theme

### 9.1 Toggle Dark Mode
- [ ] Go to Settings
- [ ] Toggle theme switch
- [ ] **Expected**: App switches between light/dark mode
- [ ] Restart app
- [ ] **Expected**: Theme preference persisted

---

## 10. App Identity

### 10.1 App Name
- [ ] Check app drawer/launcher
- [ ] **Expected**: App name shows as "MonoLog" (capital M and L)

### 10.2 App Title in Header
- [ ] On home screen
- [ ] **Expected**: Title shows "MonoLog"

---

## 11. Time-Based Visual Grouping

- [ ] Create entries with different time gaps:
  - Two entries within 2 minutes
  - Wait 10 minutes, add another entry
  - Wait 1 hour, add another entry
  - Wait until next day, add entry
- [ ] **Expected**: 
  - Close entries have minimal spacing
  - Entries 5-30 min apart show timestamp
  - Entries 2+ hours apart have larger gap
  - New day has bold date header

---

## 12. Data Persistence

- [ ] Add notebooks and entries
- [ ] Kill the app completely
- [ ] Reopen app
- [ ] **Expected**: All data still present

---

## Test Results

| Feature | Status | Notes |
|---------|--------|-------|
| Create Notebook | ⬜ | |
| Pin/Unpin Notebook | ⬜ | |
| Archive Notebook | ⬜ | |
| Delete Notebook to Trash | ⬜ | |
| Create Text Entry | ⬜ | |
| Create Image Entry | ⬜ | |
| Star Entry | ⬜ | |
| Edit Entry | ⬜ | |
| Edit Time/Date | ⬜ | |
| Custom Time Entry | ⬜ | |
| Move Entry | ⬜ | |
| Trash Restore | ⬜ | |
| Global Search | ⬜ | |
| Local Search | ⬜ | |
| Jump to Date | ⬜ | |
| Export | ⬜ | |
| Import | ⬜ | |
| Theme Toggle | ⬜ | |
| App Name Correct | ⬜ | |
| Entry Colors | ⬜ | |
| All Timestamps Shown | ⬜ | |

---

**Legend**: ⬜ Not tested | ✅ Pass | ❌ Fail
