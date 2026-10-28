<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import LinkCard from './LinkCard.vue'
import { supabase } from '../lib/supabase'

const props = defineProps({
  user: {
    type: Object,
    required: true
  }
})

const isDevUser = computed(() => props.user.id === 'dev-user')

// 母分類 (固定的社群平台)
const platforms = ['全部來源', 'Threads', 'Instagram', 'Dcard', 'YouTube', 'X', '其他來源']
const activePlatform = ref('全部來源')

// 子分類 (自訂我的收藏) - 預設優先進入「未分類」，讓待整理項目立即呈現
const customCategories = ref([])
const activeCollection = ref('未分類')

const links = ref([])
const newUrl = ref('')
const isLoadingInitial = ref(true)
const isAdding = ref(false)
const addInputRef = ref(null)

// 批次管理相關狀態
const isBatchMode = ref(false)
const selectedLinks = ref(new Set())
const batchTargetCategory = ref('未分類')

// Toast 通知系統
const toasts = ref([]) // [{ id, message, type, action }]
let toastCounter = 0
const showToast = (message, type = 'success', action = null) => {
  const id = ++toastCounter
  toasts.value.push({ id, message, type, action })
  setTimeout(() => {
    toasts.value = toasts.value.filter(t => t.id !== id)
  }, action ? 4500 : 3200)
}

// 統計各類別數量
const categoryCounts = computed(() => {
  const counts = {
    total: links.value.length,
    uncategorized: 0,
    custom: {},
    platforms: {
      '全部來源': links.value.length,
      'Threads': 0,
      'Instagram': 0,
      'Dcard': 0,
      'YouTube': 0,
      'X': 0,
      '其他來源': 0,
    }
  }

  const knownPlatforms = ['Threads', 'Instagram', 'Dcard', 'YouTube', 'X']

  links.value.forEach(link => {
    if (knownPlatforms.includes(link.category)) {
      counts.platforms[link.category] = (counts.platforms[link.category] || 0) + 1
    } else {
      counts.platforms['其他來源'] = (counts.platforms['其他來源'] || 0) + 1
    }

    const cat = link.custom_category || '未分類'
    if (cat === '未分類') {
      counts.uncategorized++
    } else {
      counts.custom[cat] = (counts.custom[cat] || 0) + 1
    }
  })

  return counts
})

// 從 Supabase 載入使用者的自訂分類
const loadCustomCategories = async () => {
  if (isDevUser.value) return

  const { data, error } = await supabase
    .from('custom_categories')
    .select('name')
    .eq('user_id', props.user.id)

  if (!error && data) {
    customCategories.value = data.map(c => c.name)
  }
}

// 儲存新的自訂分類到 Supabase
const addCategoryToDB = async (name) => {
  if (isDevUser.value) return
  await supabase.from('custom_categories').insert([
    { user_id: props.user.id, name: name }
  ])
}

const deleteCategoryFromDB = async (name) => {
  if (isDevUser.value) return
  await supabase.from('custom_categories').delete()
    .eq('user_id', props.user.id)
    .eq('name', name)
}

const createCustomCategory = async (defaultName = '') => {
  const name = prompt('請輸入新分類名稱 (例如：設計靈感、工作用)：', defaultName)
  if (name && name.trim() !== '') {
    const trimmed = name.trim()
    if (!customCategories.value.includes(trimmed) && trimmed !== '全部收藏' && trimmed !== '未分類') {
      customCategories.value.push(trimmed)
      await addCategoryToDB(trimmed)
      showToast(`已建立新分類「${trimmed}」`)
      return trimmed
    } else {
      alert('這個分類已經存在或名稱無法使用囉！')
    }
  }
  return null
}

// 從 Supabase 抓取資料（本機開發模式載入高擬真測試資料）
const fetchLinks = async () => {
  isLoadingInitial.value = true

  if (isDevUser.value) {
    customCategories.value = ['設計靈感', '實用工具', '美食餐廳', '影音收藏']
    links.value = [
      {
        id: 'mock-1',
        url: 'https://www.threads.net/@zuck/post/12345',
        title: 'Mark Zuckerberg: Building open source AI foundation models',
        category: 'Threads',
        custom_category: '未分類',
        created_at: new Date(Date.now() - 1000 * 60 * 10).toISOString(),
        description: 'Latest updates on open-weights foundation models and future roadmap.',
        thumbnail_url: null,
      },
      {
        id: 'mock-2',
        url: 'https://www.instagram.com/p/C3abcde123',
        title: '2026 台北捷運周邊超人氣甜點地圖推薦',
        category: 'Instagram',
        custom_category: '未分類',
        created_at: new Date(Date.now() - 1000 * 60 * 30).toISOString(),
        description: '精選 10 間捷運步行 5 分鐘內抵達的法式千層與戚風蛋糕！',
        thumbnail_url: null,
      },
      {
        id: 'mock-3',
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        title: 'Vue 3 高性能動畫與響應式系統深度解析實戰',
        category: 'YouTube',
        custom_category: '未分類',
        created_at: new Date(Date.now() - 1000 * 60 * 60).toISOString(),
        description: '帶你從源碼角度理解 TransitionGroup 與 FLIP 動畫實作細節。',
        thumbnail_url: null,
      },
      {
        id: 'mock-4',
        url: 'https://www.dcard.tw/f/tech/p/250000000',
        title: '軟體工程師求職面試經驗分享：系統架構與前端性能優化',
        category: 'Dcard',
        custom_category: '未分類',
        created_at: new Date(Date.now() - 1000 * 60 * 120).toISOString(),
        description: '分享今年在各大科技廠的面試題庫與準備心得。',
        thumbnail_url: null,
      },
      {
        id: 'mock-5',
        url: 'https://x.com/shadcn/status/178000000000',
        title: 'New components added to the modern glassmorphism design system',
        category: 'X',
        custom_category: '設計靈感',
        created_at: new Date(Date.now() - 1000 * 60 * 240).toISOString(),
        description: 'Beautiful, accessible components built with Tailwind CSS and Radix UI.',
        thumbnail_url: null,
      },
      {
        id: 'mock-6',
        url: 'https://github.com/features/actions',
        title: 'GitHub Actions: Automate your workflow from idea to production',
        category: '其他來源',
        custom_category: '實用工具',
        created_at: new Date(Date.now() - 1000 * 60 * 360).toISOString(),
        description: 'CI/CD built directly into GitHub to automate your build and deploy pipelines.',
        thumbnail_url: null,
      }
    ]
    isLoadingInitial.value = false
    return
  }

  const { data, error } = await supabase
    .from('links')
    .select('*')
    .order('created_at', { ascending: false })

  if (!error && data) {
    links.value = data.map(l => ({
      ...l,
      custom_category: l.custom_category || '未分類'
    }))

    const existingCats = new Set(links.value.filter(l => l.custom_category && l.custom_category !== '未分類').map(l => l.custom_category))
    existingCats.forEach(async cat => {
      if (!customCategories.value.includes(cat)) {
        customCategories.value.push(cat)
        await addCategoryToDB(cat)
      }
    })
  }
  isLoadingInitial.value = false
}

