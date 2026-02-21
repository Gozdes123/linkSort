<script setup>
import { ref, computed, onMounted } from 'vue'
import LinkCard from './LinkCard.vue'
import { supabase } from '../lib/supabase'

const props = defineProps({
  user: {
    type: Object,
    required: true
  }
})

// 母分類 (固定的社群平台)
const platforms = ['全部來源', 'Threads', 'Instagram', 'Dcard', 'YouTube', 'X', '其他來源']
const activePlatform = ref('全部來源')

// 子分類 (自訂我的收藏)
const customCategories = ref([])
const activeCollection = ref('全部收藏')

const links = ref([])
const newUrl = ref('')
const isLoadingInitial = ref(true)

// 批次管理相關狀態
const isBatchMode = ref(false)
const selectedLinks = ref(new Set())
const batchTargetCategory = ref('未分類')

// Toast 通知系統
const toasts = ref([]) // [{ id, message, type }]
let toastCounter = 0
const showToast = (message, type = 'success') => {
  const id = ++toastCounter
  toasts.value.push({ id, message, type })
  setTimeout(() => {
    toasts.value = toasts.value.filter(t => t.id !== id)
  }, 3200)
}

// 從 localStorage 載入使用者的自訂分類
const loadCustomCategories = () => {
  const saved = localStorage.getItem(`linksort_custom_categories_${props.user.id}`)
  if (saved) {
    customCategories.value = JSON.parse(saved)
  }
}

// 儲存使用者的自訂分類到 localStorage
const saveCustomCategories = () => {
  localStorage.setItem(`linksort_custom_categories_${props.user.id}`, JSON.stringify(customCategories.value))
}

const createCustomCategory = () => {
  const name = prompt('請輸入新分類名稱 (例如：設計靈感、工作用)：')
  if (name && name.trim() !== '') {
    const trimmed = name.trim()
    if (!customCategories.value.includes(trimmed) && trimmed !== '全部收藏' && trimmed !== '未分類') {
      customCategories.value.push(trimmed)
      saveCustomCategories()
      activeCollection.value = trimmed
      activePlatform.value = '全部來源'
    } else {
      alert('這個分類已經存在或名稱無法使用囉！')
    }
  }
}

// 從 Supabase 抓取資料
const fetchLinks = async () => {
  isLoadingInitial.value = true
  const { data, error } = await supabase
    .from('links')
    .select('*')
    .order('created_at', { ascending: false })

  if (!error && data) {
    // 確保即使資料庫欄位是 NULL 也能自動轉成 '未分類'
    links.value = data.map(l => ({
      ...l,
      custom_category: l.custom_category || '未分類'
    }))

    // 自動把現有資料的分類加入 customCategories
    const existingCats = new Set(links.value.filter(l => l.custom_category && l.custom_category !== '未分類').map(l => l.custom_category))
    let changed = false
    existingCats.forEach(cat => {
      if (!customCategories.value.includes(cat)) {
        customCategories.value.push(cat)
        changed = true
      }
    })
    if (changed) saveCustomCategories()
  }
  isLoadingInitial.value = false
}

onMounted(async () => {
  loadCustomCategories()
  await fetchLinks()

  const urlParams = new URLSearchParams(window.location.search);
  const sharedUrl = urlParams.get('url');

  if (sharedUrl) {
    // 1. 先解碼網址
    const decodedUrl = decodeURIComponent(sharedUrl);

    // 2. 賦值給輸入框
    newUrl.value = decodedUrl;

    // 3. 稍微延遲一下下，確保 Vue 已經更新了 DOM 和變數，再執行 addLink
    setTimeout(async () => {
      console.log('捷徑自動偵測到網址，準備儲存:', newUrl.value);
      await addLink(true); // 傳入 fromShortcut = true

      // 4. 存完後再清空網址列
      window.history.replaceState({}, document.title, window.location.pathname);
    }, 500);
  }
})

// 雙重新篩選邏輯：同時比對平台來源和自訂子分類
const filteredLinks = computed(() => {
  return links.value.filter(link => {
    const matchPlatform = activePlatform.value === '全部來源' || link.category === activePlatform.value || (activePlatform.value === '其他來源' && !['Threads', 'Dcard', 'YouTube', 'X'].includes(link.category))
    const matchCollection = activeCollection.value === '全部收藏' || link.custom_category === activeCollection.value
    return matchPlatform && matchCollection
  })
})

