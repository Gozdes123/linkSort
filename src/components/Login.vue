<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../lib/supabase'

const LIFF_ID = import.meta.env.VITE_LIFF_ID
const EDGE_FUNCTION_URL = import.meta.env.VITE_SUPABASE_EDGE_FUNCTION_URL
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY

/**
 * phase 說明:
 *  'idle'       → 顯示「使用 LINE 登入」按鈕
 *  'completing' → 正在向後端驗證（轉圈狀態）
 *  'error'      → 發生錯誤
 */
const phase = ref('idle')
const errorMsg = ref('')
const statusMsg = ref('驗證身份中，請稍候…')

// 用來避免 liff.init() 重複呼叫的 Promise 快取
let liffReadyPromise = null

const getLiff = async () => {
  if (!liffReadyPromise) {
    liffReadyPromise = (async () => {
      const liff = (await import('@line/liff')).default
      await liff.init({ liffId: LIFF_ID })
      return liff
    })()
  }
  return liffReadyPromise
}

/** 已取得 LIFF token，向後端換 Supabase session */
const completeAuth = async (liff) => {
  phase.value = 'completing'
  statusMsg.value = '驗證身份中，請稍候…'

  try {
    const accessToken = liff.getAccessToken()
    if (!accessToken) {
      console.warn('[LIFF] accessToken 為空，清除 LIFF 狀態')
      liff.logout()
      liffReadyPromise = null
      phase.value = 'idle'
      return
    }

    const res = await fetch(EDGE_FUNCTION_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      },
      body: JSON.stringify({ access_token: accessToken }),
    })

    const result = await res.json()
    if (!res.ok) throw new Error(result.error || '伺服器驗證失敗')

    statusMsg.value = '登入成功，正在載入…'
    const { error: authError } = await supabase.auth.verifyOtp({
      token_hash: result.token_hash,
      type: 'email',
    })

    if (authError) {
      liff.logout()
      liffReadyPromise = null
      throw new Error('登入驗證失敗：' + authError.message)
    }

    // 成功！App.vue 的 onAuthStateChange 會切換到 Dashboard

  } catch (e) {
    console.error('[LIFF Login Error]', e)
    phase.value = 'error'
    errorMsg.value = e.message || '發生未知錯誤，請重試'
  }
}

/** onMounted 時執行：判斷是「剛登出」還是「從 LINE 回來」*/
const initAndCheck = async () => {
  // ⚠️ 第一步：同步讀取旗標，這是最高優先順序的判斷
  // 必須在所有 async 操作之前，確保「登出後顯示按鈕」的邏輯不被任何 LIFF 操作覆蓋
  const justLoggedOut = sessionStorage.getItem('liff_just_logged_out') === 'true'

  if (justLoggedOut) {
    // 清除旗標，顯示登入按鈕，完全不觸碰 LIFF
    // LIFF token 讓它自然留在 localStorage，不主動 logout
    // （反正按鈕點下去時會重新 init，isLoggedIn() = true 的話直接完成 auth 也 ok）
    sessionStorage.removeItem('liff_just_logged_out')
    // phase 維持 'idle' → 顯示登入按鈕，等使用者手動點
    return
  }

  // 沒有登出旗標，才進行 LIFF 初始化與自動登入判斷
  try {
    const liff = await getLiff()
    console.log('[LIFF] isLoggedIn:', liff.isLoggedIn())

    if (liff.isLoggedIn()) {
      // LIFF 已登入 = 使用者從 LINE OAuth 跳回來了，自動完成 Supabase 認證
      await completeAuth(liff)
    }
    // 若 LIFF 不是登入狀態，phase 維持 'idle' → 顯示登入按鈕
  } catch (e) {
    console.error('[LIFF] 初始化失敗:', e)
    liffReadyPromise = null
    // 初始化失敗不顯示錯誤，讓使用者自己點按鈕重試
    // phase 維持 'idle'
  }
}

