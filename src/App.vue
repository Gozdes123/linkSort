<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import Login from './components/Login.vue'
import Dashboard from './components/Dashboard.vue'
import { supabase } from './lib/supabase'

const user = ref(null)
const isLoading = ref(true)
let authSubscription = null
let signedOutAt = 0  // 記錄最後一次登出的時間點

onMounted(async () => {
  try {
    const { data: { session }, error } = await supabase.auth.getSession()
    if (error) {
      await supabase.auth.signOut()
      user.value = null
    } else {
      user.value = session?.user || null
    }
  } catch (err) {
    console.error('Auth 初始化錯誤:', err)
  } finally {
    isLoading.value = false
  }

  const { data } = supabase.auth.onAuthStateChange((event, session) => {
    console.log('[Auth] event:', event, '| user:', session?.user?.id ?? 'null')

    if (event === 'SIGNED_OUT') {
      signedOutAt = Date.now()
      user.value = null
      return
    }

    // 登出後 3 秒內，忽略所有重新登入事件（防止 token 自動刷新導致意外恢復登入狀態）
    if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') {
      if (Date.now() - signedOutAt < 3000) {
        console.log('[Auth] 剛剛登出，忽略此事件:', event)
        return
      }
    }

    user.value = session?.user || null
  })
  authSubscription = data.subscription
})

onUnmounted(() => {
  authSubscription?.unsubscribe()
})
</script>

<template>
  <div v-if="!isLoading" id="app-root">
    <Login v-if="!user" />
    <Dashboard v-else :user="user" />
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
  to { transform: rotate(360deg); }
}
</style>
