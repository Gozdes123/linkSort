<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../lib/supabase'

const LIFF_ID = import.meta.env.VITE_LIFF_ID
const EDGE_FUNCTION_URL = import.meta.env.VITE_SUPABASE_EDGE_FUNCTION_URL
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY

const phase = ref('idle')
const errorMsg = ref('')
const statusMsg = ref('驗證身份中，請稍候…')
const isLocalHost = ref(false)

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

const completeAuth = async (liff) => {
  phase.value = 'completing'
  statusMsg.value = '🌸 正在驗證您的 LINE 身份，請稍候…'

  try {
    const accessToken = liff.getAccessToken()
    if (!accessToken) {
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

    statusMsg.value = '💖 登入成功！即將載入您的收藏庫…'
    const { error: authError } = await supabase.auth.verifyOtp({
      token_hash: result.token_hash,
      type: 'email',
    })

    if (authError) {
      liff.logout()
      liffReadyPromise = null
      throw new Error('登入驗證失敗：' + authError.message)
    }

  } catch (e) {
    console.error('[LIFF Login Error]', e)
    phase.value = 'error'
    errorMsg.value = e.message || '發生未知錯誤，請重試'
  }
}

const initAndCheck = async () => {
  isLocalHost.value = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'

  const justLoggedOut = sessionStorage.getItem('liff_just_logged_out') === 'true'
  if (justLoggedOut) {
    sessionStorage.removeItem('liff_just_logged_out')
    return
  }

  try {
    const liff = await getLiff()
    if (liff.isLoggedIn()) {
      await completeAuth(liff)
    }
  } catch (e) {
    liffReadyPromise = null
  }
}

const startLineLogin = async () => {
  try {
    const liff = await getLiff()
    if (liff.isLoggedIn()) {
      await completeAuth(liff)
    } else {
      liff.login({ redirectUri: window.location.href })
    }
  } catch (e) {
    liffReadyPromise = null
    phase.value = 'error'
    errorMsg.value = e.message || '無法啟動 LINE 登入，請重試'
  }
}

const enterDevPreview = () => {
  sessionStorage.setItem('linksort_dev_preview', 'true')
  window.location.reload()
}

const importSessionToken = async () => {
  const tokenInput = prompt(
    '🌸【同步正式站真實資料】\n請在正式站（已登入狀態）按 F12 開啟 Console 輸入：\ncopy(localStorage.getItem(Object.keys(localStorage).find(k=>k.startsWith("sb-")&&k.endsWith("-auth-token"))))\n\n並將複製的內容貼在下方：'
  )
  if (!tokenInput || !tokenInput.trim()) return

  try {
    const session = JSON.parse(tokenInput.trim())
    if (session.access_token && session.refresh_token) {
      const { error } = await supabase.auth.setSession({
        access_token: session.access_token,
        refresh_token: session.refresh_token,
      })
      if (error) throw error
      alert('💖 成功同步正式站登入狀態！即將進入本機可愛儀表板～')
      window.location.reload()
    } else {
      alert('❌ Token 格式不正確，缺少 access_token 或 refresh_token')
    }
  } catch (err) {
    alert('❌ 設定 Session 失敗：' + err.message)
  }
}

onMounted(initAndCheck)
</script>

<template>
  <div class="liff-login-page">
    <div class="login-card glass-panel">

      <!-- Logo -->
      <div class="brand">
        <div class="logo-wrap">🍄</div>
        <h1>LinkSort</h1>
        <p>8-BIT 像素超連結冒險收藏庫 ⭐</p>
      </div>

      <!-- ① 閒置狀態：顯示登入按鈕 -->
      <div v-if="phase === 'idle'" class="action-area">
        <p class="hint-text">點擊下方按鈕以 LINE 帳號登入 🎮</p>
        <button class="line-login-btn" @click="startLineLogin">
          <span class="line-icon">
            <svg viewBox="0 0 24 24" fill="currentColor" width="22" height="22">
              <path
                d="M19.365 9.863c.349 0 .63.285.63.631 0 .345-.281.63-.63.63H17.61v1.125h1.755c.349 0 .63.283.63.63 0 .344-.281.629-.63.629h-2.386c-.345 0-.627-.285-.627-.629V8.108c0-.345.282-.63.63-.63h2.386c.346 0 .627.285.627.63 0 .349-.281.63-.627.63H17.61v1.125h1.755zm-3.855 3.016c0 .27-.174.51-.432.596-.064.021-.133.031-.199.031-.211 0-.391-.09-.51-.25l-2.443-3.317v2.94c0 .344-.279.629-.631.629-.346 0-.626-.285-.626-.629V8.108c0-.27.173-.51.43-.595.06-.023.136-.033.194-.033.195 0 .375.104.495.254l2.462 3.33V8.108c0-.345.282-.63.63-.63.345 0 .63.285.63.63v4.771zm-5.741 0c0 .344-.282.629-.631.629-.345 0-.627-.285-.627-.629V8.108c0-.345.282-.63.627-.63.349 0 .631.285.631.63v4.771zm-2.466.629H4.917c-.345 0-.63-.285-.63-.629V8.108c0-.345.285-.63.63-.63.348 0 .63.285.63.63v4.141h1.756c.348 0 .629.283.629.63 0 .344-.281.629-.629.629M24 10.314C24 4.943 18.615.572 12 .572S0 4.943 0 10.314c0 4.811 4.27 8.842 10.035 9.608.391.082.923.258 1.058.59.12.301.079.766.038 1.08l-.164 1.02c-.045.301-.24 1.186 1.049.645 1.291-.539 6.916-4.078 9.436-6.975C23.176 14.393 24 12.458 24 10.314" />
            </svg>
          </span>
          使用 LINE 登入
        </button>

        <!-- 本機開發專用快速通道（只在 localhost 顯示） -->
        <div v-if="isLocalHost" class="dev-login-panel">
          <div class="dev-divider">
            <span>🍄 本機冒險者通道 🍄</span>
          </div>
          <p class="dev-hint">
            避免被 LINE 導回正式站，可直接於本機免登入預覽像素介面：
          </p>
          <div class="dev-buttons">
            <button class="dev-btn preview-btn" @click="enterDevPreview">
              ⭐ 免登入直接體驗 (含測試資料)
            </button>
            <button class="dev-btn sync-btn" @click="importSessionToken">
              📋 貼上正式站 Token 登入真實帳號
            </button>
          </div>
        </div>
      </div>

      <!-- ② 驗證中 -->
      <div v-else-if="phase === 'completing'" class="status-area">
        <div class="pixel-loader"></div>
        <p class="status-text">{{ statusMsg }}</p>
      </div>

      <!-- ③ 錯誤狀態 -->
      <div v-else class="error-area">
        <div class="error-icon">👾</div>
        <p class="error-text">{{ errorMsg }}</p>
        <button class="line-login-btn" @click="startLineLogin">
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
  max-width: 420px;
  padding: 2.5rem 2rem;
  border-radius: 4px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1.8rem;
  background: #202533;
  border: 4px solid #000000;
  box-shadow: 8px 8px 0px #000000;
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
  font-size: 2.2rem;
  border-radius: 4px;
  background: var(--mario-red);
  border: 3px solid #000000;
  box-shadow: 4px 4px 0px #000000;
  margin-bottom: 0.85rem;
  animation: marioJump 2s infinite ease-in-out;
}

