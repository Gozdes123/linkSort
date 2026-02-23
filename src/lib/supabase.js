import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: {
        // ⚠️ 重要：關閉 Supabase 自動偵測 URL 中的 auth code
        // 原因：LINE LIFF 跳轉回頁面時，URL 會帶有 LINE 的 OAuth code=... 參數
        // Supabase SDK 看到 code 參數會誤以為是自己的 PKCE flow 並嘗試交換 token，
        // 導致「code_verifier does not match」錯誤
        // 我們的 auth 是透過 verifyOtp(token_hash) 手動完成的，不需要 Supabase 自動偵測
        detectSessionInUrl: false,
    },
})