onMounted(async () => {
  loadCustomCategories()
  await fetchLinks()

  // 若有待整理的未分類連結，自動優先停留在「未分類」，方便連續整理
  const hasUncategorized = links.value.some(l => !l.custom_category || l.custom_category === '未分類')
  activeCollection.value = hasUncategorized ? '未分類' : '全部收藏'

  const urlParams = new URLSearchParams(window.location.search);
  const sharedUrl = urlParams.get('url');

  if (sharedUrl) {
    const decodedUrl = decodeURIComponent(sharedUrl);
    newUrl.value = decodedUrl;
    setTimeout(async () => {
      console.log('捷徑自動偵測到網址，準備儲存:', newUrl.value);
      await addLink(true);
      window.history.replaceState({}, document.title, window.location.pathname);
    }, 500);
  }
})

// 雙重新篩選邏輯：同時比對平台來源和自訂子分類
const filteredLinks = computed(() => {
  let result = links.value;

  if (activePlatform.value !== '全部來源') {
    if (activePlatform.value === '其他來源') {
      const knownPlatforms = ['Threads', 'Instagram', 'Dcard', 'YouTube', 'X'];
      result = result.filter(link => !knownPlatforms.includes(link.category));
    } else {
      result = result.filter(link => link.category === activePlatform.value);
    }
  }

  if (activeCollection.value !== '全部收藏') {
    result = result.filter(link => link.custom_category === activeCollection.value);
  }

  return [...result].sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
});

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
      const fetchedTitle = json.data.title || ''
      const fetchedDesc = json.data.description || ''
      
      const isBlocked = 
        fetchedTitle.toLowerCase().includes('attention required') || 
        fetchedTitle.toLowerCase().includes('cloudflare') ||
        fetchedDesc.toLowerCase().includes('security service to protect itself from online attacks')

      if (isBlocked) {
        return {
          title: '無法取得預覽（網站安全防護）',
          description: null,
          thumbnail_url: null,
        }
      }

      return {
        title: json.data.title || null,
        description: json.data.description || null,
        thumbnail_url: json.data.image?.url || null,
      }
    }
  } catch (_) { }
  return { title: null, description: null, thumbnail_url: null }
}

// 連續快速新增連結
const addLink = async (fromShortcut = false) => {
  if (!newUrl.value || !newUrl.value.trim() || isAdding.value) return
  isAdding.value = true

  const tempUrl = newUrl.value.trim()
  const platform = parseCategory(tempUrl)
  newUrl.value = ''

  nextTick(() => {
    addInputRef.value?.focus()
  })

  const targetCollection = activeCollection.value !== '全部收藏' ? activeCollection.value : '未分類'

  const insertData = {
    url: tempUrl,
    title: '抓取標題中...',
    category: platform,
    custom_category: targetCollection,
    user_id: props.user.id,
    thumbnail_url: null,
    description: null,
  }

  if (isDevUser.value) {
    const mockItem = {
      ...insertData,
      id: 'mock-' + Date.now(),
      created_at: new Date().toISOString()
    }
    links.value.unshift(mockItem)
    isAdding.value = false
    showToast(`✅ 已新增連結${targetCollection !== '未分類' ? '至「' + targetCollection + '」' : ''}！`)
    return
  }

  const { data, error } = await supabase
    .from('links')
    .insert([insertData])
    .select()
    .single()

  isAdding.value = false

  if (error) {
    showToast('❌ 儲存失敗：' + error.message, 'error')
    return
  }

  if (data) {
    links.value.unshift(data)
    if (fromShortcut) {
      showToast('✅ 捷徑新增成功！正在抓取標題...')
    } else {
      showToast(`✅ 已新增連結${targetCollection !== '未分類' ? '至「' + targetCollection + '」' : ''}！`)
    }

    fetchOgData(tempUrl).then(async (og) => {
      const updatePayload = {
        title: og.title || '（無法取得標題）',
        description: og.description,
        thumbnail_url: og.thumbnail_url,
      }
      await supabase.from('links').update(updatePayload).eq('id', data.id)
      links.value = links.value.map(l =>
        l.id === data.id ? { ...l, ...updatePayload } : l
      )
    })
  }
}