@keyframes marioJump {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-8px); }
}

.brand h1 {
  font-size: 2.2rem;
  font-weight: 900;
  letter-spacing: 1px;
  margin: 0 0 0.35rem;
  color: var(--mario-red);
  text-shadow: 2px 2px 0px #fcd116, 3px 3px 0px #000000;
}

.brand p {
  font-size: 0.88rem;
  color: var(--text-secondary);
  margin: 0;
  font-weight: 700;
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
  font-size: 0.88rem;
  color: #cbd5e1;
  margin: 0;
  text-align: center;
  font-weight: 700;
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
  font-size: 0.92rem;
  color: var(--mario-yellow);
  margin: 0;
  text-align: center;
  font-weight: 700;
}

.pixel-loader {
  width: 36px;
  height: 36px;
  background: var(--mario-yellow);
  border: 3px solid #000000;
  box-shadow: 3px 3px 0px #000000;
  animation: pixelSpin 0.8s steps(4) infinite;
}

@keyframes pixelSpin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
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
  font-size: 2.5rem;
}

.error-text {
  font-size: 0.88rem;
  color: #f87171;
  text-align: center;
  margin: 0;
  background: #2a1619;
  border: 3px solid #000000;
  box-shadow: 3px 3px 0px #000000;
  padding: 0.75rem 1rem;
  border-radius: 4px;
  line-height: 1.5;
  width: 100%;
  box-sizing: border-box;
  font-weight: 700;
}

/* ── LINE 登入按鈕 (水管綠像素風) ── */
.line-login-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.7rem;
  width: 100%;
  padding: 0.85rem 1.25rem;
  background: var(--mario-green);
  color: #fff;
  border: 3px solid #000000;
  border-radius: 4px;
  font-size: 1rem;
  font-weight: 900;
  cursor: pointer;
  box-shadow: 5px 5px 0px #000000;
  transition: transform 0.08s ease, box-shadow 0.08s ease;
}

.line-login-btn:hover {
  background: #008f00;
  transform: translate(-1px, -1px);
  box-shadow: 6px 6px 0px #000000;
}

.line-login-btn:active {
  transform: translate(3px, 3px) !important;
  box-shadow: 2px 2px 0px #000000 !important;
}

.line-icon {
  display: inline-flex;
  align-items: center;
}

/* ── 本機開發模式面板 ── */
.dev-login-panel {
  width: 100%;
  margin-top: 0.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
  border-top: 3px dashed #334155;
  padding-top: 1.2rem;
}

.dev-divider {
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.85rem;
  color: var(--mario-yellow);
  font-weight: 900;
  letter-spacing: 0.5px;
}

.dev-hint {
  font-size: 0.82rem;
  color: var(--text-secondary);
  line-height: 1.45;
  text-align: center;
  margin: 0;
  font-weight: 700;
}

.dev-buttons {
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
}

.dev-btn {
  width: 100%;
  padding: 0.75rem;
  border-radius: 4px;
  font-size: 0.88rem;
  font-weight: 800;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  border: 3px solid #000000;
  box-shadow: 4px 4px 0px #000000;
}

.preview-btn {
  background: var(--mario-yellow);
  color: #000000;
}

.preview-btn:hover {
  background: #ffe04d;
}

.sync-btn {
  background: #161922;
  color: #f1f5f9;
}

.sync-btn:hover {
  background: #272d3e;
  color: var(--mario-yellow);
}
</style>