const getBadgeColor = (platform) => {
  const colors = {
    Threads: 'var(--color-threads)',
    Instagram: 'var(--color-instagram)',
    Dcard: 'var(--color-dcard)',
    YouTube: 'var(--color-youtube)',
    X: 'var(--color-x)',
  }
  return colors[platform] || '#475569'
}

const parseCategory = (url) => {
  try {
    const domain = new URL(url).hostname.toLowerCase()
    if (domain.includes('threads.net') || domain.includes('threads.com')) return 'Threads'
    if (domain.includes('instagram.com')) return 'Instagram'
    if (domain.includes('dcard.tw') || domain.includes('dcard.cc')) return 'Dcard'
    if (domain.includes('youtube.com') || domain.includes('youtu.be')) return 'YouTube'
    if (domain.includes('twitter.com') || domain.includes('x.com')) return 'X'
    return '其他來源'
  } catch (e) {
    return '其他來源'
  }
}

// 透過 Microlink API 免費抓取 OG 縮圖與標題
const fetchOgData = async (url) => {
  try {
    const res = await fetch(`https://api.microlink.io?url=${encodeURIComponent(url)}`)
    const json = await res.json()
    if (json.status === 'success') {
      return {
        title: json.data.title || null,
        description: json.data.description || null,
        thumbnail_url: json.data.image?.url || null,
      }
    }
  } catch (_) { }
  return { title: null, description: null, thumbnail_url: null }
}

const addLink = async (fromShortcut = false) => {
  if (!newUrl.value) return
  const platform = parseCategory(newUrl.value)
  const tempUrl = newUrl.value
  newUrl.value = ''

  const targetCollection = activeCollection.value !== '全部收藏' ? activeCollection.value : '未分類'

  // 先用預設資料立即插入，再背景更新 OG 資料
  const insertData = {
    url: tempUrl,
    title: '抓取標題中...',
    category: platform,
    custom_category: targetCollection,
    user_id: props.user.id,
    thumbnail_url: null,
    description: null,
  }

  const { data, error } = await supabase
    .from('links')
    .insert([insertData])
    .select()
    .single()

  if (error) {
    showToast('❌ 儲存失敗：' + error.message, 'error')
    return
  }

  if (data) {
    links.value.unshift(data)
    if (fromShortcut) {
      showToast('✅ 捷徑新增成功！正在抓取標題...')
    } else {
      showToast('✅ 連結已儲存！')
    }

    // 背景異步抓 OG 資料，不阻塞 UI
    fetchOgData(tempUrl).then(async (og) => {
      const updatePayload = {
        title: og.title || '（無法取得標題）',
        description: og.description,
        thumbnail_url: og.thumbnail_url,
      }
      await supabase.from('links').update(updatePayload).eq('id', data.id)
      // 即時更新畫面，不需重整
      links.value = links.value.map(l =>
        l.id === data.id ? { ...l, ...updatePayload } : l
      )
    })
  }
}

const deleteLink = async (id) => {
  const { error } = await supabase.from('links').delete().eq('id', id)
  if (!error) {
    links.value = links.value.filter(link => link.id !== id)
    if (selectedLinks.value.has(id)) {
      selectedLinks.value.delete(id)
    }
  } else {
    alert('刪除失敗：' + error.message)
  }
}

// 批次管理功能
const toggleBatchMode = () => {
  isBatchMode.value = !isBatchMode.value
  selectedLinks.value.clear()
}

const handleToggleSelect = (id) => {
  const newSet = new Set(selectedLinks.value)
  if (newSet.has(id)) {
    newSet.delete(id)
  } else {
    newSet.add(id)
  }
  selectedLinks.value = newSet
}

