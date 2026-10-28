<script setup>
import { computed, ref, onMounted, onUnmounted } from 'vue'

const props = defineProps({
  link: { type: Object, required: true },
  selectable: { type: Boolean, default: false },
  selected: { type: Boolean, default: false },
  categories: { type: Array, default: () => [] }
})

const emit = defineEmits(['delete', 'toggleSelect', 'edit', 'updateCategory', 'createCategory'])

const isCategoryMenuOpen = ref(false)
const popoverRef = ref(null)

const toggleCategoryMenu = () => {
  if (props.selectable) return
  isCategoryMenuOpen.value = !isCategoryMenuOpen.value
}

const closeCategoryMenu = () => {
  isCategoryMenuOpen.value = false
}

const selectCategory = (cat) => {
  emit('updateCategory', props.link.id, cat)
  closeCategoryMenu()
}

const handleCreateCategory = () => {
  closeCategoryMenu()
  emit('createCategory', props.link.id)
}

const handleDocumentClick = (e) => {
  if (isCategoryMenuOpen.value && popoverRef.value && !popoverRef.value.contains(e.target)) {
    closeCategoryMenu()
  }
}

onMounted(() => {
  document.addEventListener('click', handleDocumentClick)
})

onUnmounted(() => {
  document.removeEventListener('click', handleDocumentClick)
})

const siteColors = {
  Threads: '#000000',
  Instagram: '#e1306c',
  Dcard: '#006aa6',
  YouTube: '#ff0000',
  X: '#1da1f2',
  '其他來源': '#475569'
}

const badgeColor = computed(() => siteColors[props.link.category] || '#475569')

const displayDate = computed(() => {
  const date = new Date(props.link.created_at)
  return date.toLocaleDateString('zh-TW', { year: 'numeric', month: 'short', day: 'numeric' })
})

const copyLink = async () => {
  try {
    await navigator.clipboard.writeText(props.link.url)
  } catch (err) {
    console.error('Failed to copy text: ', err)
  }
}

const isLoadingTitle = computed(() => props.link.title === '抓取標題中...')
const isUncategorized = computed(() => !props.link.custom_category || props.link.custom_category === '未分類')
</script>

