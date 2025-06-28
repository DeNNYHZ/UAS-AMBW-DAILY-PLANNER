# Daily Planner

Aplikasi Flutter untuk daily planner dengan autentikasi dan penyimpanan data menggunakan Supabase.

## Fitur
- **Login & Register** (Supabase Auth)
- **Onboarding (Get Started) screen** (hanya muncul sekali saat instalasi pertama)
- **Profile** (Custom foto profile, gravatar)
- **Manajemen Task** (CRUD, kategori custom, prioritas, filter/search, swipe to complete/delete)
- **Kategori Custom** (per user)
- **Prioritas Task** (tinggi/sedang/rendah, warna/icon)
- **Offline Mode** (Hive, sync otomatis saat online)
- **Theme Toggle** (dark/light)
- **Modern UI/UX** (Google Fonts, glassmorphism, animasi, snackbar, empty state SVG)
- **Snackbar Feedback** (aksi task, kategori)
- **Validasi Form** (judul task, email format valid, password minimal 6 karakter)

## Dummy User untuk Uji Aplikasi

|          Email            |     Password     |
|---------------------------|------------------|
| iamdenisetiawan@gmail.com |     Rahasia98    |

## Tested on
- **API Level:** 34
- **Android Version:** 14.0
- **Device:** Android Emulator

## Setup Aplikasi
1. **Buat project di [Supabase](https://supabase.com/)**

2. **Buat tabel `tasks` dengan struktur:**
   - `id` (uuid, primary key, default: uuid_generate_v4())
   - `user_id` (uuid, foreign key ke `auth.users.id`)
   - `title` (text)
   - `description` (text)
   - `date` (date)
   - `is_done` (boolean)

   SQL untuk membuat tabel:
   ```sql
   create table todos (
   id uuid primary key,
   user_id uuid references auth.users(id) on delete cascade,
   title text not null,
   description text,
   date timestamptz not null,
   is_done boolean not null default false,
   category text not null,
   priority text not null default 'Sedang',
   synced boolean not null default true
   );
   ```

1. **Clone repo**
   ```bash
   git clone https://github.com/DeNNYHZ/UAS-AMBW-DAILY-PLANNER.git
   cd uas_daily_planner
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. ## Menjalankan Aplikasi
	1. Jalankan perintah berikut:
	   ```
	   flutter run --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL --dart-define=SUPABASE_KEY=YOUR_SUPABASE_ANON_KEY
	   ```
	

## Teknologi yang Digunakan
- **Flutter** (UI utama)
- **Supabase** (Auth, Database, Storage)
- **Hive** (offline storage, cache)
- **home_widget** (widget Android)
- **connectivity_plus** (cek status online/offline)
- **google_fonts** (font modern)
- **flutter_svg** (SVG asset)
- **uni_links** (deep link)
- **crypto** (hash Gravatar)