const applyBatchCategory = async () => {
  if (selectedLinks.value.size === 0) return

  const idsToUpdate = Array.from(selectedLinks.value)
  const targetCategory = batchTargetCategory.value

  const { error } = await supabase
    .from('links')
    .update({ custom_category: targetCategory })
    .in('id', idsToUpdate)

  if (error) {
    alert('批次移動失敗：' + error.message)
    return
  }

  links.value = links.value.map(link => {
    if (idsToUpdate.includes(link.id)) {
      return { ...link, custom_category: targetCategory }
    }
    return link
  })

  isBatchMode.value = false
  selectedLinks.value.clear()
  if (targetCategory !== '未分類') {
    activeCollection.value = targetCategory
  }
}

const editLinkTitle = async (id, oldTitle) => {
  const newTitle = prompt('請輸入新的標題：', oldTitle)
  if (newTitle !== null && newTitle.trim() !== '') {
    const { error } = await supabase
      .from('links')
      .update({ title: newTitle.trim() })
      .eq('id', id)

    if (error) {
      alert('更新標題失敗：' + error.message)
    } else {
      links.value = links.value.map(l =>
        l.id === id ? { ...l, title: newTitle.trim() } : l
      )
    }
  }
}

const handleEditLink = (id, oldTitle) => {
  editLinkTitle(id, oldTitle)
}

// 編輯子分類名稱的邏輯 (會同步更新所有使用該分類的連結)
const editCustomCategory = async (oldName) => {
  if (oldName === '未分類' || oldName === '全部收藏') return

  const newName = prompt(`為「${oldName}」輸入新的名稱：`, oldName)
  if (!newName || newName.trim() === '' || newName === oldName) return

  const trimmedNewName = newName.trim()
  if (customCategories.value.includes(trimmedNewName)) {
    alert('這個分類名稱已經存在囉！')
    return
  }

  // 1. 更新資料庫裡所有使用此子分類的連結
  const { error } = await supabase
    .from('links')
    .update({ custom_category: trimmedNewName })
    .eq('custom_category', oldName)
    .eq('user_id', props.user.id) // 確保只改自己的

  if (error) {
    alert('更新分類名稱失敗：' + error.message)
    return
  }

  // 2. 更新本地端 localStorage 裡的分類清單
  const idx = customCategories.value.indexOf(oldName)
  if (idx !== -1) {
    customCategories.value[idx] = trimmedNewName
    saveCustomCategories()
  }

  // 3. 更新目前顯示在畫面上的連結資料
  links.value = links.value.map(l =>
    l.custom_category === oldName ? { ...l, custom_category: trimmedNewName } : l
  )

  // 4. 重設狀態
  if (activeCollection.value === oldName) {
    activeCollection.value = trimmedNewName
  }
}

const handleLogout = async () => {
  await supabase.auth.signOut()
}

// 手機側邊欄開關
const isSidebarOpen = ref(false)
const closeSidebar = () => { isSidebarOpen.value = false }
const openSidebar = () => { isSidebarOpen.value = true }

// 手機上點選分類後自動關閉側邊欄
const selectPlatform = (plat) => {
  activePlatform.value = plat
  closeSidebar()
}
const selectCollection = (col) => {
  activeCollection.value = col
  closeSidebar()
}
</script>