// 單一卡片快速指派分類（連續整理核心 UX）
const updateLinkCategory = async (linkId, newCategory, options = { showToast: true }) => {
  const link = links.value.find(l => l.id === linkId)
  if (!link) return
  const oldCategory = link.custom_category || '未分類'
  if (oldCategory === newCategory) return

  // 1. 本地樂觀更新：產生全新陣列與物件，確保 Vue 響應式重新計算 filteredLinks
  links.value = links.value.map(l => {
    if (l.id === linkId) {
      return { ...l, custom_category: newCategory }
    }
    return l
  })

  // 2. 提供復原 Toast 按鈕
  if (options.showToast) {
    showToast(`已分類至「${newCategory}」`, 'success', {
      label: '復原',
      onClick: () => {
        updateLinkCategory(linkId, oldCategory, { showToast: false })
      }
    })
  }

  if (isDevUser.value) return

  // 3. 後端更新
  const { error } = await supabase
    .from('links')
    .update({ custom_category: newCategory })
    .eq('id', linkId)

  if (error) {
    // 復原
    links.value = links.value.map(l => {
      if (l.id === linkId) {
        return { ...l, custom_category: oldCategory }
      }
      return l
    })
    showToast('❌ 更新分類失敗：' + error.message, 'error')
  }
}

// 從卡片上直接建立新分類並指派
const handleCreateCategoryFromCard = async (linkId) => {
  const newName = await createCustomCategory()
  if (newName && linkId) {
    await updateLinkCategory(linkId, newName)
  }
}

