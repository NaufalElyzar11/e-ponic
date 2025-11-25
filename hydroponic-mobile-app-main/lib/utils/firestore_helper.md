# Cara Membuat Akun Super Admin di Firestore

## Masalah
Error "Akun tidak terdaftar sebagai karyawan" terjadi karena dokumen di Firestore tidak ditemukan dengan UID yang sesuai.

## Solusi

### Langkah 1: Buat Akun di Firebase Auth
1. Buka Firebase Console
2. Masuk ke Authentication > Users
3. Tambahkan user baru dengan email "dosen@gmail.com"
4. **Catat UID yang dihasilkan** (contoh: `abc123xyz456...`)

### Langkah 2: Buat Dokumen di Firestore
1. Buka Firebase Console > Firestore Database
2. Pilih collection `pengguna`
3. Klik "Add document"
4. **PENTING**: Di bagian "Document ID", pilih "Custom ID" dan masukkan **UID yang sama** dari Firebase Auth (dari Langkah 1)
5. Tambahkan fields berikut:
   - `email` (string): "dosen@gmail.com"
   - `nama_pengguna` (string): "dosen"
   - `posisi` (string): "Super Admin"
   - `created_at` (timestamp): Server timestamp

### Catatan Penting
- **Document ID HARUS sama dengan UID dari Firebase Auth**
- Jika document ID berbeda, login akan gagal dengan error "Akun tidak terdaftar sebagai karyawan"
- UID dari Firebase Auth bisa dilihat di Authentication > Users setelah membuat akun