<template>
  <div class="link-card glass-panel" :class="{ 'is-selectable': selectable, 'is-selected': selected }"
    @click="selectable && emit('toggleSelect', link.id)">
    <!-- 選取時的明顯勾選標記 -->
    <div v-if="selectable && selected" class="selected-overlay">
      <div class="checkmark-circle">
        <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none"
          stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="20 6 9 17 4 12"></polyline>
        </svg>
      </div>
    </div>

    <div class="thumbnail-wrapper" v-if="link.thumbnail_url">
      <img :src="link.thumbnail_url" :alt="link.title" class="thumbnail" loading="lazy"
        @error="$event.target.style.display = 'none'" />
    </div>

    <div class="card-content">
      <!-- 平台 badge + 自訂標籤選單 + 日期 -->
      <div class="card-header">
        <div class="badges">
          <span class="category-badge platform-badge" :style="{ background: badgeColor }">
            {{ link.category }}
          </span>

          <!-- 快速分類下拉選單 -->
          <div class="category-picker-wrapper" ref="popoverRef" @click.stop>
            <button 
              type="button" 
              class="category-badge custom-badge-btn" 
              :class="{ 'is-uncategorized': isUncategorized, 'is-open': isCategoryMenuOpen }"
              @click="toggleCategoryMenu"
              :title="isUncategorized ? '點擊加入分類' : '點擊切換分類'"
            >
              <span class="badge-icon">{{ isUncategorized ? '🏷️' : '📁' }}</span>
              <span class="badge-text">{{ isUncategorized ? '未分類' : link.custom_category }}</span>
              <span class="badge-arrow">▾</span>
            </button>

            <!-- 彈出選單 -->
            <transition name="popover-anim">
              <div v-if="isCategoryMenuOpen" class="category-popover glass-panel">
                <div class="popover-title">快速指派分類</div>
                <div class="popover-list">
                  <button 
                    type="button" 
                    class="popover-item" 
                    :class="{ 'is-active': isUncategorized }"
                    @click="selectCategory('未分類')"
                  >
                    <span class="popover-icon">📂</span>
                    <span class="popover-name">未分類</span>
                    <span v-if="isUncategorized" class="popover-check">✓</span>
                  </button>

                  <button 
                    v-for="cat in categories" 
                    :key="cat" 
                    type="button" 
                    class="popover-item"
                    :class="{ 'is-active': link.custom_category === cat }"
                    @click="selectCategory(cat)"
                  >
                    <span class="popover-icon">📁</span>
                    <span class="popover-name">{{ cat }}</span>
                    <span v-if="link.custom_category === cat" class="popover-check">✓</span>
                  </button>
                </div>

                <div class="popover-divider"></div>

                <button type="button" class="popover-add-btn" @click="handleCreateCategory">
                  <span>+</span> 新增自訂分類...
                </button>
              </div>
            </transition>
          </div>
        </div>
        <span class="date">{{ displayDate }}</span>
      </div>

      <div class="card-body">
        <h3 class="title" :class="{ 'is-loading': isLoadingTitle }">
          <span v-if="isLoadingTitle" class="loading-shimmer">⏳ 正在抓取資訊...</span>
          <span v-else>{{ link.title }}</span>
        </h3>
        <p class="description" v-if="link.description && !isLoadingTitle">{{ link.description }}</p>
        <a :href="link.url" target="_blank" class="url" @click="selectable && $event.preventDefault()">{{ link.url }}</a>
      </div>

      <div class="card-footer">
        <div class="footer-left">
          <button 
            type="button" 
            class="footer-quick-tag" 
            :class="{ 'needs-tag': isUncategorized }" 
            @click.stop="toggleCategoryMenu"
            :title="isUncategorized ? '點擊加入分類' : '點擊更改分類'"
          >
            <span>{{ isUncategorized ? '⚡ 待分類' : '📁 ' + link.custom_category }}</span>
          </button>
        </div>
        <div class="footer-right">
          <button class="action-btn edit-btn" title="編輯標題" @click.stop="emit('edit', link.id, link.title)">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none"
              stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path>
              <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path>
            </svg>
          </button>
          <button class="action-btn copy-btn" title="複製連結" @click.stop="copyLink">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none"
              stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
              <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
            </svg>
          </button>
          <button class="action-btn delete-btn" title="刪除" @click.stop="emit('delete', link.id)">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none"
              stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="3 6 5 6 21 6"></polyline>
              <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
              <line x1="10" y1="11" x2="10" y2="17"></line>
              <line x1="14" y1="11" x2="14" y2="17"></line>
            </svg>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.link-card {
  display: flex;
  flex-direction: column;
  transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.25s, border-color 0.2s, opacity 0.25s;
  position: relative;
  overflow: visible; /* 允許分類 popover 超出卡片邊界 */
  padding: 0;
  border-radius: 16px;
}

/* 頂部色條 */
.link-card:not(.has-thumbnail):before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 4px;
  background: v-bind(badgeColor);
  opacity: 0.8;
  z-index: 2;
  border-top-left-radius: 16px;
  border-top-right-radius: 16px;
}

.link-card:hover:not(.is-selectable) {
  transform: translateY(-3px);
  box-shadow: 0 12px 36px rgba(0, 0, 0, 0.35);
  border-color: rgba(255, 255, 255, 0.14);
}

.is-selectable {
  cursor: pointer;
  user-select: none;
}

.is-selectable:hover {
  border-color: rgba(99, 102, 241, 0.4);
  background: rgba(255, 255, 255, 0.04);
}

.is-selected {
  border-color: var(--accent-color);
  box-shadow: 0 0 0 2px var(--accent-glow), 0 8px 30px rgba(99, 102, 241, 0.25);
  background: rgba(99, 102, 241, 0.12);
  transform: scale(0.98);
}