<template>
  <div class="dashboard-layout">
    <!-- Toast 通知區域 -->
    <div class="toast-container">
      <transition-group name="toast-anim">
        <div v-for="toast in toasts" :key="toast.id" class="toast" :class="toast.type">
          {{ toast.message }}
        </div>
      </transition-group>
    </div>

    <!-- 手機遮罩背景 -->
    <div class="sidebar-overlay" :class="{ active: isSidebarOpen }" @click="closeSidebar"></div>

    <!-- Sidebar -->
    <aside class="sidebar glass-panel" :class="{ 'sidebar-open': isSidebarOpen }">
      <div class="sidebar-header">
        <div class="logo">
          <span class="logo-icon">🔗</span>
          <h2>LinkSort</h2>
        </div>
        <p class="user-greeting">哈囉，{{ user.email.split('@')[0] }}</p>
      </div>

      <div class="sidebar-nav">
        <!-- 母分類 -->
        <h3>🏢 平台來源 (系統分類)</h3>
        <ul class="nav-list platform-list">
          <li v-for="plat in platforms" :key="plat" :class="{ active: activePlatform === plat }"
            @click="selectPlatform(plat)">
            <span class="color-dot" :style="{ background: getBadgeColor(plat) }"></span>
            {{ plat }}
          </li>
        </ul>

        <div class="divider"></div>

        <!-- 子分類 -->
        <h3>📁 我的收藏 (你的標籤)</h3>
        <ul class="nav-list collection-list">
          <li :class="{ active: activeCollection === '全部收藏' }" @click="selectCollection('全部收藏')">
            <span class="list-text">全部收藏</span>
          </li>
          <li :class="{ active: activeCollection === '未分類' }" @click="selectCollection('未分類')">
            <span class="list-text">未分類</span>
          </li>
          <li v-for="cat in customCategories" :key="cat" :class="{ active: activeCollection === cat }"
            class="collection-item">
            <!-- 名稱與編輯按鈕橫排，編輯按鈕永遠可見 -->
            <span class="list-text" @click="selectCollection(cat)">{{ cat }}</span>
            <button class="edit-cat-btn" @click.stop="editCustomCategory(cat)" title="編輯分類名稱">
              <svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none"
                stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path>
                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path>
              </svg>
            </button>
          </li>
        </ul>
        <button class="add-category-btn" @click="createCustomCategory">
          + 新增子分類標籤
        </button>
      </div>

      <div class="sidebar-footer">
        <button class="logout-btn" @click="handleLogout">登出</button>
      </div>
    </aside>

    <!-- Main Content -->
    <main class="main-content">
      <header class="main-header glass-panel">

        <!-- ===== 一般模式 ===== -->
        <template v-if="!isBatchMode">
          <button class="hamburger-btn" @click="openSidebar" title="開啟選單">
            <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none"
              stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="3" y1="12" x2="21" y2="12"></line>
              <line x1="3" y1="6" x2="21" y2="6"></line>
              <line x1="3" y1="18" x2="21" y2="18"></line>
            </svg>
          </button>

          <div class="add-link-form">
            <input type="url" v-model="newUrl" placeholder="貼上連結按 Enter 儲存..." @keyup.enter="addLink" />
            <button class="add-btn" @click="addLink">儲存</button>
          </div>

          <!-- 批次管理：純 icon 按鈕，固定 40px 寬度，永遠不超出畫面 -->
          <button class="batch-icon-btn" @click="toggleBatchMode" title="批次管理">
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none"
              stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="9 11 12 14 22 4"></polyline>
              <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"></path>
            </svg>
          </button>
        </template>

        <!-- ===== 批次模式：header 直接變成批次操作列 ===== -->
        <template v-else>
          <!-- 左側：已選筆數 + 取消按鈕 -->
          <div class="batch-left">
            <button class="cancel-batch-btn" @click="toggleBatchMode" title="取消">
              <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none"
                stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <line x1="18" y1="6" x2="6" y2="18"></line>
                <line x1="6" y1="6" x2="18" y2="18"></line>
              </svg>
            </button>
            <span class="batch-count">
              已選 <strong>{{ selectedLinks.size }}</strong> 項
            </span>
          </div>

          <!-- 右側：分類選擇 + 確認按鈕 -->
          <div class="batch-right">
            <select v-model="batchTargetCategory" class="batch-select-inline">
              <option value="未分類">取消標籤</option>
              <option v-for="cat in customCategories" :key="cat" :value="cat">{{ cat }}</option>
            </select>
            <button class="confirm-batch-btn" @click="applyBatchCategory" :disabled="selectedLinks.size === 0">
              移動
            </button>
          </div>
        </template>

      </header>

      <div class="links-container">
        <h2 class="section-title">
          <span class="title-platform">{{ activePlatform }}</span>
          <span class="title-separator" v-if="activeCollection !== '全部收藏'">/</span>
          <span class="title-collection" v-if="activeCollection !== '全部收藏'">{{ activeCollection }}</span>
          <span v-if="isBatchMode" class="batch-title-hint">(點擊卡片選取)</span>
        </h2>

        <div v-if="isLoadingInitial" class="loading-state">
          載入中...
        </div>
        <div v-else>
          <div class="links-grid" v-if="filteredLinks.length">
            <LinkCard v-for="link in filteredLinks" :key="link.id" :link="link" :selectable="isBatchMode"
              :selected="selectedLinks.has(link.id)" @delete="deleteLink" @toggleSelect="handleToggleSelect"
              @edit="handleEditLink" />
          </div>
          <div class="empty-state glass-panel" v-else>
            <span class="icon">📂</span>
            <p>這個篩選條件下沒有任何連結喔！</p>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>

