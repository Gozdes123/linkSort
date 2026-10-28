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
  const name = prompt('🍄 請輸入新關卡/分類名稱 (例如：關卡道具、攻略秘技、影音收藏)：', defaultName)
  if (name && name.trim() !== '') {
    const trimmed = name.trim()
    if (!customCategories.value.includes(trimmed) && trimmed !== '全部收藏' && trimmed !== '未分類') {
      customCategories.value.push(trimmed)
      await addCategoryToDB(trimmed)
      showToast(`🍄 已新增分類標籤「${trimmed}」`)
      return trimmed
    } else {
      alert('這個分類已經存在或名稱無法使用囉！')
    }
  }
  return null
}

// 從 Supabase 抓取資料（本機開發模式載入高擬真像素風測試資料）
const fetchLinks = async () => {
  isLoadingInitial.value = true

  if (isDevUser.value) {
    customCategories.value = ['🎮 攻略秘技', '🍄 道具清單', '⭐ 影音精選', '🏰 閱讀筆記']
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
        title: '🍄 2026 超人氣復古像素遊戲美術與地圖關卡設計大賞！',
        category: 'Instagram',
        custom_category: '未分類',
        created_at: new Date(Date.now() - 1000 * 60 * 30).toISOString(),
        description: '精選 10 款極致 NES 與 16-bit 像素藝術傑作，從色彩搭配到瓦片地圖完整解析！',
        thumbnail_url: null,
      },
      {
        id: 'mock-3',
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        title: '⭐ Super Mario Bros. 復古 8-Bit 像素音效與配樂創作幕後秘辛',
        category: 'YouTube',
        custom_category: '未分類',
        created_at: new Date(Date.now() - 1000 * 60 * 60).toISOString(),
        description: '近藤浩治經典遊戲音樂解析：方波、三角波與白噪聲如何譜寫傳奇冒險樂章。',
        thumbnail_url: null,
      },
      {
        id: 'mock-4',
        url: 'https://www.dcard.tw/f/tech/p/250000000',
        title: '🎮 軟體工程師求職面試經驗分享：系統架構與前端性能優化',
        category: 'Dcard',
        custom_category: '未分類',
        created_at: new Date(Date.now() - 1000 * 60 * 120).toISOString(),
        description: '分享今年在各大科技廠的面試題庫與準備心得，給想轉職的冒險者參考～',
        thumbnail_url: null,
      },
      {
        id: 'mock-5',
        url: 'https://x.com/shadcn/status/178000000000',
        title: '🏰 Retro Pixel UI System: Chunky borders, hard shadows and 8-bit styling',
        category: 'X',
        custom_category: '🎮 攻略秘技',
        created_at: new Date(Date.now() - 1000 * 60 * 240).toISOString(),
        description: 'Beautiful 8-bit retro components built for modern web applications.',
        thumbnail_url: null,
      },
      {
        id: 'mock-6',
        url: 'https://github.com/features/actions',
        title: '⭐ GitHub Actions: Automate your workflow from idea to production',
        category: '其他來源',
        custom_category: '🍄 道具清單',
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
    Threads: '#000000',
    Instagram: '#e52521',
    Dcard: '#0088cc',
    YouTube: '#e52521',
    X: '#0066cc',
  }
  return colors[platform] || '#9933cc'
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
    showToast(`⭐ 成功收藏新連結${targetCollection !== '未分類' ? '至「' + targetCollection + '」' : ''}！`)
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
      showToast('🍄 捷徑新增成功！正在抓取標題...')
    } else {
      showToast(`⭐ 成功收藏新連結${targetCollection !== '未分類' ? '至「' + targetCollection + '」' : ''}！`)
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
    showToast(`🎀 已歸類到「${newCategory}」`, 'success', {
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
    showToast('🗑️ 已刪除連結')
    return
  }

  const { error } = await supabase.from('links').delete().eq('id', id)
  if (!error) {
    links.value = links.value.filter(link => link.id !== id)
    if (selectedLinks.value.has(id)) {
      selectedLinks.value.delete(id)
    }
    showToast('🗑️ 已刪除連結')
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

  showToast(`✨ 已將 ${count} 筆連結移至「${targetCategory}」`, 'success', {
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
  const newTitle = prompt('🌸 請輸入新的標題：', oldTitle)
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

const editCustomCategory = async (oldName) => {
  if (oldName === '未分類' || oldName === '全部收藏') return

  const newName = prompt(`為「${oldName}」輸入新的可愛名稱：`, oldName)
  if (!newName || newName.trim() === '' || newName === oldName) return

  const trimmedNewName = newName.trim()
  if (customCategories.value.includes(trimmedNewName)) {
    alert('這個標籤名稱已經存在囉！')
    return
  }

  if (!isDevUser.value) {
    const { error } = await supabase
      .from('links')
      .update({ custom_category: trimmedNewName })
      .eq('custom_category', oldName)
      .eq('user_id', props.user.id)

    if (error) {
      alert('更新標籤失敗：' + error.message)
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

const deleteCustomCategory = async (catName) => {
  if (catName === '未分類' || catName === '全部收藏') return

  const confirmDelete = confirm(`確定要刪除標籤「${catName}」嗎？\n\n注意：此標籤下的連結將會被移至「未分類」。`)
  if (!confirmDelete) return

  if (!isDevUser.value) {
    const { error } = await supabase
      .from('links')
      .update({ custom_category: '未分類' })
      .eq('custom_category', catName)
      .eq('user_id', props.user.id)

    if (error) {
      alert('刪除標籤失敗：' + error.message)
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
  showToast(`已刪除標籤「${catName}」`)
}

const copySessionToken = async () => {
  try {
    const { data: { session } } = await supabase.auth.getSession()
    if (session) {
      await navigator.clipboard.writeText(JSON.stringify(session))
      showToast('🌸 已複製登入 Token！可直接在 localhost 點「貼上 Token」登入')
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
      <span>🍄 目前處於「8-BIT 像素冒險預覽模式 (含測試資料)」，所有操作即時反應但不會影響雲端真實資料 ⭐</span>
    </div>

    <!-- 像素 RPG 對話框 Toast 通知區域 -->
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

    <!-- 側邊導覽列 (Mario 像素方塊風格) -->
    <aside class="sidebar glass-panel" :class="{ 'sidebar-open': isSidebarOpen }">
      <div class="sidebar-header">
        <div class="logo">
          <span class="logo-icon">🍄</span>
          <h2>LinkSort</h2>
        </div>
        <p class="user-greeting">
          冒險者：{{ user.user_metadata?.display_name || user.email?.split('@')[0] || 'MARIO' }} ⭐
          <span v-if="isDevUser" class="dev-tag">DEV</span>
        </p>
      </div>

      <div class="sidebar-nav">
        <!-- 母分類 -->
        <h3>🎮 冒險世界 (來源)</h3>
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
        <h3>📦 道具箱標籤</h3>
        <ul class="nav-list collection-list">
          <!-- 全部收藏 -->
          <li :class="{ active: activeCollection === '全部收藏' }" @click="selectCollection('全部收藏')">
            <span class="list-text">⭐ 全部收藏</span>
            <span class="nav-count">{{ categoryCounts.total }}</span>
          </li>

          <!-- 未分類（待整理專區） -->
          <li :class="{ active: activeCollection === '未分類' }" @click="selectCollection('未分類')">
            <span class="list-text">❓ 待整理收件匣</span>
            <span class="nav-count" :class="{ 'has-unread': categoryCounts.uncategorized > 0 }">
              {{ categoryCounts.uncategorized }}
            </span>
          </li>

          <!-- 各使用者自訂分類 -->
          <li v-for="cat in customCategories" :key="cat" :class="{ active: activeCollection === cat }"
            class="collection-item">
            <span class="list-text" @click="selectCollection(cat)">🏷️ {{ cat }}</span>
            <span class="nav-count" @click="selectCollection(cat)">{{ categoryCounts.custom[cat] || 0 }}</span>
            <div class="category-actions">
              <button class="edit-cat-btn" @click.stop="editCustomCategory(cat)" title="編輯標籤名稱">
                ✏️
              </button>
              <button class="delete-cat-btn" @click.stop="deleteCustomCategory(cat)" title="刪除標籤">
                🗑️
              </button>
            </div>
          </li>
        </ul>
        <button class="add-category-btn" @click="createCustomCategory()">
          <span>+</span> 新增道具箱標籤 🍄
        </button>
      </div>

      <div class="sidebar-footer">
        <button v-if="!isDevUser" class="copy-token-btn" @click="copySessionToken" title="複製登入 Token">
          📋 複製 Token (本機同步)
        </button>
        <button class="logout-btn" @click="handleLogout">
          {{ isDevUser ? '結束預覽模式' : '離開遊戲 (登出)' }}
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
              stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <line x1="3" y1="12" x2="21" y2="12"></line>
              <line x1="3" y1="6" x2="21" y2="6"></line>
              <line x1="3" y1="18" x2="21" y2="18"></line>
            </svg>
          </button>

          <!-- 連續快速新增表單 -->
          <div class="add-link-form">
            <div class="target-category-indicator" :title="'儲存時將自動分類至：' + (activeCollection !== '全部收藏' ? activeCollection : '未分類')">
              <span>{{ activeCollection !== '全部收藏' ? '📦 ' + activeCollection : '❓ 未分類' }}</span>
            </div>
            <input 
              ref="addInputRef"
              type="url" 
              v-model="newUrl" 
              placeholder="貼上冒險連結，按 Enter 快速收藏 🍄..." 
              @keyup.enter="addLink(false)" 
              :disabled="isAdding"
            />
            <button class="add-btn" @click="addLink(false)" :disabled="isAdding || !newUrl.trim()">
              {{ isAdding ? '抓取中...' : '⭐ 收藏' }}
            </button>
          </div>
        </template>

        <!-- ===== 批次模式 ===== -->
        <template v-else>
          <div class="batch-left">
            <button class="cancel-batch-btn" @click="toggleBatchMode" title="離開批次管理">
              ✕
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
              放入道具箱 🍄
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

          <!-- 快速切換「待整理」與「全部收藏」像素方塊頁籤 -->
          <div class="view-mode-tabs" v-if="!isBatchMode">
            <button 
              type="button" 
              class="mode-tab-btn" 
              :class="{ 'active': activeCollection === '未分類' }"
              @click="selectCollection('未分類')"
              title="待整理收件匣：分類後立即移出此畫面"
            >
              <span class="tab-icon">❓</span>
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
              <span class="tab-icon">⭐</span>
              <span>全部收藏</span>
              <span class="tab-count">{{ categoryCounts.total }}</span>
            </button>
          </div>
        </div>

        <!-- 待整理模式下的 Mario 像素橫幅 -->
        <div class="triage-status-banner" v-if="activeCollection === '未分類' && filteredLinks.length > 0">
          <span class="banner-icon">❓</span>
          <span class="banner-text">
            <strong>【待整理收件匣】進行中：</strong>
            為卡片選取分類後會<strong>立即彈跳移出此畫面</strong>，讓您能連續收納下一筆！（所有卡片均安全保存在「⭐ 全部收藏」中）
          </span>
        </div>

        <div v-if="isLoadingInitial" class="loading-state">
          <div class="pixel-spinner"></div>
          <p>正在讀取世界地圖與道具庫 🍄...</p>
        </div>
        <div v-else>
          <!-- 切換類別時使用平滑 view-fade -->
          <transition name="view-fade" mode="out-in">
            <div :key="activePlatform + '_' + activeCollection">
              <!-- 卡片格線（原地縮小淡出，無橫向突兀滑動） -->
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

              <!-- 待整理全部完成慶祝狀態 (Inbox Zero -> STAGE CLEAR) -->
              <div class="empty-state glass-panel empty-inbox" v-else-if="activeCollection === '未分類'">
                <span class="empty-icon">🏁</span>
                <h3>⭐ STAGE CLEAR! 關卡全破！ ⭐</h3>
                <p>目前「待整理收件匣」已經全部分類完畢，所有道具與超連結均整齊歸位！🍄</p>
                <button class="empty-action-btn" @click="selectCollection('全部收藏')">
                  ⭐ 查看全部收藏 ({{ categoryCounts.total }})
                </button>
              </div>

              <!-- 一般條件無資料狀態 -->
              <div class="empty-state glass-panel" v-else>
                <span class="empty-icon">🧱</span>
                <p>「{{ activePlatform }} / {{ activeCollection }}」目前沒有任何道具卡片！</p>
                <button class="empty-action-btn" @click="selectCollection('全部收藏')">
                  返回全部收藏 ⭐
                </button>
              </div>
            </div>
          </transition>
        </div>
      </div>
    </main>

    <!-- 浮動批次管理按鈕 (Mario 無敵星星像素方塊) -->
    <button class="floating-batch-btn" :class="{ 'active-mode': isBatchMode }" @click="toggleBatchMode"
      :title="isBatchMode ? '完成管理' : '批次管理'">
      <span v-if="!isBatchMode" class="btn-bubble-icon">⭐</span>
      <span v-else class="cancel-text">完成</span>
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
  background: var(--mario-brick);
  color: #fff;
  font-size: 0.82rem;
  font-weight: 800;
  text-align: center;
  padding: 0.35rem 1rem;
  z-index: 1000;
  border-bottom: 2px solid #000000;
}

/* === 側邊欄遮罩（手機用）=== */
.sidebar-overlay {
  display: none;
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  z-index: 200;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.2s ease;
}

/* === 側邊欄 (Mario 像素控制板 - 暗色版) === */
.sidebar {
  width: 275px;
  height: calc(100vh - 2rem);
  margin: 1rem;
  border-radius: 4px;
  display: flex;
  flex-direction: column;
  padding: 1.3rem;
  flex-shrink: 0;
  background: #202533;
  border: 3px solid #000000;
  box-shadow: 6px 6px 0px #000000;
  transition: transform 0.25s steps(6);
}

.sidebar-header {
  margin-bottom: 1.1rem;
}

.logo {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  margin-bottom: 0.35rem;
}

.logo-icon {
  background: var(--mario-red);
  color: #fff;
  width: 38px;
  height: 38px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 4px;
  font-size: 1.3rem;
  border: 2px solid #000000;
  box-shadow: 3px 3px 0px #000000;
}

.logo h2 {
  font-size: 1.5rem;
  margin: 0;
  color: var(--mario-red);
  font-weight: 900;
  text-shadow: 1px 1px 0px var(--mario-yellow), 2px 2px 0px #000000;
  letter-spacing: 1px;
}

.user-greeting {
  font-size: 0.82rem;
  color: var(--text-secondary);
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-weight: 700;
}

.dev-tag {
  background: var(--mario-yellow);
  border: 1px solid #000000;
  color: #000000;
  font-size: 0.68rem;
  padding: 0.05rem 0.35rem;
  border-radius: 2px;
  font-weight: 900;
}

/* === 側邊欄導覽 === */
.sidebar-nav {
  flex-grow: 1;
  overflow-y: auto;
  overflow-x: hidden;
  padding-right: 0.35rem;
}

.sidebar-nav::-webkit-scrollbar {
  width: 6px;
}

.sidebar-nav::-webkit-scrollbar-thumb {
  background: #000000;
  border-radius: 0;
}

.sidebar-nav h3 {
  font-size: 0.78rem;
  font-weight: 900;
  color: #fcd116;
  margin-bottom: 0.65rem;
  margin-top: 0.5rem;
  letter-spacing: 0.5px;
}

.divider {
  height: 3px;
  background: #000000;
  margin: 1rem 0;
}

.nav-list {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.nav-list li {
  padding: 0.5rem 0.75rem;
  border-radius: 3px;
  cursor: pointer;
  transition: transform 0.08s ease, background 0.08s ease;
  color: #cbd5e1;
  font-size: 0.88rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  min-height: 38px;
  font-weight: 700;
  border: 2px solid transparent;
}

.nav-list li:hover {
  background: #2d3448;
  color: var(--mario-yellow);
  border-color: #000000;
  transform: translate(2px, 0);
}

.nav-list li.active {
  background: var(--mario-red);
  color: #ffffff;
  border: 2px solid #000000;
  box-shadow: 3px 3px 0px #000000;
  transform: translate(2px, 0);
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

/* 數量統計像素標籤 */
.nav-count {
  font-size: 0.74rem;
  background: #161922;
  padding: 0.1rem 0.45rem;
  border-radius: 2px;
  color: #cbd5e1;
  font-weight: 900;
  margin-left: auto;
  border: 1px solid #000000;
}

.nav-list li.active .nav-count {
  background: var(--mario-yellow);
  color: #000000;
}

.nav-count.has-unread {
  background: var(--mario-yellow);
  color: #000000;
  border: 1px solid #000000;
  animation: coinBlink 1.2s infinite ease-in-out;
}

@keyframes coinBlink {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.1); }
}

.category-actions {
  display: flex;
  gap: 3px;
  margin-left: 0.3rem;
}

.edit-cat-btn,
.delete-cat-btn {
  background: #161922;
  border: 1px solid #000000;
  font-size: 0.75rem;
  cursor: pointer;
  padding: 2px;
  border-radius: 2px;
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 22px;
  min-height: 22px;
  flex-shrink: 0;
  transition: transform 0.08s ease;
  color: #cbd5e1;
}

.edit-cat-btn:hover,
.delete-cat-btn:hover {
  background: var(--mario-yellow);
  color: #000;
  transform: scale(1.15);
}

.color-dot {
  width: 10px;
  height: 10px;
  border-radius: 1px;
  display: inline-block;
  flex-shrink: 0;
  border: 1.5px solid #000000;
}

.add-category-btn {
  width: 100%;
  padding: 0.6rem;
  margin-top: 0.85rem;
  background: #161922;
  border: 2px dashed #475569;
  color: var(--mario-yellow);
  border-radius: 3px;
  font-size: 0.84rem;
  font-weight: 900;
  transition: all 0.1s;
  min-height: 38px;
}

.add-category-btn:hover {
  background: #272d3e;
  border-color: #000000;
  border-style: solid;
}

.sidebar-footer {
  margin-top: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
}

.copy-token-btn {
  width: 100%;
  padding: 0.55rem;
  background: #161922;
  border: 2px solid #000000;
  box-shadow: 2px 2px 0px #000000;
  color: #cbd5e1;
  border-radius: 3px;
  font-size: 0.78rem;
  font-weight: 800;
}

.copy-token-btn:hover {
  background: #272d3e;
  color: var(--mario-yellow);
}

.logout-btn {
  width: 100%;
  padding: 0.65rem;
  background: #2a1619;
  color: #f87171;
  border: 2px solid #000000;
  box-shadow: 2px 2px 0px #000000;
  border-radius: 3px;
  font-weight: 900;
  font-size: 0.85rem;
  min-height: 38px;
}

.logout-btn:hover {
  background: var(--mario-red);
  color: #ffffff;
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
  padding: 0.7rem 1.1rem;
  border-radius: 4px;
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-shrink: 0;
  background: #202533;
  border: 3px solid #000000;
  box-shadow: 4px 4px 0px #000000;
}

.hamburger-btn {
  display: none;
  background: #161922;
  border: 2px solid #000000;
  box-shadow: 2px 2px 0px #000000;
  color: #cbd5e1;
  border-radius: 3px;
  padding: 0.5rem;
  min-width: 38px;
  min-height: 38px;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.hamburger-btn:hover {
  background: #272d3e;
  color: var(--mario-yellow);
}

/* 連續新增表單 */
.add-link-form {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  flex-grow: 1;
}

.target-category-indicator {
  display: flex;
  align-items: center;
  background: var(--mario-yellow);
  border: 2px solid #000000;
  box-shadow: 2px 2px 0px #000000;
  border-radius: 3px;
  padding: 0 0.75rem;
  height: 40px;
  font-size: 0.82rem;
  font-weight: 900;
  color: #000000;
  white-space: nowrap;
  user-select: none;
  flex-shrink: 0;
}

.add-link-form input {
  flex-grow: 1;
  min-width: 0;
  height: 40px;
  font-size: 0.92rem;
  border: 2px solid #000000;
  border-radius: 3px;
  background: #161922;
  color: #f1f5f9;
  padding: 0 0.75rem;
  font-family: inherit;
  font-weight: 700;
}

.add-link-form input:focus {
  outline: none;
  border-color: var(--mario-red);
  box-shadow: 2px 2px 0px var(--mario-red);
  background: #1a1e2a;
}

.add-btn {
  background: var(--mario-red);
  color: #ffffff;
  padding: 0 1.25rem;
  border-radius: 3px;
  font-weight: 900;
  white-space: nowrap;
  flex-shrink: 0;
  height: 40px;
  border: 2px solid #000000;
  box-shadow: 3px 3px 0px #000000;
}

.add-btn:hover:not(:disabled) {
  background: #c41e1a;
  transform: translate(-1px, -1px);
  box-shadow: 4px 4px 0px #000000;
}

.add-btn:active:not(:disabled) {
  transform: translate(2px, 2px) !important;
  box-shadow: 1px 1px 0px #000000 !important;
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
  background: #161922;
  border: 2px solid #000000;
  box-shadow: 2px 2px 0px #000000;
  color: #f87171;
  border-radius: 3px;
  width: 34px;
  height: 34px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.95rem;
  font-weight: 900;
  cursor: pointer;
  flex-shrink: 0;
}

.cancel-batch-btn:hover {
  background: var(--mario-red);
  color: #fff;
}

.batch-count {
  font-size: 0.88rem;
  color: #cbd5e1;
  white-space: nowrap;
  font-weight: 700;
}

.batch-count strong {
  color: var(--mario-yellow);
  font-size: 1.05rem;
}

.select-all-btn {
  background: #161922;
  border: 2px solid #000000;
  box-shadow: 2px 2px 0px #000000;
  color: #cbd5e1;
  font-size: 0.8rem;
  font-weight: 800;
  padding: 0.3rem 0.65rem;
  border-radius: 3px;
  cursor: pointer;
  white-space: nowrap;
}

.select-all-btn:hover {
  background: #272d3e;
  color: var(--mario-yellow);
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
  background: #161922;
  border: 2px solid #000000;
  color: #f1f5f9;
  padding: 0 0.7rem;
  border-radius: 3px;
  outline: none;
  font-family: inherit;
  font-size: 0.88rem;
  height: 36px;
  flex: 1;
  min-width: 0;
  max-width: 180px;
  cursor: pointer;
  font-weight: 700;
}

.confirm-batch-btn {
  background: var(--mario-green);
  color: white;
  padding: 0.4rem 1.1rem;
  border-radius: 3px;
  font-weight: 900;
  white-space: nowrap;
  font-size: 0.88rem;
  border: 2px solid #000000;
  box-shadow: 3px 3px 0px #000000;
}

.confirm-batch-btn:hover:not(:disabled) {
  background: #008f00;
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
  width: 8px;
}

.links-container::-webkit-scrollbar-thumb {
  background: #000000;
  border-radius: 0;
}

.section-title-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  flex-wrap: wrap;
  gap: 0.75rem;
}

/* 主要模式切換 Mario 像素方塊頁籤 (暗色) */
.view-mode-tabs {
  display: flex;
  background: #161922;
  border: 3px solid #000000;
  box-shadow: 4px 4px 0px #000000;
  border-radius: 4px;
  padding: 3px;
  gap: 4px;
}

.mode-tab-btn {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  padding: 0.45rem 0.95rem;
  border-radius: 3px;
  background: transparent;
  color: #94a3b8;
  font-size: 0.88rem;
  font-weight: 800;
  border: 2px solid transparent;
  cursor: pointer;
  transition: all 0.08s ease;
}

.mode-tab-btn:hover {
  background: #272d3e;
  color: var(--mario-yellow);
  border-color: #000000;
}

.mode-tab-btn.active {
  background: var(--mario-red);
  color: #ffffff;
  font-weight: 900;
  border: 2px solid #000000;
  box-shadow: 2px 2px 0px #000000;
}

.tab-count {
  font-size: 0.72rem;
  padding: 0.08rem 0.4rem;
  border-radius: 2px;
  background: #202533;
  color: #cbd5e1;
  border: 1px solid #000000;
  font-weight: 900;
}

.tab-count.has-badge {
  background: var(--mario-yellow);
  color: #000000;
}

.mode-tab-btn.active .tab-count {
  background: var(--mario-yellow);
  color: #000000;
}

/* 待整理提示 Mario 磚塊問號黃色橫幅 (舒適暗底發光感) */
.triage-status-banner {
  background: #28210c;
  border: 3px solid var(--mario-yellow);
  box-shadow: 4px 4px 0px #000000;
  border-radius: 4px;
  padding: 0.75rem 1.15rem;
  margin-bottom: 1.25rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  color: #fef08a;
  font-size: 0.88rem;
  line-height: 1.5;
  font-weight: 700;
}

.banner-icon {
  font-size: 1.4rem;
  flex-shrink: 0;
}

.section-title {
  font-weight: 900;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
  font-size: 1.25rem;
  margin: 0;
}

.title-platform {
  color: #f1f5f9;
}

.title-separator {
  color: var(--mario-red);
}

.title-collection {
  color: var(--mario-yellow);
  background: #161922;
  padding: 0.2rem 0.65rem;
  border-radius: 3px;
  font-size: 0.85em;
  font-weight: 900;
  border: 2px solid #000000;
  box-shadow: 2px 2px 0px #000000;
}

.links-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(310px, 1fr));
  gap: 1.25rem;
  padding-bottom: 1rem;
}

/* === 切換類別平滑淡入淡出（無橫向異常位移）=== */
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
  transition: opacity 0.2s ease, transform 0.2s ease;
}
.card-fade-leave-active {
  transition: opacity 0.18s ease, transform 0.18s ease;
}
.card-fade-enter-from {
  opacity: 0;
  transform: translateY(6px);
}
.card-fade-leave-to {
  opacity: 0;
  transform: scale(0.92);
}

/* 狀態區塊 (Mario 關卡像素狀態) */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 280px;
  border-radius: 4px;
  gap: 0.75rem;
  text-align: center;
  padding: 2.5rem;
  background: #202533;
  border: 3px solid #000000;
  box-shadow: 6px 6px 0px #000000;
}

.empty-icon {
  font-size: 3.5rem;
}

.empty-inbox h3 {
  color: var(--mario-yellow);
  font-size: 1.35rem;
  font-weight: 900;
  margin: 0;
}

.empty-inbox p {
  color: var(--text-secondary);
  max-width: 440px;
  font-size: 0.95rem;
  line-height: 1.6;
  font-weight: 700;
}

.empty-action-btn {
  margin-top: 0.85rem;
  background: var(--mario-red);
  color: #fff;
  padding: 0.65rem 1.45rem;
  border-radius: 3px;
  font-weight: 900;
  font-size: 0.92rem;
  border: 3px solid #000000;
  box-shadow: 4px 4px 0px #000000;
}

.empty-action-btn:hover {
  background: #c41e1a;
  transform: translate(-1px, -1px);
  box-shadow: 5px 5px 0px #000000;
}

.loading-state {
  padding-top: 4rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  color: #f1f5f9;
  font-weight: 800;
}

.pixel-spinner {
  width: 36px;
  height: 36px;
  background: var(--mario-yellow);
  border: 3px solid #000000;
  box-shadow: 3px 3px 0px #000000;
  animation: pixelSpin 0.8s steps(4) infinite;
}

@keyframes pixelSpin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

/* 浮動批次按鈕 (Mario 無敵星星金色方塊) */
.floating-batch-btn {
  position: fixed;
  right: 24px;
  bottom: 24px;
  width: 56px;
  height: 56px;
  border-radius: 4px;
  background: var(--mario-yellow);
  color: #000000;
  border: 3px solid #000000;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 5px 5px 0px #000000;
  z-index: 500;
  cursor: pointer;
  transition: transform 0.08s ease, box-shadow 0.08s ease;
}

.btn-bubble-icon {
  font-size: 1.6rem;
}

.floating-batch-btn:hover {
  background: #ffe04d;
  transform: translate(-2px, -2px);
  box-shadow: 7px 7px 0px #000000;
}

.floating-batch-btn.active-mode {
  background: var(--mario-red);
  color: #ffffff;
  width: 88px;
}

.cancel-text {
  font-weight: 900;
  font-size: 0.95rem;
}

/* === Toast 通知（Mario 對話方塊）=== */
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
  background: #202533;
  border: 3px solid #000000;
  color: #f1f5f9;
  padding: 0.65rem 1.15rem;
  border-radius: 4px;
  font-size: 0.88rem;
  font-weight: 800;
  white-space: nowrap;
  box-shadow: 5px 5px 0px #000000;
  display: inline-flex;
  align-items: center;
  gap: 0.75rem;
  pointer-events: auto;
}

.toast.error {
  border-color: #000000;
  background: #2a1619;
  color: #f87171;
}

.toast-action-btn {
  background: var(--mario-green);
  color: #fff;
  font-weight: 900;
  font-size: 0.8rem;
  padding: 0.2rem 0.65rem;
  border-radius: 3px;
  cursor: pointer;
  border: 2px solid #000000;
  box-shadow: 2px 2px 0px #000000;
}

.toast-action-btn:hover {
  background: #008f00;
}

.toast-anim-enter-active {
  animation: toast-in 0.15s ease-out;
}
.toast-anim-leave-active {
  animation: toast-out 0.15s ease-in forwards;
}

@keyframes toast-in {
  from { opacity: 0; transform: translateY(14px) scale(0.9); }
  to { opacity: 1; transform: translateY(0) scale(1); }
}

@keyframes toast-out {
  from { opacity: 1; transform: translateY(0) scale(1); }
  to { opacity: 0; transform: translateY(8px) scale(0.95); }
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
    border-radius: 0 4px 4px 0;
    z-index: 300;
    transform: translateX(-110%);
    width: 285px;
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
    border-radius: 4px;
    gap: 0.5rem;
  }

  .hamburger-btn {
    display: flex;
  }

  .target-category-indicator {
    display: none;
  }

  .add-link-form input {
    font-size: 0.85rem;
  }

  .add-btn {
    padding: 0 0.85rem;
    font-size: 0.85rem;
  }

  .links-grid {
    grid-template-columns: 1fr;
    gap: 0.85rem;
  }

  .section-title {
    font-size: 1.05rem;
  }

  .floating-batch-btn {
    right: 16px;
    bottom: 20px;
    width: 50px;
    height: 50px;
  }
}
</style>