/* 勾選標記覆蓋層 */
.selected-overlay {
  position: absolute;
  inset: 0;
  background: rgba(99, 102, 241, 0.08);
  z-index: 10;
  pointer-events: none;
  display: flex;
  align-items: flex-start;
  justify-content: flex-end;
  padding: 0.75rem;
  border-radius: inherit;
}

.checkmark-circle {
  width: 34px;
  height: 34px;
  background: var(--accent-color);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  box-shadow: 0 3px 12px rgba(99, 102, 241, 0.6);
  animation: pop-in 0.2s cubic-bezier(0.34, 1.56, 0.64, 1) forwards;
}

@keyframes pop-in {
  from {
    transform: scale(0);
    opacity: 0;
  }
  to {
    transform: scale(1);
    opacity: 1;
  }
}

/* 縮圖區域 */
.thumbnail-wrapper {
  width: 100%;
  height: 180px;
  overflow: hidden;
  position: relative;
  flex-shrink: 0;
  background: rgba(0, 0, 0, 0.2);
  border-top-left-radius: 16px;
  border-top-right-radius: 16px;
}

.thumbnail {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
  transition: transform 0.3s ease;
}

.link-card:hover .thumbnail {
  transform: scale(1.03);
}

.card-content {
  display: flex;
  flex-direction: column;
  padding: 1.15rem;
  gap: 0.75rem;
  flex-grow: 1;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.5rem;
}

.badges {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.45rem;
}

.category-badge {
  font-size: 0.75rem;
  font-weight: 600;
  padding: 0.25rem 0.65rem;
  border-radius: 99px;
  color: #fff;
  letter-spacing: 0.3px;
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  white-space: nowrap;
}

.platform-badge {
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.3);
}

/* 快速分類按鈕 */
.category-picker-wrapper {
  position: relative;
  display: inline-block;
}

.custom-badge-btn {
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.16);
  color: var(--text-primary);
  cursor: pointer;
  transition: all 0.2s;
  padding: 0.25rem 0.6rem;
}

.custom-badge-btn:hover,
.custom-badge-btn.is-open {
  background: rgba(99, 102, 241, 0.2);
  border-color: var(--accent-color);
  color: #fff;
  transform: translateY(-1px);
}

.custom-badge-btn.is-uncategorized {
  background: rgba(245, 158, 11, 0.12);
  border: 1px dashed rgba(245, 158, 11, 0.45);
  color: #fbbf24;
}

.custom-badge-btn.is-uncategorized:hover {
  background: rgba(245, 158, 11, 0.25);
  border-style: solid;
  color: #fff;
}

.badge-arrow {
  font-size: 0.65rem;
  opacity: 0.7;
  transition: transform 0.2s;
}

.custom-badge-btn.is-open .badge-arrow {
  transform: rotate(180deg);
}

/* 彈出選單 Popover */
.category-popover {
  position: absolute;
  top: calc(100% + 6px);
  left: 0;
  width: 200px;
  max-height: 260px;
  background: rgba(20, 26, 43, 0.96);
  backdrop-filter: blur(16px);
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: 12px;
  box-shadow: 0 12px 32px rgba(0, 0, 0, 0.55), 0 0 0 1px rgba(99, 102, 241, 0.2);
  z-index: 100;
  padding: 0.4rem;
  display: flex;
  flex-direction: column;
}

.popover-title {
  font-size: 0.72rem;
  color: var(--text-secondary);
  font-weight: 600;
  padding: 0.35rem 0.5rem;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  margin-bottom: 0.3rem;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.popover-list {
  display: flex;
  flex-direction: column;
  gap: 2px;
  overflow-y: auto;
  max-height: 160px;
}

.popover-list::-webkit-scrollbar {
  width: 4px;
}

.popover-list::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.2);
  border-radius: 4px;
}

