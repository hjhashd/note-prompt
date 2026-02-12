<template>
  <div class="skeleton-card">
    <div class="skeleton-header">
      <div class="skeleton-icon pulse"></div>
      <div class="skeleton-actions pulse"></div>
    </div>
    <div class="skeleton-body">
      <div class="skeleton-tag pulse"></div>
      <div class="skeleton-title pulse"></div>
      <div class="skeleton-desc pulse"></div>
      <div class="skeleton-desc short pulse"></div>
    </div>
    <div class="skeleton-footer">
      <div class="skeleton-author">
        <div class="skeleton-avatar pulse"></div>
        <div class="skeleton-name pulse"></div>
      </div>
      <div class="skeleton-stats pulse"></div>
    </div>
  </div>
</template>

<style scoped>
.skeleton-card {
  background: var(--bg-surface);
  border-radius: var(--radius-lg);
  border: 1px solid rgba(0,0,0,0.04);
  padding: 20px;
  height: 100%;
  display: flex;
  flex-direction: column;
}

.pulse {
  background: linear-gradient(90deg, #f0f0f0 25%, #f8f8f8 50%, #f0f0f0 75%);
  background-size: 200% 100%;
  animation: pulse 1.5s infinite;
  border-radius: 4px;
}

@keyframes pulse {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

.skeleton-header {
  display: flex;
  justify-content: space-between;
  margin-bottom: 16px;
}

.skeleton-icon {
  width: 48px;
  height: 48px;
  border-radius: 12px;
}

.skeleton-actions {
  width: 24px;
  height: 24px;
  border-radius: 50%;
}

.skeleton-body {
  flex: 1;
  margin-bottom: 20px;
}

.skeleton-tag {
  width: 60px;
  height: 20px;
  border-radius: 10px;
  margin-bottom: 12px;
}

.skeleton-title {
  width: 80%;
  height: 24px;
  margin-bottom: 12px;
}

.skeleton-desc {
  width: 100%;
  height: 16px;
  margin-bottom: 8px;
}

.skeleton-desc.short {
  width: 60%;
}

.skeleton-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 16px;
  border-top: 1px solid var(--border-subtle);
}

.skeleton-author {
  display: flex;
  align-items: center;
  gap: 8px;
}

.skeleton-avatar {
  width: 24px;
  height: 24px;
  border-radius: 50%;
}

.skeleton-name {
  width: 80px;
  height: 16px;
}

.skeleton-stats {
  width: 100px;
  height: 16px;
}
</style>