const deleteLink = async (id) => {
  if (isDevUser.value) {
    links.value = links.value.filter(link => link.id !== id)
    showToast('已刪除連結')
    return
  }

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

// 批次全選 / 取消全選
const isAllSelected = computed(() => {
  if (filteredLinks.value.length === 0) return false
  return filteredLinks.value.every(l => selectedLinks.value.has(l.id))
})

const toggleSelectAll = () => {
  if (isAllSelected.value) {
    selectedLinks.value.clear()
  } else {
    filteredLinks.value.forEach(l => selectedLinks.value.add(l.id))
  }
}

// 批次移動分類：不跳轉頁面，保留在當前工作流，提供復原選項
const applyBatchCategory = async () => {
  if (selectedLinks.value.size === 0) return

  const idsToUpdate = Array.from(selectedLinks.value)
  const targetCategory = batchTargetCategory.value
  const count = idsToUpdate.length

  const previousCategories = new Map()
  links.value.forEach(l => {
    if (idsToUpdate.includes(l.id)) {
      previousCategories.set(l.id, l.custom_category || '未分類')
    }
  })

  // 本地樂觀更新
  links.value = links.value.map(link => {
    if (idsToUpdate.includes(link.id)) {
      return { ...link, custom_category: targetCategory }
    }
    return link
  })

  isBatchMode.value = false
  selectedLinks.value.clear()

  showToast(`已將 ${count} 筆連結移至「${targetCategory}」`, 'success', {
    label: '復原',
    onClick: async () => {
      links.value = links.value.map(link => {
        if (previousCategories.has(link.id)) {
          return { ...link, custom_category: previousCategories.get(link.id) }
        }
        return link
      })
      if (!isDevUser.value) {
        for (const [id, oldCat] of previousCategories.entries()) {
          await supabase.from('links').update({ custom_category: oldCat }).eq('id', id)
        }
      }
    }
  })

  if (isDevUser.value) return

  const { error } = await supabase
    .from('links')
    .update({ custom_category: targetCategory })
    .in('id', idsToUpdate)

  if (error) {
    showToast('❌ 批次移動失敗：' + error.message, 'error')
    links.value = links.value.map(link => {
      if (previousCategories.has(link.id)) {
        return { ...link, custom_category: previousCategories.get(link.id) }
      }
      return link
    })
  }
}

const editLinkTitle = async (id, oldTitle) => {
  const newTitle = prompt('請輸入新的標題：', oldTitle)
  if (newTitle !== null && newTitle.trim() !== '') {
    if (isDevUser.value) {
      links.value = links.value.map(l =>
        l.id === id ? { ...l, title: newTitle.trim() } : l
      )
      return
    }

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

// 編輯子分類名稱
const editCustomCategory = async (oldName) => {
  if (oldName === '未分類' || oldName === '全部收藏') return

  const newName = prompt(`為「${oldName}」輸入新的名稱：`, oldName)
  if (!newName || newName.trim() === '' || newName === oldName) return

  const trimmedNewName = newName.trim()
  if (customCategories.value.includes(trimmedNewName)) {
    alert('這個分類名稱已經存在囉！')
    return
  }

  if (!isDevUser.value) {
    const { error } = await supabase
      .from('links')
      .update({ custom_category: trimmedNewName })
      .eq('custom_category', oldName)
      .eq('user_id', props.user.id)

    if (error) {
      alert('更新分類名稱失敗：' + error.message)
      return
    }

    await deleteCategoryFromDB(oldName)
    await addCategoryToDB(trimmedNewName)
  }

  const idx = customCategories.value.indexOf(oldName)
  if (idx !== -1) {
    customCategories.value[idx] = trimmedNewName
  }

  links.value = links.value.map(l =>
    l.custom_category === oldName ? { ...l, custom_category: trimmedNewName } : l
  )

  if (activeCollection.value === oldName) {
    activeCollection.value = trimmedNewName
  }
}

// 刪除自訂分類
const deleteCustomCategory = async (catName) => {
  if (catName === '未分類' || catName === '全部收藏') return

  const confirmDelete = confirm(`確定要刪除分類「${catName}」嗎？\n\n注意：此分類下的所有連結將會被移至「未分類」。`)
  if (!confirmDelete) return

  if (!isDevUser.value) {
    const { error } = await supabase
      .from('links')
      .update({ custom_category: '未分類' })
      .eq('custom_category', catName)
      .eq('user_id', props.user.id)

    if (error) {
      alert('刪除分類失敗：' + error.message)
      return
    }

    await deleteCategoryFromDB(catName)
  }

  customCategories.value = customCategories.value.filter(c => c !== catName)

  links.value = links.value.map(l =>
    l.custom_category === catName ? { ...l, custom_category: '未分類' } : l
  )

  if (activeCollection.value === catName) {
    activeCollection.value = '全部收藏'
  }
  showToast(`已刪除分類「${catName}」`)
}

// 複製當前 Session Token（供從正式站貼回本機同步）
const copySessionToken = async () => {
  try {
    const { data: { session } } = await supabase.auth.getSession()
    if (session) {
      await navigator.clipboard.writeText(JSON.stringify(session))
      showToast('✅ 已複製登入 Token！可直接在 localhost 點「貼上 Token」登入')
    } else {
      showToast('目前為本機預覽模式，無正式 Token', 'error')
    }
  } catch (err) {
    showToast('複製失敗：' + err.message, 'error')
  }
}

const handleLogout = async () => {
  sessionStorage.removeItem('linksort_dev_preview')
  sessionStorage.setItem('liff_just_logged_out', 'true')
  await supabase.auth.signOut()
  window.location.reload()
}

// 手機側邊欄開關
const isSidebarOpen = ref(false)
const closeSidebar = () => { isSidebarOpen.value = false }
const openSidebar = () => { isSidebarOpen.value = true }

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
    <!-- 本機預覽提示頂條 -->
    <div v-if="isDevUser" class="dev-banner">
      <span>🛠️ 目前處於「本機預覽模式 (含測試資料)」，所有修改即時反應但不會覆蓋雲端資料</span>
    </div>

    <!-- Toast 通知區域（支援復原操作） -->
    <div class="toast-container">
      <transition-group name="toast-anim">
        <div v-for="toast in toasts" :key="toast.id" class="toast" :class="toast.type">
          <span class="toast-message">{{ toast.message }}</span>
          <button v-if="toast.action" class="toast-action-btn" @click="toast.action.onClick">
            {{ toast.action.label }}
          </button>
        </div>
      </transition-group>
    </div>

    <!-- 手機遮罩背景 -->
    <div class="sidebar-overlay" :class="{ active: isSidebarOpen }" @click="closeSidebar"></div>

    <!-- Sidebar 側邊導覽列（含即時數量統計） -->
    <aside class="sidebar glass-panel" :class="{ 'sidebar-open': isSidebarOpen }">
      <div class="sidebar-header">
        <div class="logo">
          <span class="logo-icon">🔗</span>
          <h2>LinkSort</h2>
        </div>
        <p class="user-greeting">
          哈囉，{{ user.user_metadata?.display_name || user.email?.split('@')[0] || '使用者' }}
          <span v-if="isDevUser" class="dev-tag">預覽版</span>
        </p>
      </div>

      <div class="sidebar-nav">
        <!-- 母分類 -->
        <h3>🏢 平台來源</h3>
        <ul class="nav-list platform-list">
          <li v-for="plat in platforms" :key="plat" :class="{ active: activePlatform === plat }"
            @click="selectPlatform(plat)">
            <span class="color-dot" :style="{ background: getBadgeColor(plat) }"></span>
            <span class="list-text">{{ plat }}</span>
            <span class="nav-count">{{ categoryCounts.platforms[plat] || 0 }}</span>
          </li>
        </ul>

        <div class="divider"></div>

        <!-- 子分類 -->
        <h3>📁 我的收藏標籤</h3>
        <ul class="nav-list collection-list">
          <li :class="{ active: activeCollection === '全部收藏' }" @click="selectCollection('全部收藏')">
            <span class="list-text">全部收藏</span>
            <span class="nav-count">{{ categoryCounts.total }}</span>
          </li>

          <li :class="{ active: activeCollection === '未分類' }" @click="selectCollection('未分類')">
            <span class="list-text">⚡ 未分類 (待整理)</span>
            <span class="nav-count" :class="{ 'has-unread': categoryCounts.uncategorized > 0 }">
              {{ categoryCounts.uncategorized }}
            </span>
          </li>

          <li v-for="cat in customCategories" :key="cat" :class="{ active: activeCollection === cat }"
            class="collection-item">
            <span class="list-text" @click="selectCollection(cat)">{{ cat }}</span>
            <span class="nav-count" @click="selectCollection(cat)">{{ categoryCounts.custom[cat] || 0 }}</span>
            <div class="category-actions">
              <button class="edit-cat-btn" @click.stop="editCustomCategory(cat)" title="編輯分類名稱">
                <svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none"
                  stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path>
                  <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path>
                </svg>
              </button>
              <button class="delete-cat-btn" @click.stop="deleteCustomCategory(cat)" title="刪除分類">
                <svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none"
                  stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <line x1="18" y1="6" x2="6" y2="18"></line>
                  <line x1="6" y1="6" x2="18" y2="18"></line>
                </svg>
              </button>
            </div>
          </li>
        </ul>
        <button class="add-category-btn" @click="createCustomCategory()">
          + 新增子分類標籤
        </button>
      </div>

      <div class="sidebar-footer">
        <button v-if="!isDevUser" class="copy-token-btn" @click="copySessionToken" title="複製登入 Token">
          📋 複製 Token (本機同步用)
        </button>
        <button class="logout-btn" @click="handleLogout">
          {{ isDevUser ? '結束本機預覽' : '登出' }}
        </button>
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

          <!-- 連續快速新增表單 -->
          <div class="add-link-form">
            <div class="target-category-indicator" :title="'儲存時將自動分類至：' + (activeCollection !== '全部收藏' ? activeCollection : '未分類')">
              <span>{{ activeCollection !== '全部收藏' ? '📁 ' + activeCollection : '🏷️ 未分類' }}</span>
            </div>
            <input 
              ref="addInputRef"
              type="url" 
              v-model="newUrl" 
              placeholder="貼上連結按 Enter 快速新增..." 
              @keyup.enter="addLink(false)" 
              :disabled="isAdding"
            />
            <button class="add-btn" @click="addLink(false)" :disabled="isAdding || !newUrl.trim()">
              {{ isAdding ? '新增中...' : '儲存' }}
            </button>
          </div>
        </template>

        <!-- ===== 批次模式 ===== -->
        <template v-else>
          <div class="batch-left">
            <button class="cancel-batch-btn" @click="toggleBatchMode" title="離開批次管理">
              <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none"
                stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <line x1="18" y1="6" x2="6" y2="18"></line>
                <line x1="6" y1="6" x2="18" y2="18"></line>
              </svg>
            </button>
            <span class="batch-count">
              已選 <strong>{{ selectedLinks.size }}</strong> 項
            </span>
            <button class="select-all-btn" @click="toggleSelectAll">
              {{ isAllSelected ? '取消全選' : '全選本頁' }}
            </button>
          </div>

          <div class="batch-right">
            <select v-model="batchTargetCategory" class="batch-select-inline">
              <option value="未分類">設為未分類</option>
              <option v-for="cat in customCategories" :key="cat" :value="cat">{{ cat }}</option>
            </select>
            <button class="confirm-batch-btn" @click="applyBatchCategory" :disabled="selectedLinks.size === 0">
              移動
            </button>
          </div>
        </template>

      </header>

      <div class="links-container">
        <!-- 標題欄與主要模式快速切換頁籤 -->
        <div class="section-title-bar">
          <div class="title-left">
            <h2 class="section-title">
              <span class="title-platform">{{ activePlatform }}</span>
              <span class="title-separator" v-if="activeCollection !== '全部收藏' && activeCollection !== '未分類'">/</span>
              <span class="title-collection" v-if="activeCollection !== '全部收藏' && activeCollection !== '未分類'">{{ activeCollection }}</span>
            </h2>
          </div>

          <!-- 快速切換「待整理」與「全部收藏」頁籤（讓使用者清楚掌握當前模式） -->
          <div class="view-mode-tabs" v-if="!isBatchMode">
            <button 
              type="button" 
              class="mode-tab-btn" 
              :class="{ 'active': activeCollection === '未分類' }"
              @click="selectCollection('未分類')"
              title="待整理收件匣：分類後立即移出此畫面"
            >
              <span class="tab-icon">⚡</span>
              <span>待整理</span>
              <span class="tab-count" :class="{ 'has-badge': categoryCounts.uncategorized > 0 }">
                {{ categoryCounts.uncategorized }}
              </span>
            </button>
            <button 
              type="button" 
              class="mode-tab-btn" 
              :class="{ 'active': activeCollection === '全部收藏' }"
              @click="selectCollection('全部收藏')"
              title="全部收藏：查看所有整理完成與留存的連結"
            >
              <span class="tab-icon">📁</span>
              <span>全部收藏</span>
              <span class="tab-count">{{ categoryCounts.total }}</span>
            </button>
          </div>
        </div>

        <!-- 待整理模式下的提示橫幅 -->
        <div class="triage-status-banner" v-if="activeCollection === '未分類' && filteredLinks.length > 0">
          <span class="banner-icon">🎯</span>
          <span class="banner-text">
            <strong>待整理收件匣：</strong>
            為卡片選擇分類後會<strong>立即移出此畫面</strong>，讓您順暢整理剩餘項目（整理好的連結都會完整保存在「全部收藏」中）
          </span>
        </div>

        <div v-if="isLoadingInitial" class="loading-state">
          <div class="loader-inline"></div>
          <p>載入連結中...</p>
        </div>
        <div v-else>
          <!-- 切換類別時使用平滑 view-fade，避免卡片橫向向左滑動飛躍 -->
          <transition name="view-fade" mode="out-in">
            <div :key="activePlatform + '_' + activeCollection">
              <!-- 卡片格線（原地淡入/淡出，不使用橫向移動動畫） -->
              <transition-group 
                name="card-fade" 
                tag="div" 
                class="links-grid" 
                v-if="filteredLinks.length"
              >
                <LinkCard 
                  v-for="link in filteredLinks" 
                  :key="link.id" 
                  :link="link" 
                  :categories="customCategories"
                  :selectable="isBatchMode"
                  :selected="selectedLinks.has(link.id)" 
                  @delete="deleteLink" 
                  @toggleSelect="handleToggleSelect"
                  @edit="handleEditLink" 
                  @updateCategory="updateLinkCategory"
                  @createCategory="handleCreateCategoryFromCard"
                />
              </transition-group>

              <!-- 待整理全部完成慶祝狀態 (Inbox Zero) -->
              <div class="empty-state glass-panel empty-inbox" v-else-if="activeCollection === '未分類'">
                <span class="empty-icon">🎉</span>
                <h3>太棒了！所有待整理連結已全部分類完成</h3>
                <p>未分類清單已清空，所有連結均已妥善歸類於各自標籤中！</p>
                <button class="empty-action-btn" @click="selectCollection('全部收藏')">
                  查看全部收藏 ({{ categoryCounts.total }})
                </button>
              </div>

              <!-- 一般條件無資料狀態 -->
              <div class="empty-state glass-panel" v-else>
                <span class="empty-icon">📂</span>
                <p>「{{ activePlatform }} / {{ activeCollection }}」目前沒有任何連結喔！</p>
                <button class="empty-action-btn" @click="selectCollection('全部收藏')">
                  返回全部收藏
                </button>
              </div>
            </div>
          </transition>
        </div>
      </div>
    </main>

    <!-- 浮動批次管理按鈕 -->
    <button class="floating-batch-btn" :class="{ 'active-mode': isBatchMode }" @click="toggleBatchMode"
      :title="isBatchMode ? '取消批次管理' : '開啟批次管理'">
      <svg v-if="!isBatchMode" xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <polyline points="9 11 12 14 22 4"></polyline>
        <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"></path>
      </svg>
      <span v-else class="cancel-text">取消</span>
    </button>
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

.dev-banner {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  background: linear-gradient(90deg, #6366f1, #a855f7);
  color: #fff;
  font-size: 0.78rem;
  font-weight: 500;
  text-align: center;
  padding: 0.3rem 1rem;
  z-index: 1000;
}

/* === 側邊欄遮罩（手機用）=== */
.sidebar-overlay {
  display: none;
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.55);
  backdrop-filter: blur(4px);
  z-index: 200;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.3s ease;
}

/* === 側邊欄 === */
.sidebar {
  width: 270px;
  height: calc(100vh - 2rem);
  margin: 1rem;
  border-radius: 20px;
  display: flex;
  flex-direction: column;
  padding: 1.5rem;
  flex-shrink: 0;
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.4);
  transition: transform 0.35s cubic-bezier(0.32, 0.72, 0, 1);
}

.sidebar-header {
  margin-bottom: 1.25rem;
}

.logo {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 0.4rem;
}

.logo-icon {
  background: linear-gradient(135deg, var(--accent-glow), var(--accent-hover));
  width: 38px;
  height: 38px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
  font-size: 1.25rem;
  box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3);
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
  display: flex;
  align-items: center;
  gap: 0.4rem;
}

.dev-tag {
  background: rgba(99, 102, 241, 0.2);
  border: 1px solid rgba(99, 102, 241, 0.4);
  color: #a5b4fc;
  font-size: 0.7rem;
  padding: 0.1rem 0.4rem;
  border-radius: 4px;
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
  opacity: 0.75;
  letter-spacing: 0.5px;
  text-transform: uppercase;
}

.divider {
  height: 1px;
  background: var(--panel-border);
  margin: 1.2rem 0;
}

.nav-list {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.nav-list li {
  padding: 0.55rem 0.85rem;
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.2s;
  color: var(--text-secondary);
  font-size: 0.9rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  min-height: 42px;
}

.nav-list li:hover {
  background: var(--panel-border);
  color: var(--text-primary);
}

.nav-list li.active {
  background: var(--accent-glow);
  color: white;
  font-weight: 600;
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

/* 數量統計標籤 */
.nav-count {
  font-size: 0.75rem;
  background: rgba(255, 255, 255, 0.08);
  padding: 0.15rem 0.5rem;
  border-radius: 99px;
  color: var(--text-secondary);
  font-weight: 500;
  margin-left: auto;
  transition: all 0.2s;
}

.nav-list li.active .nav-count {
  background: rgba(255, 255, 255, 0.25);
  color: #fff;
}

.nav-count.has-unread {
  background: rgba(245, 158, 11, 0.2);
  color: #fbbf24;
  border: 1px solid rgba(245, 158, 11, 0.4);
  font-weight: 600;
}

.category-actions {
  display: flex;
  gap: 2px;
  margin-left: 0.3rem;
}

.edit-cat-btn,
.delete-cat-btn {
  background: transparent;
  border: none;
  color: var(--text-secondary);
  opacity: 0.35;
  cursor: pointer;
  padding: 4px;
  border-radius: 6px;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 28px;
  min-height: 28px;
  flex-shrink: 0;
}

.collection-item:hover .edit-cat-btn,
.collection-item:hover .delete-cat-btn {
  opacity: 0.75;
}

.edit-cat-btn:hover,
.edit-cat-btn:active {
  opacity: 1 !important;
  color: var(--accent-color);
  background: rgba(99, 102, 241, 0.15);
}

.delete-cat-btn:hover,
.delete-cat-btn:active {
  opacity: 1 !important;
  color: #ef4444;
  background: rgba(239, 68, 68, 0.15);
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
  margin-top: 0.85rem;
  background: transparent;
  border: 1px dashed rgba(255, 255, 255, 0.2);
  color: var(--text-secondary);
  border-radius: 10px;
  font-size: 0.85rem;
  transition: all 0.2s;
  min-height: 42px;
}

.add-category-btn:hover {
  border-color: var(--accent-color);
  color: var(--accent-color);
  background: rgba(99, 102, 241, 0.08);
}

.sidebar-footer {
  margin-top: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
}

.copy-token-btn {
  width: 100%;
  padding: 0.65rem;
  background: rgba(99, 102, 241, 0.12);
  border: 1px solid rgba(99, 102, 241, 0.3);
  color: #a5b4fc;
  border-radius: 10px;
  font-size: 0.82rem;
  font-weight: 500;
  transition: all 0.2s;
}

.copy-token-btn:hover {
  background: rgba(99, 102, 241, 0.25);
  color: #fff;
}

.logout-btn {
  width: 100%;
  padding: 0.75rem;
  background: rgba(255, 255, 255, 0.05);
  color: var(--text-secondary);
  border-radius: 10px;
  font-weight: 500;
  font-size: 0.9rem;
  min-height: 42px;
}

.logout-btn:hover {
  background: rgba(244, 63, 94, 0.18);
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
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-shrink: 0;
}

.hamburger-btn {
  display: none;
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

.hamburger-btn:hover {
  background: rgba(255, 255, 255, 0.15);
}

/* 連續新增表單 */
.add-link-form {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  flex-grow: 1;
}

.target-category-indicator {
  display: flex;
  align-items: center;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid var(--panel-border);
  border-radius: 8px;
  padding: 0 0.75rem;
  height: 44px;
  font-size: 0.85rem;
  color: var(--text-secondary);
  white-space: nowrap;
  user-select: none;
  flex-shrink: 0;
}

.add-link-form input {
  flex-grow: 1;
  background: rgba(0, 0, 0, 0.25);
  border: 1px solid var(--panel-border);
  font-size: 0.95rem;
  min-width: 0;
  height: 44px;
}

.add-link-form input:focus {
  background: rgba(0, 0, 0, 0.45);
}

.add-btn {
  background: var(--accent-color);
  color: white;
  padding: 0 1.25rem;
  border-radius: 8px;
  font-weight: 600;
  white-space: nowrap;
  flex-shrink: 0;
  height: 44px;
}

.add-btn:hover:not(:disabled) {
  background: var(--accent-hover);
  transform: translateY(-1px);
}

.add-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* 批次管理狀態列 */
.batch-left {
  display: flex;
  align-items: center;
  gap: 0.65rem;
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

.cancel-batch-btn:hover {
  background: rgba(244, 63, 94, 0.2);
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

.select-all-btn {
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid var(--panel-border);
  color: var(--text-primary);
  font-size: 0.8rem;
  padding: 0.35rem 0.65rem;
  border-radius: 6px;
  cursor: pointer;
  white-space: nowrap;
  transition: all 0.2s;
}

.select-all-btn:hover {
  background: rgba(255, 255, 255, 0.16);
  border-color: rgba(255, 255, 255, 0.3);
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
  background: rgba(0, 0, 0, 0.35);
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

.confirm-batch-btn {
  background: var(--accent-color);
  color: white;
  padding: 0.45rem 1.15rem;
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

/* === 連結列表區域 === */
.links-container {
  flex-grow: 1;
  overflow-y: auto;
  overflow-x: hidden;
  padding-right: 0.5rem;
  padding-bottom: 6rem;
  -webkit-overflow-scrolling: touch;
  overscroll-behavior-y: contain;
}

.links-container::-webkit-scrollbar {
  width: 6px;
}

.links-container::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.12);
  border-radius: 10px;
}

.section-title-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.1rem;
  flex-wrap: wrap;
  gap: 0.75rem;
}

/* 主要模式切換頁籤 */
.view-mode-tabs {
  display: flex;
  background: rgba(0, 0, 0, 0.28);
  border: 1px solid var(--panel-border);
  border-radius: 12px;
  padding: 3px;
  gap: 3px;
}

.mode-tab-btn {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  padding: 0.45rem 0.85rem;
  border-radius: 9px;
  background: transparent;
  color: var(--text-secondary);
  font-size: 0.85rem;
  font-weight: 500;
  transition: all 0.2s;
  border: none;
  cursor: pointer;
}

.mode-tab-btn:hover {
  color: var(--text-primary);
  background: rgba(255, 255, 255, 0.06);
}

.mode-tab-btn.active {
  background: var(--accent-color);
  color: #fff;
  font-weight: 600;
  box-shadow: 0 2px 8px rgba(99, 102, 241, 0.35);
}

.tab-count {
  font-size: 0.72rem;
  padding: 0.1rem 0.45rem;
  border-radius: 99px;
  background: rgba(255, 255, 255, 0.15);
  color: #fff;
}

.tab-count.has-badge {
  background: #f59e0b;
  color: #000;
  font-weight: 700;
}

.mode-tab-btn.active .tab-count.has-badge {
  background: #fff;
  color: var(--accent-color);
}

/* 待整理提示橫幅 */
.triage-status-banner {
  background: rgba(245, 158, 11, 0.1);
  border: 1px solid rgba(245, 158, 11, 0.25);
  border-radius: 12px;
  padding: 0.65rem 1rem;
  margin-bottom: 1.1rem;
  display: flex;
  align-items: center;
  gap: 0.6rem;
  color: #fbbf24;
  font-size: 0.86rem;
  line-height: 1.4;
}

.banner-icon {
  font-size: 1.15rem;
  flex-shrink: 0;
}

.banner-text strong {
  color: #fff;
}

.section-title {
  font-weight: 600;
  letter-spacing: -0.5px;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
  font-size: 1.15rem;
  margin: 0;
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
  background: rgba(99, 102, 241, 0.12);
  padding: 0.2rem 0.6rem;
  border-radius: 6px;
  font-size: 0.95em;
}

.item-total-tag {
  font-size: 0.78rem;
  color: var(--text-secondary);
  background: rgba(255, 255, 255, 0.06);
  padding: 0.15rem 0.5rem;
  border-radius: 99px;
  font-weight: 400;
}

.batch-title-hint {
  font-size: 0.82rem;
  color: var(--text-secondary);
  font-weight: normal;
}

.links-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(310px, 1fr));
  gap: 1.25rem;
  padding-bottom: 1rem;
}

/* === 切換類別平滑淡入淡出（徹底消除橫向向左飄移動畫）=== */
.view-fade-enter-active,
.view-fade-leave-active {
  transition: opacity 0.16s ease;
}
.view-fade-enter-from,
.view-fade-leave-to {
  opacity: 0;
}

/* 單張卡片整理移出時原地縮小淡出 */
.card-fade-enter-active {
  transition: opacity 0.22s ease, transform 0.22s ease;
}
.card-fade-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}
.card-fade-enter-from {
  opacity: 0;
  transform: translateY(6px);
}
.card-fade-leave-to {
  opacity: 0;
  transform: scale(0.92);
}

/* 狀態區塊 */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 280px;
  border-radius: 16px;
  gap: 0.75rem;
  text-align: center;
  padding: 2rem;
}

.empty-icon {
  font-size: 3rem;
}

.empty-inbox h3 {
  color: var(--text-primary);
  font-size: 1.2rem;
  margin: 0;
}

.empty-inbox p {
  color: var(--text-secondary);
  max-width: 420px;
  font-size: 0.95rem;
  line-height: 1.5;
}

.empty-action-btn {
  margin-top: 0.75rem;
  background: var(--accent-color);
  color: #fff;
  padding: 0.55rem 1.25rem;
  border-radius: 10px;
  font-weight: 500;
  font-size: 0.9rem;
}

.empty-action-btn:hover {
  background: var(--accent-hover);
  transform: translateY(-1px);
}

.loading-state {
  padding-top: 4rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  color: var(--text-secondary);
}

.loader-inline {
  width: 32px;
  height: 32px;
  border: 3px solid rgba(255, 255, 255, 0.1);
  border-radius: 50%;
  border-top-color: var(--accent-color);
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* 浮動批次按鈕 */
.floating-batch-btn {
  position: fixed;
  right: 24px;
  bottom: 24px;
  width: 54px;
  height: 54px;
  border-radius: 27px;
  background: var(--accent-color);
  color: white;
  border: none;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 18px rgba(0, 0, 0, 0.35);
  z-index: 500;
  transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
  cursor: pointer;
}

.floating-batch-btn:hover {
  transform: scale(1.06);
  box-shadow: 0 6px 22px rgba(99, 102, 241, 0.4);
}

.floating-batch-btn.active-mode {
  background: #ef4444;
  width: 86px;
  border-radius: 16px;
}

.cancel-text {
  font-weight: 600;
  font-size: 0.95rem;
}

/* === Toast 通知（含復原按鈕）=== */
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
  background: rgba(22, 27, 46, 0.96);
  backdrop-filter: blur(14px);
  border: 1px solid rgba(255, 255, 255, 0.14);
  color: #fff;
  padding: 0.65rem 1.15rem;
  border-radius: 40px;
  font-size: 0.9rem;
  font-weight: 500;
  white-space: nowrap;
  box-shadow: 0 8px 28px rgba(0, 0, 0, 0.45);
  display: inline-flex;
  align-items: center;
  gap: 0.65rem;
  pointer-events: auto;
}

.toast.error {
  border-color: rgba(239, 68, 68, 0.4);
  background: rgba(80, 20, 20, 0.95);
}

.toast-action-btn {
  background: rgba(255, 255, 255, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.3);
  color: #fff;
  font-weight: 600;
  font-size: 0.8rem;
  padding: 0.2rem 0.65rem;
  border-radius: 99px;
  cursor: pointer;
  transition: all 0.15s;
}

.toast-action-btn:hover {
  background: #fff;
  color: #0f172a;
}

.toast-anim-enter-active {
  animation: toast-in 0.25s cubic-bezier(0.34, 1.56, 0.64, 1);
}
.toast-anim-leave-active {
  animation: toast-out 0.2s ease forwards;
}

@keyframes toast-in {
  from {
    opacity: 0;
    transform: translateY(12px) scale(0.92);
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

/* ============================================
   手機版 RWD (768px 以下)
   ============================================ */
@media (max-width: 768px) {
  .sidebar-overlay {
    display: block;
  }
  .sidebar-overlay.active {
    opacity: 1;
    pointer-events: auto;
  }

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

  .main-content {
    padding: 0.75rem;
    padding-bottom: 0;
  }

  .main-header {
    margin-bottom: 0.85rem;
    padding: 0.65rem 0.75rem;
    border-radius: 12px;
    gap: 0.5rem;
  }

  .hamburger-btn {
    display: flex;
  }

  .target-category-indicator {
    display: none;
  }

  .add-link-form input {
    font-size: 0.88rem;
  }

  .add-btn {
    padding: 0 0.85rem;
    font-size: 0.88rem;
  }

  .links-grid {
    grid-template-columns: 1fr;
    gap: 0.85rem;
  }

  .section-title {
    font-size: 1rem;
  }

  .floating-batch-btn {
    right: 16px;
    bottom: 20px;
    width: 50px;
    height: 50px;
  }
}
</style>