/** 使用者手動點擊「使用 LINE 登入」按鈕 */
const startLineLogin = async () => {
  try {
    const liff = await getLiff()

    if (liff.isLoggedIn()) {
      // 若 LIFF 恰好已登入（LIFF token 還在），直接完成
      await completeAuth(liff)
    } else {
      // 跳轉到 LINE OAuth，授權後會帶著 code 回來，initAndCheck 會自動完成
      liff.login()
    }
  } catch (e) {
    console.error('[LIFF] startLineLogin 錯誤:', e)
    liffReadyPromise = null
    phase.value = 'error'
    errorMsg.value = e.message || '無法啟動 LINE 登入，請重試'
  }
}

onMounted(initAndCheck)
</script>

<template>
  <div class="liff-login-page">
    <div class="login-card glass-panel">

      <!-- Logo -->
      <div class="brand">
        <div class="logo-wrap">🔗</div>
        <h1>LinkSort</h1>
        <p>你的個人連結收藏庫</p>
      </div>

      <!-- ① 閒置狀態：顯示登入按鈕 -->
      <div v-if="phase === 'idle'" class="action-area">
        <p class="hint-text">使用您的 LINE 帳號快速登入</p>
        <button class="line-login-btn" @click="startLineLogin">
          <span class="line-icon">
            <svg viewBox="0 0 24 24" fill="currentColor" width="22" height="22">
              <path
                d="M19.365 9.863c.349 0 .63.285.63.631 0 .345-.281.63-.63.63H17.61v1.125h1.755c.349 0 .63.283.63.63 0 .344-.281.629-.63.629h-2.386c-.345 0-.627-.285-.627-.629V8.108c0-.345.282-.63.63-.63h2.386c.346 0 .627.285.627.63 0 .349-.281.63-.627.63H17.61v1.125h1.755zm-3.855 3.016c0 .27-.174.51-.432.596-.064.021-.133.031-.199.031-.211 0-.391-.09-.51-.25l-2.443-3.317v2.94c0 .344-.279.629-.631.629-.346 0-.626-.285-.626-.629V8.108c0-.27.173-.51.43-.595.06-.023.136-.033.194-.033.195 0 .375.104.495.254l2.462 3.33V8.108c0-.345.282-.63.63-.63.345 0 .63.285.63.63v4.771zm-5.741 0c0 .344-.282.629-.631.629-.345 0-.627-.285-.627-.629V8.108c0-.345.282-.63.627-.63.349 0 .631.285.631.63v4.771zm-2.466.629H4.917c-.345 0-.63-.285-.63-.629V8.108c0-.345.285-.63.63-.63.348 0 .63.285.63.63v4.141h1.756c.348 0 .629.283.629.63 0 .344-.281.629-.629.629M24 10.314C24 4.943 18.615.572 12 .572S0 4.943 0 10.314c0 4.811 4.27 8.842 10.035 9.608.391.082.923.258 1.058.59.12.301.079.766.038 1.08l-.164 1.02c-.045.301-.24 1.186 1.049.645 1.291-.539 6.916-4.078 9.436-6.975C23.176 14.393 24 12.458 24 10.314" />
            </svg>
          </span>
          使用 LINE 登入
        </button>
      </div>

      <!-- ② 驗證中 -->
      <div v-else-if="phase === 'completing'" class="status-area">
        <div class="spinner-ring"></div>
        <p class="status-text">{{ statusMsg }}</p>
      </div>

      <!-- ③ 錯誤狀態 -->
      <div v-else class="error-area">
        <div class="error-icon">⚠️</div>
        <p class="error-text">{{ errorMsg }}</p>
        <button class="line-login-btn" @click="startLineLogin">
          <span class="line-icon">
            <svg viewBox="0 0 24 24" fill="currentColor" width="22" height="22">
              <path
                d="M19.365 9.863c.349 0 .63.285.63.631 0 .345-.281.63-.63.63H17.61v1.125h1.755c.349 0 .63.283.63.63 0 .344-.281.629-.63.629h-2.386c-.345 0-.627-.285-.627-.629V8.108c0-.345.282-.63.63-.63h2.386c.346 0 .627.285.627.63 0 .349-.281.63-.627.63H17.61v1.125h1.755zm-3.855 3.016c0 .27-.174.51-.432.596-.064.021-.133.031-.199.031-.211 0-.391-.09-.51-.25l-2.443-3.317v2.94c0 .344-.279.629-.631.629-.346 0-.626-.285-.626-.629V8.108c0-.27.173-.51.43-.595.06-.023.136-.033.194-.033.195 0 .375.104.495.254l2.462 3.33V8.108c0-.345.282-.63.63-.63.345 0 .63.285.63.63v4.771zm-5.741 0c0 .344-.282.629-.631.629-.345 0-.627-.285-.627-.629V8.108c0-.345.282-.63.627-.63.349 0 .631.285.631.63v4.771zm-2.466.629H4.917c-.345 0-.63-.285-.63-.629V8.108c0-.345.285-.63.63-.63.348 0 .63.285.63.63v4.141h1.756c.348 0 .629.283.629.63 0 .344-.281.629-.629.629M24 10.314C24 4.943 18.615.572 12 .572S0 4.943 0 10.314c0 4.811 4.27 8.842 10.035 9.608.391.082.923.258 1.058.59.12.301.079.766.038 1.08l-.164 1.02c-.045.301-.24 1.186 1.049.645 1.291-.539 6.916-4.078 9.436-6.975C23.176 14.393 24 12.458 24 10.314" />
            </svg>
          </span>
          重新使用 LINE 登入
        </button>
      </div>

    </div>
  </div>
