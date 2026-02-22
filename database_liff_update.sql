-- 在 Supabase SQL Editor 執行此檔案
-- 目的：讓 user_profiles 支援 LIFF 登入後儲存 LINE 顯示名稱和頭像

-- 若 user_profiles 表不存在，先建立（含所有欄位）
create table if not exists public.user_profiles (
  id   uuid primary key references auth.users on delete cascade,
  line_id      text unique,
  display_name text,
  avatar_url   text,
  created_at   timestamp with time zone default timezone('utc', now())
);

-- 若表已存在，只新增缺少的欄位（執行若已有欄位會安全略過）
alter table public.user_profiles
  add column if not exists display_name text,
  add column if not exists avatar_url   text;

-- 啟用 RLS
alter table public.user_profiles enable row level security;

-- 讓使用者只能讀取自己的 profile
create policy if not exists "Users can read own profile"
  on public.user_profiles for select
  using (auth.uid() = id);

-- Edge Function（Service Role Key）可以寫入任何 row
-- （Service Role Key 會繞過 RLS，所以不需要另外開放 insert policy）
