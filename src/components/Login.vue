<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../lib/supabase'

const LIFF_ID = '2009194598-nEng9eZX'
const EDGE_FUNCTION_URL = 'https://vnzolmsjftcqcyrvhall.supabase.co/functions/v1/liff-auth'
const SUPABASE_ANON_KEY = 'sb_publishable_SaLhF_xj1c4SLl1S3ww-Ag_9odbsPho'

const phase = ref('init')   // 'init' | 'logging-in' | 'error'
const errorMsg = ref('')
const statusMsg = ref('正在啟動 LINE 登入…')

const login = async () => {
  try {
    // ── 1. 動態載入並初始化 LIFF SDK ──────────────────────────────────
    phase.value = 'init'
    statusMsg.value = '正在初始化 LINE…'

    const liff = (await import('@line/liff')).default
    await liff.init({ liffId: LIFF_ID })

    console.log('[LIFF] isLoggedIn:', liff.isLoggedIn())
    console.log('[LIFF] isInClient:', liff.isInClient())

    // ── 2. 尚未登入 → 觸發 LINE OAuth 跳轉 ───────────────────────────
    if (!liff.isLoggedIn()) {
      statusMsg.value = '正在跳轉至 LINE 登入…'
      liff.login()
      return  // 頁面會跳轉，不需繼續
    }

    // ── 3. 已登入 → 取得 Access Token 並呼叫 Edge Function ──────────
    phase.value = 'logging-in'
    statusMsg.value = '驗證身份中，請稍候…'

    const accessToken = liff.getAccessToken()
    console.log('[LIFF] accessToken:', accessToken ? '已取得（長度:' + accessToken.length + '）' : 'null')

    // accessToken 為 null 代表 LIFF Session 不完整，強制重新登入
    if (!accessToken) {
      console.warn('[LIFF] Access Token 為空，重新執行 login()')
      liff.logout()
      await new Promise(r => setTimeout(r, 500))
      liff.login()
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

    if (!res.ok) {
      throw new Error(result.error || '伺服器驗證失敗')
    }

    // ── 4. 用 token_hash 完成 Supabase 登入 ──────────────────────────
    statusMsg.value = '登入完成，正在載入…'
    const { error: authError } = await supabase.auth.verifyOtp({
      token_hash: result.token_hash,
      type: 'email',
    })

    if (authError) throw new Error('登入失敗：' + authError.message)

    // 成功！App.vue 的 onAuthStateChange 會自動切換至 Dashboard

  } catch (e) {
    console.error('[LIFF Login Error]', e)
    phase.value = 'error'
    errorMsg.value = e.message || '發生未知錯誤，請重試'
  }
}

onMounted(login)
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

      <!-- 載入中 / 跳轉中 -->
      <div v-if="phase !== 'error'" class="status-area">
        <div class="spinner-ring"></div>
        <p class="status-text">{{ statusMsg }}</p>
      </div>

      <!-- 錯誤狀態 -->
      <div v-else class="error-area">
        <div class="error-icon">⚠️</div>
        <p class="error-text">{{ errorMsg }}</p>
        <button class="retry-btn" @click="login">
          <span class="line-icon">
            <svg viewBox="0 0 24 24" fill="currentColor" width="20" height="20">
              <path d="M19.365 9.863c.349 0 .63.285.63.631 0 .345-.281.63-.63.63H17.61v1.125h1.755c.349 0 .63.283.63.63 0 .344-.281.629-.63.629h-2.386c-.345 0-.627-.285-.627-.629V8.108c0-.345.282-.63.63-.63h2.386c.346 0 .627.285.627.63 0 .349-.281.63-.627.63H17.61v1.125h1.755zm-3.855 3.016c0 .27-.174.51-.432.596-.064.021-.133.031-.199.031-.211 0-.391-.09-.51-.25l-2.443-3.317v2.94c0 .344-.279.629-.631.629-.346 0-.626-.285-.626-.629V8.108c0-.27.173-.51.43-.595.06-.023.136-.033.194-.033.195 0 .375.104.495.254l2.462 3.33V8.108c0-.345.282-.63.63-.63.345 0 .63.285.63.63v4.771zm-5.741 0c0 .344-.282.629-.631.629-.345 0-.627-.285-.627-.629V8.108c0-.345.282-.63.627-.63.349 0 .631.285.631.63v4.771zm-2.466.629H4.917c-.345 0-.63-.285-.63-.629V8.108c0-.345.285-.63.63-.63.348 0 .63.285.63.63v4.141h1.756c.348 0 .629.283.629.63 0 .344-.281.629-.629.629M24 10.314C24 4.943 18.615.572 12 .572S0 4.943 0 10.314c0 4.811 4.27 8.842 10.035 9.608.391.082.923.258 1.058.59.12.301.079.766.038 1.08l-.164 1.02c-.045.301-.24 1.186 1.049.645 1.291-.539 6.916-4.078 9.436-6.975C23.176 14.393 24 12.458 24 10.314"/>
            </svg>
          </span>
          使用 LINE 重新登入
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

/* ── Status ── */
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
  to { transform: rotate(360deg); }
}

/* ── Error ── */
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

/* ── LINE 按鈕 ── */
.retry-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.6rem;
  width: 100%;
  padding: 0.9rem 1.25rem;
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

.retry-btn:hover {
  background: #05b34c;
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(6, 199, 85, 0.45);
}

.retry-btn:active {
  transform: translateY(0);
}

.line-icon {
  display: inline-flex;
  align-items: center;
}
</style>