</template>

<style scoped>
.liff-login-page {
  width: 100%;
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1.5rem;
  box-sizing: border-box;
}

.login-card {
  width: 100%;
  max-width: 380px;
  padding: 2.5rem 2rem;
  border-radius: 28px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2rem;
}

/* ── Brand ── */
.brand {
  text-align: center;
}

.logo-wrap {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 68px;
  height: 68px;
  font-size: 1.85rem;
  border-radius: 20px;
  background: linear-gradient(135deg, var(--accent-glow), var(--accent-hover));
  margin-bottom: 1rem;
  box-shadow: 0 4px 24px rgba(99, 102, 241, 0.4);
}

.brand h1 {
  font-size: 2rem;
  font-weight: 700;
  letter-spacing: -1px;
  margin: 0 0 0.35rem;
}

.brand p {
  font-size: 0.9rem;
  color: var(--text-secondary);
  margin: 0;
}

/* ── 登入按鈕區域 ── */
.action-area {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  width: 100%;
}

.hint-text {
  font-size: 0.875rem;
  color: var(--text-secondary);
  margin: 0;
  text-align: center;
  opacity: 0.8;
}

/* ── 驗證中 ── */
.status-area {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  width: 100%;
}

.status-text {
  font-size: 0.9rem;
  color: var(--text-secondary);
  margin: 0;
  text-align: center;
}

/* ── Spinner ── */
.spinner-ring {
  width: 44px;
  height: 44px;
  border: 3px solid rgba(255, 255, 255, 0.1);
  border-top-color: var(--accent-color);
  border-radius: 50%;
  animation: spin 0.85s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

/* ── 錯誤 ── */
.error-area {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.9rem;
  width: 100%;
}

.error-icon {
  font-size: 2rem;
}

.error-text {
  font-size: 0.875rem;
  color: #fca5a5;
  text-align: center;
  margin: 0;
  background: rgba(239, 68, 68, 0.1);
  border: 1px solid rgba(239, 68, 68, 0.25);
  padding: 0.65rem 1rem;
  border-radius: 10px;
  line-height: 1.5;
  width: 100%;
  box-sizing: border-box;
}

/* ── LINE 登入按鈕 ── */
.line-login-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.65rem;
  width: 100%;
  padding: 0.95rem 1.25rem;
  background: #06C755;
  color: #fff;
  border: none;
  border-radius: 12px;
  font-size: 1rem;
  font-weight: 600;
  font-family: inherit;
  cursor: pointer;
  transition: all 0.2s ease;
  box-shadow: 0 4px 16px rgba(6, 199, 85, 0.35);
}

.line-login-btn:hover {
  background: #05b34c;
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(6, 199, 85, 0.45);
}

.line-login-btn:active {
  transform: translateY(0);
}

.line-icon {
  display: inline-flex;
  align-items: center;
}
</style>
