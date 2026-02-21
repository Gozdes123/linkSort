<script setup>
import { ref } from 'vue'
import { supabase } from '../lib/supabase'

const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')
const success = ref('')
const mode = ref('login') // 'login' | 'register' | 'forgot'

const switchMode = (m) => {
  mode.value = m
  error.value = ''
  success.value = ''
}

const translateError = (msg = '') => {
  if (msg.includes('Invalid login credentials')) return '帳號或密碼錯誤，請再試一次'
  if (msg.includes('User already registered')) return '此 Email 已經註冊，請直接登入'
  if (msg.includes('Password should be at least')) return '密碼長度至少需要 6 個字元'
  if (msg.includes('rate limit') || msg.includes('email rate limit'))
    return '寄信次數已達上限（每小時 2 封），請稍後再試'
  if (msg.includes('Unable to validate email')) return 'Email 格式不正確'
  if (msg.includes('Email not confirmed')) return '帳號尚未驗證，請先去信箱點擊驗證連結'
  return msg
}

const handleSubmit = async () => {
  if (!email.value) return
  if (mode.value !== 'forgot' && !password.value) return
  loading.value = true
  error.value = ''
  success.value = ''

  if (mode.value === 'login') {
    const { error: e } = await supabase.auth.signInWithPassword({
      email: email.value,
      password: password.value,
    })
    if (e) error.value = translateError(e.message)
    // 成功時 App.vue 的 onAuthStateChange 自動跳轉

  } else if (mode.value === 'register') {
    const { data, error: e } = await supabase.auth.signUp({
      email: email.value,
      password: password.value,
    })
    if (e) {
      error.value = translateError(e.message)
    } else if (data?.user?.identities?.length === 0) {
      error.value = '此 Email 已經註冊，請直接登入'
    } else if (data?.session) {
      success.value = '帳號建立成功！正在登入...'
    } else {
      success.value = `驗證信已發送到 ${email.value}，點擊信中連結完成驗證後再回來登入`
    }

  } else if (mode.value === 'forgot') {
    const redirectUrl = window.location.origin + window.location.pathname
    const { error: e } = await supabase.auth.resetPasswordForEmail(email.value, {
      redirectTo: redirectUrl,
    })
    if (e) {
      error.value = translateError(e.message)
    } else {
      success.value = `密碼重設信已寄到 ${email.value}，請收信後點擊連結設定新密碼`
    }
  }

  loading.value = false
}
</script>

<template>
  <div class="login-page">
    <div class="login-card glass-panel">

      <!-- Logo -->
      <div class="brand">
        <div class="logo-wrap">🔗</div>
        <h1>LinkSort</h1>
        <p>你的個人連結收藏庫</p>
      </div>

      <!-- Tab 切換 -->
      <div class="tabs">
        <button :class="{ active: mode === 'login' }" @click="switchMode('login')">登入</button>
        <button :class="{ active: mode === 'register' }" @click="switchMode('register')">註冊</button>
        <button :class="{ active: mode === 'forgot' }" @click="switchMode('forgot')">忘記密碼</button>
      </div>

      <!-- Form -->
      <form @submit.prevent="handleSubmit" class="form">

        <div class="field">
          <label>{{ mode === 'forgot' ? '請輸入你的 Email' : 'Email' }}</label>
          <input type="email" v-model="email" placeholder="your@email.com" required autocomplete="email" />
        </div>

        <div class="field" v-if="mode !== 'forgot'">
          <label>密碼</label>
          <input type="password" v-model="password" placeholder="至少 6 個字元" required minlength="6"
            autocomplete="current-password" />
        </div>

        <!-- 錯誤訊息 -->
        <div v-if="error" class="msg error">⚠️ {{ error }}</div>
        <!-- 成功訊息 -->
        <div v-if="success" class="msg success">✅ {{ success }}</div>

        <button type="submit" class="submit" :disabled="loading">
          <span v-if="loading" class="spinner"></span>
          <span v-else>
            {{ mode === 'login' ? '登入' : mode === 'register' ? '建立帳號' : '發送重設密碼信' }}
          </span>
        </button>

      </form>

      <!-- 底部提示 -->
      <p class="hint" v-if="mode === 'login'">
        還沒有帳號？<button class="link" @click="switchMode('register')">立即註冊</button>
      </p>
      <p class="hint" v-else-if="mode === 'register'">
        已有帳號？<button class="link" @click="switchMode('login')">回到登入</button>
      </p>
      <p class="hint" v-else>
        想起密碼了？<button class="link" @click="switchMode('login')">回到登入</button>
      </p>

    </div>
  </div>
