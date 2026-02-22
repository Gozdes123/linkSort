-- 在 Supabase SQL Editor 執行此檔案
-- 目的：建立使用者的自訂分類表，以便跨裝置同步

-- 1. 建立自訂分類資料表
create table if not exists public.custom_categories (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  name text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  -- 確保同一個使用者不會有兩個同樣名稱的分類
  unique(user_id, name)
);

-- 2. 啟用 Row Level Security (RLS)
alter table public.custom_categories enable row level security;

-- 3. 建立安全規則 (Policies)：只能對自己的分類進行操作
create policy "Users can view their own categories" on public.custom_categories
  for select using (auth.uid() = user_id);

create policy "Users can insert their own categories" on public.custom_categories
  for insert with check (auth.uid() = user_id);

create policy "Users can update their own categories" on public.custom_categories
  for update using (auth.uid() = user_id);

create policy "Users can delete their own categories" on public.custom_categories
  for delete using (auth.uid() = user_id);
