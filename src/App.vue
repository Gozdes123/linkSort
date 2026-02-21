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

onMounted(async () => {
  // 最先執行，不等任何 async
  checkRecoveryFromUrl()

  // 檢查是否帶有 lineId 準備綁定
  const handleLineBinding = async (userId) => {
    try {
      const query = new URLSearchParams(window.location.search)
      const lineId = query.get('lineId')
      if (lineId && userId) {
        // 將 Supabase ID 和 LINE ID 綁定存入 user_profiles 表格
        const { error } = await supabase
          .from('user_profiles')
          .upsert({ id: userId, line_id: lineId }, { onConflict: 'id' })
        
        if (!error) {
          alert('🎉 LINE 機器人帳號綁定成功！現在請回 LINE 傳送連結吧！')
          
          // 使用 URLSearchParams 優雅地清理網址列，避免 GitHub Pages 的 404
          const newUrl = new URL(window.location.href);
          newUrl.searchParams.delete('lineId');
          // 清理後的網址若只剩 '?'，就把 '?' 也去掉
          const cleanUrl = newUrl.href.endsWith('?') ? newUrl.href.slice(0, -1) : newUrl.href;
          window.history.replaceState({}, document.title, cleanUrl);
        } else {
          console.error('LINE 綁定失敗:', error)
          // 假如是刪除後的無效憑證，進行安全登出
          if (error.code === '401' || error.message?.includes('JWT')) {
            await supabase.auth.signOut()
          }
        }
      }
    } catch (e) {
      console.error('Line Binding API 例外錯誤:', e)
    }
  }

  // 確保無論發生什麼事（如 LINE 瀏覽器禁止 Cookie/localStorage、無效金鑰），都能結束 Loading
  try {
    const { data: { session }, error } = await supabase.auth.getSession()
    if (error) {
      await supabase.auth.signOut()
      user.value = null
    } else {
      user.value = session?.user || null
    }

    if (user.value) {
      await handleLineBinding(user.value.id)
    }
  } catch (err) {
    console.error('Auth 初始化錯誤:', err)
  } finally {
    isLoading.value = false
  }

  supabase.auth.onAuthStateChange(async (event, session) => {
    if (event === 'PASSWORD_RECOVERY') {
      isResettingPassword.value = true
      user.value = session?.user || null
    } else if (event === 'USER_UPDATED') {
      // 密碼改完後，清除重設狀態，讓使用者進入 Dashboard
      isResettingPassword.value = false
      user.value = session?.user || null
    } else {
      user.value = session?.user || null
      if (user.value) await handleLineBinding(user.value.id)
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
