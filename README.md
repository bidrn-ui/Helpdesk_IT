#Helpdesk IT Support - Tugas Akhir Pemrograman Mobile

Aplikasi ini adalah solusi manajemen tiket dukungan IT yang memungkinkan pengguna untuk melaporkan masalah teknis dan bagi teknisi untuk mengelola resolusi tiket tersebut.

📱 Fitur Utama Aplikasi

Sesuai dengan kriteria penilaian, aplikasi ini mencakup:

Autentikasi: Fitur Login dan Logout yang terintegrasi dengan Firebase Auth.
UI/UX Minimalis: Menggunakan AppBar dengan judul yang jelas, form input yang rapi dengan validasi, serta tombol logout yang mudah diakses.
Manajemen Data (CRUD): - Create: Menambah tiket keluhan baru.
Read: Menampilkan daftar tiket menggunakan ListView beserta halaman detail.
Update: Mengubah status atau informasi tiket.
Delete: Menghapus tiket yang sudah tidak relevan.
Query Database: Implementasi filter data menggunakan where, orderBy, atau limit pada koleksi Firestore.

🗄️ Struktur Database (Cloud Firestore)

Database menggunakan Firestore dengan struktur koleksi utama sebagai berikut:

Koleksi tickets (Data Keluhan):
title (string): Ticket Keluhan Kampus.
description (string): Detail masalah.
status (string): Status tiket (misal: Open, In Progress, Closed).
created_at (timestamp): Waktu pembuatan tiket (Server Timestamp).
user_email (string): Email pelapor.

🚀 Cara Menjalankan Project

Pastikan Flutter SDK sudah terinstal di perangkat Anda.
Clone repositori ini ke komputer lokal.
Jalankan perintah flutter pub get di terminal untuk mengunduh dependencies.
Hubungkan emulator atau perangkat fisik.
Jalankan aplikasi dengan perintah flutter run.

👤 Akun Demo Pengujian

Untuk keperluan penilaian oleh dosen/penguji, silakan gunakan akun berikut:

Role: Teknisi / Admin
Email: admin@projectf.com
Password: 87654321

Dibuat oleh Bagus Indrawan sebagai syarat pengumpulan Tugas UAS Pemrograman Mobile.