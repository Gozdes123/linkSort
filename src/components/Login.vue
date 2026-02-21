<script setup>
import { ref } from 'vue'
import { supabase } from '../lib/supabase'

const email = ref('')
const loading = ref(false)
const errorMessage = ref('')
const successMessage = ref('')

const handleLogin = async () => {
  if (!email.value) return
  loading.value = true
  errorMessage.value = ''
  successMessage.value = ''

  // 核心修正：動態組合當前網址 (包含 https://domain.com/repo-name/)
  // 這樣在本地開發會是 localhost，部署後會是 github.io/linkSort/
  const redirectUrl = window.location.origin + window.location.pathname

  const { error } = await supabase.auth.signInWithOtp({
    email: email.value,
    options: {
      // 傳送正確的跳轉地址給 Supabase
      emailRedirectTo: redirectUrl
    }
  })

  if (error) {
    errorMessage.value = error.message
  } else {
    successMessage.value = '登入連結已發送！請去您的信箱收信，並點擊信中的連結即可登入。'
  }

  loading.value = false
}
</script>

<template>
  <div class="login-container">
    <div class="glass-panel login-card animate-fade-in">
      <div class="brand">
        <div class="logo-circle">
          <span class="logo-icon">🔗</span>
        </div>
        <h1>LinkSort</h1>
        <p>你的智慧社群連結管家</p>
      </div>

      <form @submit.prevent="handleLogin" class="login-form">
        <div class="input-group">
          <label>電子信箱 Email (無密碼登入)</label>
          <input type="email" v-model="email" placeholder="friend@example.com" required
            :disabled="successMessage !== ''" />
        </div>

        <p v-if="errorMessage" class="error-msg">{{ errorMessage }}</p>
        <div v-if="successMessage" class="success-box">
          <span class="icon">📬</span>
          <p>{{ successMessage }}</p>
        </div>

        <button v-if="!successMessage" type="submit" class="login-btn" :class="{ loading }">
          <span v-if="!loading">發送專屬登入連結</span>
          <span v-else class="loader"></span>
        </button>
      </form>

      <div class="footer-note" v-if="!successMessage">
        <p>我們採用更安全、無需記憶密碼的 Magic Link 登入方式。</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.login-container {
  width: 100vw;
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
}

.login-card {
  width: 100%;
  max-width: 400px;
  padding: 2.5rem;
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.brand {
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.logo-circle {
  width: 64px;
  height: 64px;
  background: linear-gradient(135deg, var(--accent-glow), var(--accent-hover));
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 1rem;
  font-size: 1.5rem;
  box-shadow: 0 4px 15px var(--accent-glow);
}

.brand h1 {
  font-size: 1.75rem;
  letter-spacing: -0.5px;
  margin-bottom: 0.25rem;
}

.brand p {
  font-size: 0.9rem;
  opacity: 0.8;
}

.login-form {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.input-group label {
  font-size: 0.85rem;
  font-weight: 500;
  color: var(--text-secondary);
}

/* 如果發送成功，把輸入框稍微變暗 */
input:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.login-btn {
  background: var(--accent-color);
  color: white;
  font-weight: 600;
  padding: 0.85rem;
  border-radius: 8px;
  margin-top: 1rem;
  position: relative;
  overflow: hidden;
}

.login-btn:hover:not(.loading) {
  background: var(--accent-hover);
  transform: translateY(-1px);
  box-shadow: 0 4px 12px var(--accent-glow);
}

.login-btn:active:not(.loading) {
  transform: translateY(1px);
  box-shadow: none;
}

.error-msg {
  color: #ff6b6b;
  font-size: 0.85rem;
  text-align: center;
  margin-top: -0.5rem;
}

.success-box {
  background: rgba(16, 185, 129, 0.1);
  border: 1px solid rgba(16, 185, 129, 0.2);
  border-radius: 8px;
  padding: 1.25rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  text-align: center;
}

.success-box .icon {
  font-size: 2rem;
}

.success-box p {
  color: #10b981;
  font-weight: 500;
  font-size: 0.95rem;
  line-height: 1.5;
}

.footer-note {
  text-align: center;
  font-size: 0.8rem;
  margin-top: 1rem;
  color: var(--text-secondary);
}

.loader {
  display: inline-block;
  width: 20px;
  height: 20px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-radius: 50%;
  border-top-color: white;
  animation: spin 0.8s ease-in-out infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
