<script setup>
import { computed } from 'vue'

const props = defineProps({
  link: { type: Object, required: true },
  selectable: { type: Boolean, default: false },
  selected: { type: Boolean, default: false }
})

const emit = defineEmits(['delete', 'toggleSelect', 'edit'])

const siteColors = {
  Threads: '#000000',
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
</script>

<template>
  <div 
    class="link-card glass-panel animate-fade-in" 
    :class="{ 'is-selectable': selectable, 'is-selected': selected }"
    @click="selectable && emit('toggleSelect', link.id)"
  >
    <!-- 選取時的明顯勾選標記 -->
    <div v-if="selectable && selected" class="selected-overlay">
      <div class="checkmark-circle">
        <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
      </div>
    </div>

    <div class="thumbnail-wrapper" v-if="link.thumbnail_url">
      <img 
        :src="link.thumbnail_url" 
        :alt="link.title"
        class="thumbnail"
        loading="lazy"
        @error="$event.target.style.display='none'"
      />
    </div>

    <div class="card-content">
      <!-- 平台 badge + 自訂標籤 + 日期：全部卡片通用，不管有沒有縮圖 -->
      <div class="card-header">
        <div class="badges">
          <span class="category-badge platform-badge" :style="{ background: badgeColor }">
            {{ link.category }}
          </span>
          <span 
            class="category-badge custom-badge" 
            v-if="link.custom_category && link.custom_category !== '未分類'"
          >
            📁 {{ link.custom_category }}
          </span>
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
        <button class="action-btn edit-btn" title="編輯標題" @click.stop="emit('edit', link.id, link.title)">
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>
        </button>
        <button class="action-btn copy-btn" title="複製連結" @click.stop="copyLink">
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>
        </button>
        <button class="action-btn delete-btn" title="刪除" @click.stop="emit('delete', link.id)">
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path><line x1="10" y1="11" x2="10" y2="17"></line><line x1="14" y1="11" x2="14" y2="17"></line></svg>
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.link-card {
  display: flex;
  flex-direction: column;
  transition: transform 0.2s, box-shadow 0.2s, border-color 0.2s;
  position: relative;
  overflow: hidden;
  padding: 0;
}

/* 只在沒有縮圖時，才在頂部顯示色條 */
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
}

.link-card:hover:not(.is-selectable) {
  transform: translateY(-4px);
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.4);
}

.is-selectable {
  cursor: pointer;
  user-select: none; /* 防止長按選到文字 */
}

.is-selectable:hover {
  border-color: rgba(99, 102, 241, 0.4);
  background: rgba(255, 255, 255, 0.04);
}

.is-selected {
  border-color: var(--accent-color);
  box-shadow: 0 0 0 2px var(--accent-glow), 0 8px 30px rgba(99, 102, 241, 0.25);
  background: rgba(99, 102, 241, 0.12);
  transform: scale(0.98); /* 輕微縮小，有按下去的感覺 */
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
  from { transform: scale(0); opacity: 0; }
  to   { transform: scale(1); opacity: 1; }
}

/* 縮圖區域 */
.thumbnail-wrapper {
  width: 100%;
  height: 180px;
  overflow: hidden;
  position: relative;
  flex-shrink: 0;
  background: rgba(0,0,0,0.2);
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

.platform-badge-overlay {
  position: absolute;
  top: 0.75rem;
  right: 0.75rem;
  font-size: 0.7rem;
  font-weight: 700;
  padding: 0.2rem 0.6rem;
  border-radius: 99px;
  color: #fff;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  text-shadow: 0 1px 2px rgba(0,0,0,0.5);
  box-shadow: 0 2px 8px rgba(0,0,0,0.3);
  z-index: 5;
}

.card-content {
  display: flex;
  flex-direction: column;
  padding: 1.25rem;
  gap: 0.75rem;
  flex-grow: 1;
  transition: padding-left 0.2s;
}

.card-content.shifted {
  padding-left: 3rem;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 0.5rem;
}

.thumbnail-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.badges {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.category-badge {
  font-size: 0.75rem;
  font-weight: 600;
  padding: 0.25rem 0.75rem;
  border-radius: 99px;
  color: #fff;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  text-shadow: 0 1px 2px rgba(0,0,0,0.3);
}

.custom-badge {
  background: rgba(255, 255, 255, 0.12);
  border: 1px solid rgba(255, 255, 255, 0.2);
  color: var(--text-primary);
  text-shadow: none;
}

.date {
  font-size: 0.8rem;
  color: var(--text-secondary);
  white-space: nowrap;
  flex-shrink: 0;
}

.card-body {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.title {
  font-size: 1rem;
  font-weight: 500;
  color: var(--text-primary);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.4;
}

.description {
  font-size: 0.85rem;
  color: var(--text-secondary);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.5;
}

.url {
  font-size: 0.85rem;
  color: var(--accent-color);
  text-decoration: none;
  word-break: break-all;
  display: -webkit-box;
  -webkit-line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
  opacity: 0.7;
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
  font-size: 0.9rem;
}

.card-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
  margin-top: auto;
  border-top: 1px solid var(--panel-border);
  padding-top: 0.75rem;
}

.action-btn {
  background: rgba(255,255,255, 0.05);
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