.popover-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.45rem 0.6rem;
  border-radius: 8px;
  background: transparent;
  color: var(--text-secondary);
  font-size: 0.85rem;
  text-align: left;
  border: none;
  cursor: pointer;
  transition: all 0.15s;
  width: 100%;
}

.popover-item:hover {
  background: rgba(255, 255, 255, 0.08);
  color: var(--text-primary);
}

.popover-item.is-active {
  background: var(--accent-glow);
  color: #fff;
  font-weight: 500;
}

.popover-name {
  flex-grow: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.popover-check {
  font-size: 0.8rem;
  color: #fff;
  font-weight: bold;
}

.popover-divider {
  height: 1px;
  background: rgba(255, 255, 255, 0.08);
  margin: 0.35rem 0;
}

.popover-add-btn {
  background: transparent;
  border: 1px dashed rgba(255, 255, 255, 0.2);
  color: var(--accent-color);
  padding: 0.4rem;
  border-radius: 8px;
  font-size: 0.8rem;
  font-weight: 500;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.3rem;
  cursor: pointer;
  transition: all 0.2s;
  width: 100%;
}

.popover-add-btn:hover {
  background: rgba(99, 102, 241, 0.15);
  border-color: var(--accent-color);
  color: #fff;
}

/* Popover 動畫 */
.popover-anim-enter-active {
  animation: popover-in 0.18s cubic-bezier(0.16, 1, 0.3, 1);
}
.popover-anim-leave-active {
  animation: popover-out 0.12s ease forwards;
}

@keyframes popover-in {
  from {
    opacity: 0;
    transform: translateY(-6px) scale(0.96);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

@keyframes popover-out {
  from {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
  to {
    opacity: 0;
    transform: translateY(-4px) scale(0.96);
  }
}

.date {
  font-size: 0.78rem;
  color: var(--text-secondary);
  white-space: nowrap;
  flex-shrink: 0;
}

.card-body {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.title {
  font-size: 0.98rem;
  font-weight: 600;
  color: var(--text-primary);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.4;
}

.description {
  font-size: 0.84rem;
  color: var(--text-secondary);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.5;
}

.url {
  font-size: 0.8rem;
  color: var(--accent-color);
  text-decoration: none;
  word-break: break-all;
  display: -webkit-box;
  -webkit-line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
  opacity: 0.75;
  transition: opacity 0.2s;
}

.url:hover {
  opacity: 1;
  text-decoration: underline;
}

/* 載入中的閃爍動畫 */
@keyframes shimmer {
  0% { opacity: 0.6; }
  50% { opacity: 1; }
  100% { opacity: 0.6; }
}

.loading-shimmer {
  animation: shimmer 1.5s ease-in-out infinite;
  color: var(--text-secondary);
  font-weight: 400;
  font-size: 0.88rem;
}

.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.5rem;
  margin-top: auto;
  border-top: 1px solid var(--panel-border);
  padding-top: 0.75rem;
}

.footer-left {
  display: flex;
  align-items: center;
  min-width: 0;
}

.footer-quick-tag {
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.08);
  color: var(--text-secondary);
  font-size: 0.76rem;
  padding: 0.25rem 0.55rem;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s;
  max-width: 140px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.footer-quick-tag:hover {
  background: rgba(99, 102, 241, 0.15);
  color: var(--accent-color);
  border-color: rgba(99, 102, 241, 0.3);
}

.footer-quick-tag.needs-tag {
  color: #fbbf24;
  border-color: rgba(245, 158, 11, 0.25);
  background: rgba(245, 158, 11, 0.06);
}

.footer-right {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  flex-shrink: 0;
}

.action-btn {
  background: rgba(255, 255, 255, 0.05);
  border-radius: 6px;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-secondary);
  transition: all 0.2s;
  border: none;
  cursor: pointer;
}

.action-btn:hover {
  background: var(--panel-border);
  color: var(--text-primary);
}

.delete-btn:hover {
  background: rgba(239, 68, 68, 0.2);
  color: #ef4444;
}
</style>