<style scoped>
/* === 基礎佈局 === */
.dashboard-layout {
  display: flex;
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  position: relative;
}

/* === 側邊欄遮罩（手機用）=== */
.sidebar-overlay {
  display: none;
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(4px);
  z-index: 200;
  opacity: 0;
  pointer-events: none;
  /* 最關鍵：預設不攔截任何點擊/觸碰 */
  transition: opacity 0.3s ease;
}

/* === 側邊欄 === */
.sidebar {
  width: 260px;
  height: calc(100vh - 2rem);
  margin: 1rem;
  border-radius: 20px;
  display: flex;
  flex-direction: column;
  padding: 1.5rem;
  flex-shrink: 0;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4);
  transition: transform 0.35s cubic-bezier(0.32, 0.72, 0, 1);
}

.sidebar-header {
  margin-bottom: 1.5rem;
}

.logo {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 0.5rem;
}

.logo-icon {
  background: linear-gradient(135deg, var(--accent-glow), var(--accent-hover));
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
  font-size: 1.2rem;
}

.logo h2 {
  font-size: 1.4rem;
  margin: 0;
  letter-spacing: -0.5px;
}

.user-greeting {
  font-size: 0.85rem;
  color: var(--text-secondary);
  opacity: 0.8;
}

/* === 側邊欄導覽 === */
.sidebar-nav {
  flex-grow: 1;
  overflow-y: auto;
  overflow-x: hidden;
  padding-right: 0.5rem;
}

.sidebar-nav::-webkit-scrollbar {
  width: 4px;
}

.sidebar-nav::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.1);
  border-radius: 10px;
}

.sidebar-nav h3 {
  font-size: 0.75rem;
  font-weight: 700;
  color: var(--text-secondary);
  margin-bottom: 0.75rem;
  margin-top: 0.5rem;
  opacity: 0.7;
}

.divider {
  height: 1px;
  background: var(--panel-border);
  margin: 1.25rem 0;
}

