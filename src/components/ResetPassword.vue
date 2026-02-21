<script setup>
import { ref } from 'vue'
import { supabase } from '../lib/supabase'

const emit = defineEmits(['done'])

const newPassword = ref('')
const confirmPassword = ref('')
const loading = ref(false)
const errorMessage = ref('')
const success = ref(false)

const handleReset = async () => {
    errorMessage.value = ''

    if (newPassword.value.length < 6) {
        errorMessage.value = '密碼長度至少需要 6 個字元'
        return
    }
    if (newPassword.value !== confirmPassword.value) {
        errorMessage.value = '兩次輸入的密碼不一致，請再確認'
        return
    }

    loading.value = true

    const { error } = await supabase.auth.updateUser({
        password: newPassword.value
    })

    loading.value = false

    if (error) {
        errorMessage.value = '更新失敗：' + error.message
    } else {
        // 清除 URL hash，避免重新整理又跳回重設畫面
        window.history.replaceState({}, document.title, window.location.pathname)
        success.value = true
        // 先登出，讓使用者重新以新密碼登入，避免直接進 Dashboard
        await supabase.auth.signOut()
        // 2 秒後通知父元件，此時 user 已是 null，會顯示登入頁
        setTimeout(() => emit('done'), 2000)
    }
}
</script>

<template>
    <div class="reset-page">
        <div class="reset-card glass-panel">
            <div class="reset-header">
                <div class="logo-icon">🔐</div>
                <h1>設定新密碼</h1>
                <p>請輸入你想要使用的新密碼</p>
            </div>

            <!-- 成功畫面 -->
            <div v-if="success" class="success-box">
                <div class="success-icon">✅</div>
                <p class="success-text">密碼已成功更新！</p>
                <p class="success-hint">即將跳回登入頁，請以新密碼重新登入</p>
            </div>

            <!-- 設定新密碼表單 -->
            <form v-else @submit.prevent="handleReset" class="reset-form">
                <div class="input-group">
                    <label>新密碼</label>
                    <input type="password" v-model="newPassword" placeholder="至少 6 個字元" required minlength="6"
                        autocomplete="new-password" />
                </div>

                <div class="input-group">
                    <label>確認新密碼</label>
                    <input type="password" v-model="confirmPassword" placeholder="再輸入一次新密碼" required
                        autocomplete="new-password" />
                </div>

                <p v-if="errorMessage" class="error-msg">⚠️ {{ errorMessage }}</p>

                <button type="submit" class="submit-btn" :disabled="loading">
                    <span v-if="loading" class="spinner"></span>
                    <span v-else>確認修改密碼</span>
                </button>
            </form>
        </div>
    </div>
</template>

<style scoped>
.reset-page {
    width: 100%;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1.5rem;
    box-sizing: border-box;
}

.reset-card {
    width: 100%;
    max-width: 420px;
    padding: 2.5rem 2rem;
    border-radius: 24px;
    display: flex;
    flex-direction: column;
    gap: 1.75rem;
}

.reset-header {
    text-align: center;
}

.logo-icon {
    font-size: 2.5rem;
    display: inline-block;
    background: linear-gradient(135deg, var(--accent-glow), var(--accent-hover));
    width: 64px;
    height: 64px;
    border-radius: 18px;
    line-height: 64px;
    margin-bottom: 1rem;
}

.reset-header h1 {
    font-size: 1.75rem;
    font-weight: 700;
    letter-spacing: -0.5px;
    margin: 0 0 0.4rem;
}

.reset-header p {
    color: var(--text-secondary);
    font-size: 0.95rem;
    margin: 0;
}

.reset-form {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.input-group {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
}

.input-group label {
    font-size: 0.85rem;
    font-weight: 500;
    color: var(--text-secondary);
}

.input-group input {
    padding: 0.75rem 1rem;
    background: rgba(0, 0, 0, 0.2);
    border: 1px solid var(--panel-border);
    border-radius: 10px;
    color: var(--text-primary);
    font-size: 1rem;
    font-family: inherit;
    transition: border-color 0.2s;
    outline: none;
}

.input-group input:focus {
    border-color: var(--accent-color);
    background: rgba(0, 0, 0, 0.35);
}

.error-msg {
    color: #f87171;
    font-size: 0.875rem;
    background: rgba(239, 68, 68, 0.1);
    border: 1px solid rgba(239, 68, 68, 0.2);
    border-radius: 8px;
    padding: 0.6rem 0.85rem;
    margin: 0;
}

.submit-btn {
    padding: 0.85rem;
    background: var(--accent-color);
    color: white;
    border: none;
    border-radius: 10px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    min-height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
}

.submit-btn:hover:not(:disabled) {
    background: var(--accent-hover);
    transform: translateY(-1px);
    box-shadow: 0 6px 20px rgba(99, 102, 241, 0.4);
}

.submit-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
}

/* 成功畫面 */
.success-box {
    text-align: center;
    padding: 1rem 0;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
}

.success-icon {
    font-size: 3rem;
    animation: pop 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
}

@keyframes pop {
    from {
        transform: scale(0);
    }

    to {
        transform: scale(1);
    }
}

.success-text {
    font-size: 1.1rem;
    font-weight: 600;
    color: #4ade80;
    margin: 0;
}

.success-hint {
    font-size: 0.875rem;
    color: var(--text-secondary);
    margin: 0;
}

/* Spinner */
@keyframes spin {
    to {
        transform: rotate(360deg);
    }
}

.spinner {
    width: 20px;
    height: 20px;
    border: 2px solid rgba(255, 255, 255, 0.3);
    border-top-color: white;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    display: inline-block;
}
</style>
