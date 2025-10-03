# 🎓 College Mate

A focused study companion for college students — built with **SwiftUI**, **SwiftData**, and native Apple frameworks. Track attendance with the 75% rule in mind, keep subject‑wise notes (PDFs & images), and manage your weekly timetable — all in a clean, fast, and delightful interface.

---

## ✨ Highlights

- 📚 Subject management with an intuitive, card‑based UI
- ✅ Attendance tracking designed around the 75% requirement
- 🖼️ Notes that accept PDFs and images (from Photos or Files)
- 🗓️ Simple timetable view for your weekly schedule
- ⚡️ Fast, minimal design focused on what matters

> Personal project turned daily essential — made by a student for students.

---

## 🧠 Why I Built This

Two everyday pain points inspired College Mate:

1. Checking attendance was slow and frustrating — yet essential to meet the 75% rule.
2. Important study notes (screenshots/PDFs) got buried among unrelated photos.

College Mate solves this by:
- Providing a fast, clean UI to track attendance per subject
- Storing only subject‑relevant images and PDFs
- Keeping everything organized in a beautiful, distraction‑free layout

---

## 📸 Screenshots

### 🏠 Home Screen

<img width="220" alt="Home 1" src="https://github.com/user-attachments/assets/1f3ed9b1-95dc-40fe-8b08-4d543391c423" />
<img width="220" alt="Home 2" src="https://github.com/user-attachments/assets/0905c3de-16d6-4518-a2dd-b3a07dfa2a09" />
<img width="220" alt="Home 3" src="https://github.com/user-attachments/assets/817b382c-0e19-412e-a2b3-b65f6221d133" />

### 📝 Daily Log View

<img width="220" alt="Daily 1" src="https://github.com/user-attachments/assets/2b08ae20-db82-4013-b5fc-cda13bb8e35d" />
<img width="220" alt="Daily 2" src="https://github.com/user-attachments/assets/0fc049ca-626c-4c72-9b61-9efc13d01f8a" />
<img width="220" alt="Daily 3" src="https://github.com/user-attachments/assets/6676ecd8-b88c-448e-a8e3-95144bb88d8b" />
<img width="220" alt="Daily 4" src="https://github.com/user-attachments/assets/8903ce90-3e00-44a6-9880-bcc32c483728" />

### 📅 Timetable View

<img width="220" alt="Timetable" src="https://github.com/user-attachments/assets/228f53b0-2e11-43ce-8fa9-16e47f577bfd" />

### 👤 Profile & Attendance History

<img width="220" alt="Profile 1" src="https://github.com/user-attachments/assets/ad3a7cc1-3cf3-4b82-bd1c-268fff094dde" />
<img width="220" alt="Profile 2" src="https://github.com/user-attachments/assets/c38cfe97-9d0a-4e29-99c2-5c99cc634f42" />
<img width="220" alt="Profile 3" src="https://github.com/user-attachments/assets/60c9800c-2d33-4a6b-ba2b-3288e75a633a" />
<img width="220" alt="Profile 4" src="https://github.com/user-attachments/assets/815da267-ece6-411b-8f1c-11a922d28ca1" />

### 📝 Notes View

<img width="220" alt="Notes 1" src="https://github.com/user-attachments/assets/fec7fe26-7599-4ae3-afe7-9fdf7a112785" />
<img width="220" alt="Notes 2" src="https://github.com/user-attachments/assets/0aac4e16-a1d4-457a-80df-c9bd91655d9b" />
<img width="220" alt="Notes 3" src="https://github.com/user-attachments/assets/fafb7d9f-cbec-4846-9bb2-5297fc26c2f2" />
<img width="220" alt="Notes 4" src="https://github.com/user-attachments/assets/606eb314-7f3d-42c2-aa9f-c90128326491" />

---

## 🎥 Demo

- iPhone Simulator (full demo except Notes view):
  - 🔗 https://github.com/user-attachments/assets/c2967243-07c9-4cc7-98ca-bd228efafa66
- iPhone 15 (Notes view only):
  - 🔗 https://github.com/user-attachments/assets/f48304cc-0374-43d3-83c2-44b507310598

---

## 🧱 Tech Stack

- **SwiftUI** — Declarative UI
- **SwiftData** — Local persistence (CloudKit sync planned)
- **PDFKit** — Displaying PDFs
- **PhotosUI** — Image picking
- **UniformTypeIdentifiers (UTType)** — File type handling

> Targeting iOS 17+ (SwiftData). Built with Xcode 15+.

---

## 🔒 Data & Privacy

- Notes and attendance data are stored locally on‑device.
- Only subject‑relevant images/PDFs are imported (from Photos/Files with user consent).
- iCloud sync (Private Database) is planned for cross‑device access.
- No third‑party analytics.

---

## 🚀 Roadmap

- ☁️ iCloud sync across iPhone and iPad (SwiftData + CloudKit)
- 👤 Sign in with Apple (start trial after login)
- 💳 One‑time unlock after a 90‑day free period (StoreKit 2)
- 📥 WhatsApp auto‑import
- 📊 Weekly attendance analytics
- 🔔 Smart alerts for low attendance

If you have feature ideas, please open an issue or start a discussion!

---

## 🛠️ Getting Started

### Requirements
- iOS 17 or later
- Xcode 15 or later

### Build & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/<your-username>/college-mate.git
   cd college-mate
