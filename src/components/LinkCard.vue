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

const handleDocumentClick = (e) => {
  if (isCategoryMenuOpen.value && popoverRef.value && !popoverRef.value.contains(e.target)) {
    closeCategoryMenu()
  }
}

const toggleCategoryMenu = () => {
  if (props.selectable) return
  isCategoryMenuOpen.value = !isCategoryMenuOpen.value
  if (isCategoryMenuOpen.value) {
    document.addEventListener('click', handleDocumentClick)
  } else {
    document.removeEventListener('click', handleDocumentClick)
  }
}

const closeCategoryMenu = () => {
  if (isCategoryMenuOpen.value) {
    isCategoryMenuOpen.value = false
    document.removeEventListener('click', handleDocumentClick)
  }
}

const selectCategory = (cat) => {
  emit('updateCategory', props.link.id, cat)
  closeCategoryMenu()
}

const handleCreateCategory = () => {
  closeCategoryMenu()
  emit('createCategory', props.link.id)
}

onUnmounted(() => {
  document.removeEventListener('click', handleDocumentClick)
})

// 馬力歐像素經典配色
const siteColors = {
  Threads: '#000000',
  Instagram: '#e52521',
  Dcard: '#0088cc',
  YouTube: '#e52521',
  X: '#0066cc',
  '其他來源': '#9933cc'
}

const badgeColor = computed(() => siteColors[props.link.category] || '#9933cc')

// 高效輕量月日擷取 (避免 700+ 物件反覆 new Date 與 toLocaleDateString)
const displayDate = computed(() => {
  const raw = props.link.created_at
  if (!raw) return ''
  if (raw.length >= 10 && raw[4] === '-' && raw[7] === '-') {
    const month = parseInt(raw.slice(5, 7), 10)
    const day = parseInt(raw.slice(8, 10), 10)
    if (!isNaN(month) && !isNaN(day)) {
      return `${month}/${day}`
    }
  }
  const date = new Date(raw)
  return isNaN(date) ? '' : `${date.getMonth() + 1}/${date.getDate()}`
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
    <!-- 像素選取打勾標記 -->
    <div v-if="selectable && selected" class="selected-overlay">
      <div class="checkmark-box">
        ✓
      </div>
    </div>

    <!-- 縮圖區域 -->
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
              :title="isUncategorized ? '點擊加入分類' : '點擊更換分類'"
            >
              <span class="badge-icon">{{ isUncategorized ? '❓' : '🍄' }}</span>
              <span class="badge-text">{{ isUncategorized ? '未分類' : link.custom_category }}</span>
              <span class="badge-arrow">▼</span>
            </button>

            <!-- 像素對話框彈出選單 (RPG 對話框風格) -->
            <transition name="popover-anim">
              <div v-if="isCategoryMenuOpen" class="category-popover">
                <div class="popover-title">▶ 選擇目標分類</div>
                <div class="popover-list">
                  <button 
                    type="button" 
                    class="popover-item" 
                    :class="{ 'is-active': isUncategorized }"
                    @click="selectCategory('未分類')"
                  >
                    <span class="popover-icon">❓</span>
                    <span class="popover-name">未分類</span>
                    <span v-if="isUncategorized" class="popover-check">★</span>
                  </button>

                  <button 
                    v-for="cat in categories" 
                    :key="cat" 
                    type="button" 
                    class="popover-item"
                    :class="{ 'is-active': link.custom_category === cat }"
                    @click="selectCategory(cat)"
                  >
                    <span class="popover-icon">🍄</span>
                    <span class="popover-name">{{ cat }}</span>
                    <span v-if="link.custom_category === cat" class="popover-check">★</span>
                  </button>
                </div>

                <div class="popover-divider"></div>

                <button type="button" class="popover-add-btn" @click="handleCreateCategory">
                  <span>+</span> 新增標籤...
                </button>
              </div>
            </transition>
          </div>
        </div>
        <span class="date">{{ displayDate }}</span>
      </div>

      <div class="card-body">
        <h3 class="title" :class="{ 'is-loading': isLoadingTitle }">
          <span v-if="isLoadingTitle" class="loading-shimmer">⌛ 抓取關卡資訊中...</span>
          <span v-else>{{ link.title }}</span>
        </h3>
        <p class="description" v-if="link.description && !isLoadingTitle">{{ link.description }}</p>
        <a :href="link.url" target="_blank" class="url" @click="selectable && $event.preventDefault()">
          🔗 {{ link.url }}
        </a>
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
            <span>{{ isUncategorized ? '❓ 待分類' : '🍄 ' + link.custom_category }}</span>
          </button>
        </div>
        <div class="footer-right">
          <button class="action-btn edit-btn" title="編輯標題" @click.stop="emit('edit', link.id, link.title)">
            ✏️
          </button>
          <button class="action-btn copy-btn" title="複製網址" @click.stop="copyLink">
            📋
          </button>
          <button class="action-btn delete-btn" title="刪除項目" @click.stop="emit('delete', link.id)">
            💣
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
  transition: transform 0.1s ease, box-shadow 0.1s ease;
  position: relative;
  overflow: visible;
  padding: 0;
  border-radius: 4px;
  background: #202533;
  border: 3px solid #000000;
  box-shadow: 4px 4px 0px #000000;
}

/* 頂部像素色條 */
.link-card:not(.has-thumbnail):before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 6px;
  background: v-bind(badgeColor);
  z-index: 2;
  border-bottom: 2px solid #000000;
}

