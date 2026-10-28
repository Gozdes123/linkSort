<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import Login from './components/Login.vue'
import Dashboard from './components/Dashboard.vue'
import { supabase } from './lib/supabase'

const user = ref(null)
const isLoading = ref(true)
let authSubscription = null
let signedOutAt = 0

onMounted(async () => {
  const isDevPreview = sessionStorage.getItem('linksort_dev_preview') === 'true'
  if (isDevPreview) {
    user.value = {
      id: 'dev-user',
      email: 'dev@linksort.local',
      user_metadata: { display_name: '本機開發者' }
    }
    isLoading.value = false
    return
  }

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
    if (sessionStorage.getItem('linksort_dev_preview') === 'true') {
      return
    }

    if (event === 'SIGNED_OUT') {
      signedOutAt = Date.now()
      user.value = null
      return
    }

    if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') {
      if (Date.now() - signedOutAt < 3000) {
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
    <div class="cute-loader">
      <div class="loader-heart">💖</div>
      <p>正在載入可愛世界...</p>
    </div>
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
  background: radial-gradient(circle at 10% 20%, #ffe8ee 0%, #fff2f6 35%, #f4e8ff 70%, #e6f3ff 100%);
}

.cute-loader {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.8rem;
}

.loader-heart {
  font-size: 2.5rem;
  animation: pulse 0.8s ease-in-out infinite alternate;
}

.cute-loader p {
  color: #ff6584;
  font-weight: 600;
  font-size: 0.95rem;
}

@keyframes pulse {
  from { transform: scale(0.9); }
  to { transform: scale(1.15); }
}
</style>