</template>

<style scoped>
.login-page {
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
  padding: 2.25rem 2rem;
  border-radius: 24px;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

/* ---- Brand ---- */
.brand {
  text-align: center;
}

.logo-wrap {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 62px;
  height: 62px;
  font-size: 1.75rem;
  border-radius: 18px;
  background: linear-gradient(135deg, var(--accent-glow), var(--accent-hover));
  margin-bottom: 0.9rem;
  box-shadow: 0 4px 20px rgba(99, 102, 241, 0.4);
}

.brand h1 {
  font-size: 1.9rem;
  font-weight: 700;
  letter-spacing: -1px;
  margin: 0 0 0.3rem;
}

.brand p {
  font-size: 0.9rem;
  color: var(--text-secondary);
  margin: 0;
}

/* ---- Tabs ---- */
.tabs {
  display: flex;
  background: rgba(0, 0, 0, 0.2);
  border-radius: 10px;
  padding: 4px;
  gap: 4px;
}

.tabs button {
  flex: 1;
  padding: 0.5rem 0;
  border: none;
  border-radius: 8px;
  background: transparent;
  color: var(--text-secondary);
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.tabs button.active {
  background: var(--accent-color);
  color: #fff;
  box-shadow: 0 2px 10px rgba(99, 102, 241, 0.35);
}

/* ---- Form ---- */
.form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.field label {
  font-size: 0.82rem;
  font-weight: 500;
  color: var(--text-secondary);
}

.field input {
  padding: 0.75rem 1rem;
  background: rgba(0, 0, 0, 0.2);
  border: 1px solid var(--panel-border);
  border-radius: 10px;
  color: var(--text-primary);
  font-size: 1rem;
  font-family: inherit;
  outline: none;
  transition: border-color 0.2s, background 0.2s;
  min-height: 48px;
}

.field input:focus {
  border-color: var(--accent-color);
  background: rgba(0, 0, 0, 0.35);
}

/* ---- Messages ---- */
.msg {
  font-size: 0.875rem;
  border-radius: 8px;
  padding: 0.65rem 0.9rem;
  line-height: 1.5;
}

.msg.error {
  color: #fca5a5;
  background: rgba(239, 68, 68, 0.1);
  border: 1px solid rgba(239, 68, 68, 0.25);
}

.msg.success {
  color: #6ee7b7;
  background: rgba(16, 185, 129, 0.08);
  border: 1px solid rgba(16, 185, 129, 0.2);
}

/* ---- Submit ---- */
.submit {
  padding: 0.85rem;
  background: var(--accent-color);
  color: #fff;
  border: none;
  border-radius: 10px;
  font-size: 1rem;
  font-weight: 600;
  font-family: inherit;
  cursor: pointer;
  transition: all 0.2s;
  min-height: 50px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.submit:hover:not(:disabled) {
  background: var(--accent-hover);
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(99, 102, 241, 0.4);
}

.submit:active:not(:disabled) {
  transform: translateY(0);
}

.submit:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

/* ---- Hint ---- */
.hint {
  text-align: center;
  font-size: 0.875rem;
  color: var(--text-secondary);
  margin: 0;
}

.link {
  background: none;
  border: none;
  color: var(--accent-color);
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  padding: 0;
  text-decoration: underline;
  text-underline-offset: 2px;
  font-family: inherit;
}

.link:hover {
  color: var(--accent-hover);
}

/* ---- Spinner ---- */
.spinner {
  width: 20px;
  height: 20px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  display: inline-block;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