.nav-list {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.nav-list li {
  padding: 0.65rem 1rem;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
  color: var(--text-secondary);
  font-size: 0.9rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  min-height: 44px;
  /* a11y 觸控目標 */
}

.nav-list li:hover {
  background: var(--panel-border);
  color: var(--text-primary);
}

.nav-list li.active {
  background: var(--accent-glow);
  color: white;
  font-weight: 500;
}

.collection-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.list-text {
  flex-grow: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.edit-cat-btn {
  background: transparent;
  border: none;
  color: var(--text-secondary);
  opacity: 0.45;
  /* 永遠可見，手機上不需要 hover 才能點擊 */
  cursor: pointer;
  padding: 5px 6px;
  border-radius: 6px;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 30px;
  min-height: 30px;
  /* a11y 觸控目標大小 */
  flex-shrink: 0;
}

.collection-item:hover .edit-cat-btn {
  opacity: 0.8;
}

.edit-cat-btn:hover,
.edit-cat-btn:active {
  opacity: 1 !important;
  color: var(--accent-color);
  background: rgba(99, 102, 241, 0.12);
}

.color-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  display: inline-block;
  flex-shrink: 0;
  opacity: 0.9;
}

.add-category-btn {
  width: 100%;
  padding: 0.65rem;
  margin-top: 1rem;
  background: transparent;
  border: 1px dashed var(--text-secondary);
  color: var(--text-secondary);
  border-radius: 8px;
  font-size: 0.85rem;
  transition: all 0.2s;
  min-height: 44px;
}

.add-category-btn:hover {
  border-color: var(--accent-color);
  color: var(--accent-color);
  background: rgba(99, 102, 241, 0.05);
}

.sidebar-footer {
  margin-top: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.logout-btn {
  width: 100%;
  padding: 0.85rem;
  background: rgba(255, 255, 255, 0.05);
  color: var(--text-primary);
  border-radius: 10px;
  font-weight: 500;
  min-height: 44px;
}

.logout-btn:hover {
  background: rgba(244, 63, 94, 0.2);
  color: #f43f5e;
}

/* === 主畫面 === */
.main-content {
  flex-grow: 1;
  display: flex;
  flex-direction: column;
  padding: 1rem 1rem 1rem 0;
  overflow: hidden;
  position: relative;
  min-width: 0;
}

.main-header {
  padding: 0.75rem 1.25rem;
  border-radius: 16px;
  margin-bottom: 1.25rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-shrink: 0;
}

/* 漢堡按鈕：桌面隱藏、手機顯示 */
.hamburger-btn {
  display: none;
  /* PC 上隱藏 */
  background: rgba(255, 255, 255, 0.07);
  border: 1px solid var(--panel-border);
  color: var(--text-primary);
  border-radius: 8px;
  padding: 0.6rem;
  min-width: 42px;
  min-height: 44px;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

/* 批次管理 icon 按鈕：純 icon，固定 40×44px，永遠不超出畫面 */
.batch-icon-btn {
  background: rgba(255, 255, 255, 0.07);
  border: 1px solid var(--panel-border);
  color: var(--text-secondary);
  border-radius: 8px;
  width: 40px;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  transition: all 0.2s;
}

.batch-icon-btn:hover {
  color: var(--accent-color);
  background: rgba(99, 102, 241, 0.12);
  border-color: var(--accent-color);
}

.batch-icon-btn:active {
  transform: scale(0.94);
}

.hamburger-btn:hover {
  background: rgba(255, 255, 255, 0.15);
}

.add-link-form {
  display: flex;
  gap: 0.75rem;
  flex-grow: 1;
}

.add-link-form input {
  flex-grow: 1;
  background: rgba(0, 0, 0, 0.2);
  border: 1px solid var(--panel-border);
  font-size: 1rem;
  min-width: 0;
}

.add-link-form input:focus {
  background: rgba(0, 0, 0, 0.4);
}

.add-link-form input:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.add-btn {
  background: var(--accent-color);
  color: white;
  padding: 0 1.25rem;
  border-radius: 8px;
  font-weight: 600;
  white-space: nowrap;
  flex-shrink: 0;
  min-height: 44px;
}

.add-btn:hover:not(:disabled) {
  background: var(--accent-hover);
  transform: translateY(-1px);
}

.add-btn:active:not(:disabled) {
  transform: translateY(1px);
}

.add-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.batch-mode-btn {
  padding: 0.65rem 1rem;
  background: rgba(255, 255, 255, 0.05);
  color: var(--text-primary);
  border-radius: 8px;
  font-weight: 500;
  white-space: nowrap;
  border: 1px solid transparent;
  transition: all 0.2s;
  flex-shrink: 0;
  min-height: 44px;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.batch-label-desktop {
  display: inline;
}

.batch-icon-mobile {
  display: none;
}

.batch-mode-btn:hover {
  background: var(--panel-border);
}

.batch-mode-btn.active {
  background: rgba(244, 63, 94, 0.1);
  color: #f43f5e;
  border-color: rgba(244, 63, 94, 0.3);
}

/* ─── 批次模式 header 元件 ─── */

.batch-left {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  flex-shrink: 0;
}

.cancel-batch-btn {
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid var(--panel-border);
  color: var(--text-primary);
  border-radius: 8px;
  width: 38px;
  height: 38px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: background 0.2s;
  flex-shrink: 0;
}

.cancel-batch-btn:hover,
.cancel-batch-btn:active {
  background: rgba(244, 63, 94, 0.15);
  color: #f43f5e;
}

.batch-count {
  font-size: 0.9rem;
  color: var(--text-secondary);
  white-space: nowrap;
}

.batch-count strong {
  color: var(--text-primary);
  font-size: 1rem;
}

.batch-right {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex: 1;
  min-width: 0;
  justify-content: flex-end;
}

.batch-select-inline {
  background: rgba(0, 0, 0, 0.25);
  border: 1px solid var(--panel-border);
  color: white;
  padding: 0 0.6rem;
  border-radius: 8px;
  outline: none;
  font-family: inherit;
  font-size: 0.9rem;
  height: 38px;
  flex: 1;
  min-width: 0;
  max-width: 200px;
  cursor: pointer;
}

.batch-select-inline:focus {
  border-color: var(--accent-color);
}

.batch-select-inline option {
  background: var(--bg-gradient-end);
  color: white;
}

/* === 連結列表 === */
.links-container {
  flex-grow: 1;
  overflow-y: auto;
  overflow-x: hidden;
  padding-right: 0.5rem;
  padding-bottom: 6rem;
  -webkit-overflow-scrolling: touch;
  /* iOS 慣性滾動 */
  overscroll-behavior-y: contain;
  /* 防止觸發瀏覽器的下拉刷新 */
}

.links-container::-webkit-scrollbar {
  width: 6px;
}

.links-container::-webkit-scrollbar-track {
  background: transparent;
}

.links-container::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.1);
  border-radius: 10px;
}

.section-title {
  margin-bottom: 1.25rem;
  font-weight: 600;
  letter-spacing: -0.5px;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.title-platform {
  color: var(--text-primary);
}

.title-separator {
  color: var(--text-secondary);
  opacity: 0.5;
}

.title-collection {
  color: var(--accent-color);
  background: rgba(99, 102, 241, 0.1);
  padding: 0.2rem 0.6rem;
  border-radius: 6px;
  font-size: 0.95em;
}

.batch-title-hint {
  font-size: 0.85rem;
  color: var(--text-secondary);
  font-weight: normal;
}

.links-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1.25rem;
  padding-bottom: 1rem;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 260px;
  border-radius: 16px;
  gap: 1rem;
  opacity: 0.6;
}

.empty-state .icon {
  font-size: 3rem;
}

.loading-state {
  padding-top: 3rem;
  text-align: center;
  color: var(--text-secondary);
  font-size: 1.1rem;
}

/* === 批次操作工具列 === */
.batch-action-bar {
  position: absolute;
  bottom: 1.25rem;
  left: 50%;
  transform: translateX(-50%);
  width: 92%;
  max-width: 600px;
  background: rgba(15, 23, 42, 0.95);
  backdrop-filter: blur(16px);
  padding: 0.85rem 1.25rem;
  border-radius: 99px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.5);
  border: 1px solid var(--accent-glow);
  z-index: 100;
  gap: 0.75rem;
}

@keyframes slideUp {
  from {
    opacity: 0;
    transform: translate(-50%, 20px);
  }

  to {
    opacity: 1;
    transform: translate(-50%, 0);
  }
}

.animate-slide-up {
  animation: slideUp 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards;
}

.batch-info {
  font-size: 0.9rem;
  color: var(--text-secondary);
  white-space: nowrap;
}

.batch-info strong {
  color: white;
  font-size: 1rem;
}

.batch-controls {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.batch-select {
  background: rgba(0, 0, 0, 0.3);
  border: 1px solid var(--panel-border);
  color: white;
  padding: 0.4rem 0.75rem;
  border-radius: 8px;
  outline: none;
  font-family: inherit;
  font-size: 0.9rem;
}

.batch-select:focus {
  border-color: var(--accent-color);
}

.batch-select option {
  background: var(--bg-gradient-end);
  color: white;
}

.confirm-batch-btn {
  background: var(--accent-color);
  color: white;
  padding: 0.45rem 1.1rem;
  border-radius: 8px;
  font-weight: 500;
  white-space: nowrap;
  font-size: 0.9rem;
}

.confirm-batch-btn:hover:not(:disabled) {
  background: var(--accent-hover);
}

.confirm-batch-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

/* ============================================
   手機版 RWD (768px 以下)
   ============================================ */
@media (max-width: 768px) {

  /* 遮罩：手機上顯示，但預設不擋觸碰 */
  .sidebar-overlay {
    display: block;
    pointer-events: none;
  }

  /* 只有開啟側邊欄時才允許觸碰（用來點擊關閉） */
  .sidebar-overlay.active {
    opacity: 1;
    pointer-events: auto;
  }

  /* 側邊欄：手機上隱藏、滑動開啟 */
  .sidebar {
    position: fixed;
    left: 0;
    top: 0;
    height: 100vh;
    margin: 0;
    border-radius: 0 20px 20px 0;
    z-index: 300;
    transform: translateX(-110%);
    width: 280px;
  }

  .sidebar.sidebar-open {
    transform: translateX(0);
  }

  /* 主畫面：手機上填滿整個寬度 */
  .main-content {
    padding: 0.75rem;
    padding-bottom: 0;
  }

  /* Header 調整 */
  .main-header {
    margin-bottom: 1rem;
    padding: 0.65rem 0.75rem;
    border-radius: 12px;
    gap: 0.5rem;
  }

  /* 漢堡按鈕：手機上顯示 */
  .hamburger-btn {
    display: flex;
  }

  /* 輸入框在手機上縮短佔位文字已在 HTML 改過了 */
  .add-link-form input {
    font-size: 0.9rem;
  }

  .add-btn {
    padding: 0 0.85rem;
    font-size: 0.9rem;
  }

  /* 批次按鈕：手機只顯示 icon */
  .batch-label-desktop {
    display: none;
  }

  .batch-icon-mobile {
    display: block;
  }

  .batch-mode-btn {
    padding: 0.65rem 0.75rem;
    min-width: 42px;
  }

  /* 卡片格線：手機單欄 */
  .links-grid {
    grid-template-columns: 1fr;
    gap: 0.85rem;
  }

  /* 批次工具列：手機分區塊式設計 */
  .batch-action-bar {
    /* 重置為基本排版，手機重建 */
    flex-direction: column;
    border-radius: 20px;
    bottom: 1rem;
    left: 1rem;
    right: 1rem;
    width: auto;
    /* 不要用 % width + translateX，改用 left/right 區大小 */
    transform: none;
    /* 覆寫掉桌面版的 translateX(-50%) */
    max-width: none;
    padding: 1rem;
    gap: 0.85rem;
    animation: slideUp-mobile 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  @keyframes slideUp-mobile {
    from {
      opacity: 0;
      transform: translateY(20px);
    }

    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  /* 已選筆數：區塊占滿寬 */
  .batch-info {
    width: 100%;
    text-align: center;
    font-size: 1rem;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  }

  /* 標籤選擇 + 確認按鈕：占滿寬並排 */
  .batch-controls {
    width: 100%;
    flex-wrap: nowrap;
    gap: 0.6rem;
  }

  /* 下拉選單充滿剰餘空間 */
  .batch-select {
    flex: 1;
    min-width: 0;
    font-size: 0.92rem;
    padding: 0.55rem 0.6rem;
    height: 44px;
    /* 手機觸控最小高度 */
  }

  /* 確認按鈕固定寬度，不被沪縮 */
  .confirm-batch-btn {
    flex-shrink: 0;
    padding: 0 1rem;
    height: 44px;
    font-size: 0.92rem;
  }

  .section-title {
    font-size: 1rem;
  }
}

/* ============================================
   Toast 通知
   ============================================ */
.toast-container {
  position: fixed;
  bottom: 1.5rem;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  z-index: 9999;
  pointer-events: none;
}

.toast {
  background: rgba(30, 30, 50, 0.92);
  backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.12);
  color: #fff;
  padding: 0.7rem 1.2rem;
  border-radius: 40px;
  font-size: 0.9rem;
  font-weight: 500;
  white-space: nowrap;
  box-shadow: 0 6px 24px rgba(0, 0, 0, 0.4);
  letter-spacing: 0.01em;
}

.toast.error {
  border-color: rgba(239, 68, 68, 0.4);
  background: rgba(80, 20, 20, 0.92);
}

/* toast 動畫 */
.toast-anim-enter-active {
  animation: toast-in 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
}

.toast-anim-leave-active {
  animation: toast-out 0.25s ease forwards;
}

@keyframes toast-in {
  from {
    opacity: 0;
    transform: translateY(12px) scale(0.9);
  }

  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

@keyframes toast-out {
  from {
    opacity: 1;
    transform: translateY(0) scale(1);
  }

  to {
    opacity: 0;
    transform: translateY(8px) scale(0.95);
  }
}
</style>
