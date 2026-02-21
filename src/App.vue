<script setup>
import { ref, onMounted } from 'vue'
import Login from './components/Login.vue'
import Dashboard from './components/Dashboard.vue'
import { supabase } from './lib/supabase'

const user = ref(null)
const isLoading = ref(true)

onMounted(() => {
  // 取得目前 Supabase 的連線 session
  supabase.auth.getSession().then(({ data: { session } }) => {
    user.value = session?.user || null
    isLoading.value = false
  })

  // 監聽登入狀態改變
  supabase.auth.onAuthStateChange((_event, session) => {
    user.value = session?.user || null
  })
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
  display: inline-block;
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