.link-card:hover:not(.is-selectable) {
  transform: translate(-2px, -2px);
  box-shadow: 6px 6px 0px #000000;
}

.is-selectable {
  cursor: pointer;
  user-select: none;
}

.is-selectable:hover {
  background: #272d3e;
}

.is-selected {
  border-color: #000000;
  background: #262920;
  box-shadow: 4px 4px 0px #fcd116;
}

/* 像素選取標記 */
.selected-overlay {
  position: absolute;
  inset: 0;
  background: rgba(252, 209, 22, 0.15);
  z-index: 10;
  pointer-events: none;
  display: flex;
  align-items: flex-start;
  justify-content: flex-end;
  padding: 0.65rem;
}

.checkmark-box {
  width: 28px;
  height: 28px;
  background: #00a800;
  border: 2px solid #000000;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 900;
  font-size: 1.1rem;
  box-shadow: 2px 2px 0px #000000;
}

/* 縮圖區域 */
.thumbnail-wrapper {
  width: 100%;
  height: 165px;
  overflow: hidden;
  position: relative;
  flex-shrink: 0;
  background: #141720;
  border-bottom: 3px solid #000000;
}

.thumbnail {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.card-content {
  display: flex;
  flex-direction: column;
  padding: 1rem;
  gap: 0.65rem;
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

/* 像素標籤徽章 */
.category-badge {
  font-size: 0.75rem;
  font-weight: 700;
  padding: 0.2rem 0.55rem;
  border-radius: 2px;
  color: #fff;
  border: 2px solid #000000;
  box-shadow: 2px 2px 0px #000000;
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  white-space: nowrap;
}

.category-picker-wrapper {
  position: relative;
  display: inline-block;
}

/* 快速分類按鈕（馬力歐問號磚塊 / 水管蘑菇風格） */
.custom-badge-btn {
  background: #00a800;
  color: #ffffff;
  cursor: pointer;
  transition: transform 0.08s ease;
}

.custom-badge-btn:hover {
  transform: translate(-1px, -1px);
  box-shadow: 3px 3px 0px #000000;
}

.custom-badge-btn:active {
  transform: translate(1px, 1px);
  box-shadow: 1px 1px 0px #000000;
}

.custom-badge-btn.is-uncategorized {
  background: #fcd116;
  color: #000000;
}

.badge-arrow {
  font-size: 0.6rem;
}

/* 像素 RPG 對話框選單 (暗色地底/酒吧風格) */
.category-popover {
  position: absolute;
  top: calc(100% + 6px);
  left: 0;
  width: 200px;
  max-height: 250px;
  background: #1a1e29;
  border: 3px solid #000000;
  border-radius: 2px;
  box-shadow: 5px 5px 0px #000000;
  z-index: 100;
  padding: 0.4rem;
  display: flex;
  flex-direction: column;
}

.popover-title {
  font-size: 0.78rem;
  color: #fcd116;
  font-weight: 700;
  padding: 0.3rem 0.4rem;
  border-bottom: 2px dashed #334155;
  margin-bottom: 0.3rem;
}

.popover-list {
  display: flex;
  flex-direction: column;
  gap: 3px;
  overflow-y: auto;
  max-height: 150px;
}

.popover-list::-webkit-scrollbar {
  width: 4px;
}

.popover-list::-webkit-scrollbar-thumb {
  background: #000000;
}

.popover-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 0.5rem;
  border-radius: 2px;
  background: transparent;
  color: #f1f5f9;
  font-size: 0.82rem;
  font-weight: 700;
  text-align: left;
  border: none;
  cursor: pointer;
  transition: all 0.08s;
  width: 100%;
}

.popover-item:hover {
  background: #272d3e;
  color: #fcd116;
}

.popover-item.is-active {
  background: #e52521;
  color: #ffffff;
}

.popover-name {
  flex-grow: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.popover-check {
  font-size: 0.8rem;
  color: #fcd116;
}

.popover-divider {
  height: 2px;
  background: #334155;
  margin: 0.35rem 0;
}

.popover-add-btn {
  background: #161922;
  border: 2px solid #000000;
  color: #fcd116;
  padding: 0.35rem;
  border-radius: 2px;
  font-size: 0.78rem;
  font-weight: 700;
  box-shadow: 2px 2px 0px #000000;
  cursor: pointer;
  width: 100%;
}

.popover-add-btn:hover {
  background: #272d3e;
}

.popover-anim-enter-active,
.popover-anim-leave-active {
  transition: opacity 0.1s ease, transform 0.1s ease;
}

.popover-anim-enter-from {
  opacity: 0;
  transform: translateY(-4px);
}
.popover-anim-leave-to {
  opacity: 0;
}

.date {
  font-size: 0.75rem;
  color: #64748b;
  font-weight: 700;
  white-space: nowrap;
}

.card-body {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.title {
  font-size: 0.98rem;
  font-weight: 700;
  color: #f8fafc;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.45;
}

.description {
  font-size: 0.82rem;
  color: #94a3b8;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.45;
}

.url {
  font-size: 0.78rem;
  color: #38bdf8;
  text-decoration: none;
  word-break: break-all;
  display: -webkit-box;
  -webkit-line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
  font-weight: 700;
}

.url:hover {
  text-decoration: underline;
}

.loading-shimmer {
  color: #fcd116;
  font-weight: 700;
}

.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.5rem;
  margin-top: auto;
  border-top: 2px dashed #334155;
  padding-top: 0.7rem;
}

.footer-left {
  display: flex;
  align-items: center;
  min-width: 0;
}

.footer-quick-tag {
  background: #161922;
  border: 2px solid #000000;
  color: #f1f5f9;
  font-size: 0.76rem;
  font-weight: 700;
  padding: 0.25rem 0.55rem;
  border-radius: 2px;
  box-shadow: 2px 2px 0px #000000;
  cursor: pointer;
  max-width: 140px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.footer-quick-tag:hover {
  background: #fcd116;
  color: #000000;
  transform: translate(-1px, -1px);
  box-shadow: 3px 3px 0px #000000;
}

.footer-quick-tag.needs-tag {
  background: #fcd116;
  color: #000000;
}

.footer-right {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  flex-shrink: 0;
}

.action-btn {
  background: #161922;
  border: 2px solid #000000;
  box-shadow: 2px 2px 0px #000000;
  border-radius: 2px;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.95rem;
  cursor: pointer;
  color: #f1f5f9;
}

.action-btn:hover {
  background: #fcd116;
  color: #000000;
  transform: translate(-1px, -1px);
  box-shadow: 3px 3px 0px #000000;
}

.delete-btn:hover {
  background: #e52521;
  color: #ffffff;
}
</style>
