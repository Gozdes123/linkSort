-- 請再次到 Supabase 的 "SQL Editor" 去貼上並執行這段程式碼

-- 在既有的 links 資料表中，新增一個「自訂子分類 (custom_category)」的欄位
ALTER TABLE public.links 
ADD COLUMN custom_category text DEFAULT '未分類';
