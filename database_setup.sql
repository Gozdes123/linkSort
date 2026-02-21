-- 請到 Supabase 後台的 "SQL Editor" 去貼上並執行這段程式碼

-- 1. 建立資料表 (Table)
create table public.links (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  url text not null,
  title text default '目前尚無標題（來自捷徑或手動加入）',
  category text default '未分類',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. 啟用 Row Level Security (RLS) 最關鍵的一步！確保資料安全
alter table public.links enable row level security;

-- 3. 建立安全規則 (Policies)：設定只能看到、新增、修改、刪除屬於自己的連結
create policy "Users can view their own links" on links
  for select using (auth.uid() = user_id);

create policy "Users can insert their own links" on links
  for insert with check (auth.uid() = user_id);

create policy "Users can update their own links" on links
  for update using (auth.uid() = user_id);

create policy "Users can delete their own links" on links
  for delete using (auth.uid() = user_id);
