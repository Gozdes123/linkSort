<script setup>
import { ref, onMounted } from 'vue'
import Login from './components/Login.vue'
import Dashboard from './components/Dashboard.vue'
import ResetPassword from './components/ResetPassword.vue'
import { supabase } from './lib/supabase'

const user = ref(null)
const isLoading = ref(true)
const isResettingPassword = ref(false)

// ★ 關鍵修正：在任何非同步操作之前，先檢查 URL hash/params
// Supabase 密碼重設連結帶有 #type=recovery 或 ?type=recovery
const checkRecoveryFromUrl = () => {
  // 情況 A：Implicit flow（URL hash：#access_token=...&type=recovery）
  const hash = new URLSearchParams(window.location.hash.slice(1))
  if (hash.get('type') === 'recovery') {
    isResettingPassword.value = true
    return
  }
  // 情況 B：PKCE flow（Query string：?code=...&type=recovery）
  const query = new URLSearchParams(window.location.search)
  if (query.get('type') === 'recovery') {
    isResettingPassword.value = true
  }
}

onMounted(() => {
  // 最先執行，不等任何 async
  checkRecoveryFromUrl()

  supabase.auth.getSession().then(({ data: { session } }) => {
    user.value = session?.user || null
    isLoading.value = false
  })

  supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'PASSWORD_RECOVERY') {
      isResettingPassword.value = true
      user.value = session?.user || null
    } else if (event === 'USER_UPDATED') {
      // 密碼改完後，清除重設狀態，讓使用者進入 Dashboard
      isResettingPassword.value = false
      user.value = session?.user || null
    } else {
      user.value = session?.user || null
    }
  })
})
</script>

<template>
  <div v-if="!isLoading" id="app-root">
    <ResetPassword v-if="isResettingPassword" @done="isResettingPassword = false" />
    <template v-else>
      <Login v-if="!user" />
      <Dashboard v-else :user="user" />
    </template>
  </div>
  <div v-else class="loading-screen">
    <div class="loader"></div>
  </div>
</template>

<style scoped>
#app-root {
  width: 100vw;
  height: 100vh;
}

.loading-screen {
  width: 100vw;
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, var(--bg-gradient-start) 0%, var(--bg-gradient-end) 100%);
}

.loader {
  width: 40px;
  height: 40px;
  border: 4px solid rgba(255, 255, 255, 0.1);
  border-radius: 50%;
  border-top-color: var(--accent-color);
  animation: spin 1s ease-in-out infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
