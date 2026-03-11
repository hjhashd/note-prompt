# 我的提示词卡片样式更新记录

**日期**: 2025-03-09  
**修改人**: AI Assistant

## 修改概述

对 `MyPromptsView.vue` 页面中的提示词卡片进行了样式和功能调整，主要包括：
1. 移除点赞按钮的高亮色
2. 替换右下角按钮为分享按钮
3. 添加支持部门选择的分享功能
4. 修复卡片底部按钮位置不一致的问题

---

## 详细修改内容

### 1. PromptList.vue - 新增 `isMyPrompts` 属性

**文件**: `src/components/layout/PromptList.vue`

新增 `isMyPrompts` prop，用于区分是否在"我的提示词"页面，以应用不同的样式和行为。

---

### 2. PromptList.vue - 移除点赞高亮色

**效果**: 在"我的提示词"页面，点赞按钮不会显示橙色高亮。

---

### 3. PromptList.vue - 右下角按钮替换为分享按钮

**修改位置**: 卡片底部 `card-footer`

在"我的提示词"页面，卡片右下角只显示分享按钮，其他页面保持原有统计按钮。

---

### 4. PromptList.vue - 分享弹窗支持部门选择

**新增状态**:
- `shareScope`: 分享范围（'all' | 'department'）
- `departments`: 部门列表（只包含全部部门和用户自己的部门）
- `selectedDepartment`: 选中的部门

**分享弹窗功能**:
- 可以选择"全部部门"或"指定部门"
- 选择"指定部门"时显示部门列表（仅显示全部部门和用户自己的部门）
- 未选择部门时"确认分享"按钮禁用

**部门过滤逻辑**:
```typescript
// 只显示全部部门(ID=1)和用户自己的部门
const filterDepartmentsForShare = (nodes: any[]): any[] => {
  const ALL_DEPT_ID = 1
  const userDeptId = userStore.userInfo?.departmentId ?? userStore.userInfo?.department_id ?? null
  // ...
}
```

---

### 5. api/prompt.ts - 更新分享 API

**修改**:
```typescript
export function batchSharePrompts(ids: number[], departmentId?: number) {
  return request<any, void>({
    url: '/java/v1/prompts/batch-share',
    method: 'post',
    data: ids  // 直接发送数组
  })
}
```

---

### 6. MyPromptsView.vue - 传入新属性

**修改位置**: PromptList 组件调用

新增 `:is-my-prompts="true"` 属性。

---

### 7. 修复卡片底部按钮位置不一致问题

**修复** - `.card-body` 和 `.card-footer` 样式，确保 footer 始终在底部。

---

## 影响范围

| 文件 | 修改类型 | 影响页面 |
|------|----------|----------|
| `src/components/layout/PromptList.vue` | 修改 | 所有使用 PromptList 的页面 |
| `src/views/MyPromptsView.vue` | 修改 | 我的提示词页面 |
| `src/views/PublicFolder.vue` | 无修改 | 提示词广场（保持原有行为） |
| `src/api/prompt.ts` | 修改 | 分享功能 |

---

## 后续修复记录

### 2025-03-09 - 修复批量分享请求格式问题

**问题描述**: 前端发送的 JSON 格式与后端期望的格式不匹配，导致 500 错误。

**原因分析**:
- 后端 `PromptController.batchShare()` 期望接收 `List<Long>` 数组格式：`[1, 2, 3]`
- 前端 `batchSharePrompts()` 发送的是对象格式：`{ ids: [1, 2, 3], department_id: null }`

**修复方案**: 修改前端 `api/prompt.ts`，直接发送 `ids` 数组。

**注意**: `departmentId` 参数暂时保留在函数签名中以兼容现有调用代码，但不再发送到后端。如果将来需要支持部门分享功能，需要后端接口配合修改为接收对象格式。

---

### 2025-03-09 - 实现部门选择功能

**问题描述**: 用户选择分享到自己的部门后，在对应部门下看不到提示词，只能在全部部门下看到。

**原因分析**:
- 后端 `batchShare` 方法强制使用用户自己的部门，不接受前端传入的 `departmentId`
- 前端虽然选择了部门，但没有传递给后端

**修复方案**:

1. **后端 DTO** ([PromptDTO.java](file:///root/zzp/langextract-main/ljt/prompt-system-backend/src/main/java/com/prompt/system/model/dto/PromptDTO.java)):
   新增 `BatchShareRequest` 类：
   ```java
   @Data
   @Builder
   @NoArgsConstructor
   @AllArgsConstructor
   public static class BatchShareRequest {
       private List<Long> ids;
       private Integer departmentId;
   }
   ```

2. **后端 Controller** ([PromptController.java](file:///root/zzp/langextract-main/ljt/prompt-system-backend/src/main/java/com/prompt/system/controller/PromptController.java)):
   修改接口接收 DTO：
   ```java
   @PostMapping("/v1/prompts/batch-share")
   public Result<Void> batchShare(@RequestBody PromptDTO.BatchShareRequest request) {
       // ...
       promptService.batchShare(request.getIds(), request.getDepartmentId());
   }
   ```

3. **后端 Service** ([PromptService.java](file:///root/zzp/langextract-main/ljt/prompt-system-backend/src/main/java/com/prompt/system/service/PromptService.java)):
   修改方法签名，优先使用传入的 departmentId：
   ```java
   public void batchShare(List<Long> promptIds, Integer departmentId) {
       // 如果前端没有传入部门ID，使用用户自己的部门
       if (departmentId == null) {
           departmentId = currentUser.getDeptId();
       }
       // ...
   }
   ```

4. **前端 API** ([prompt.ts](file:///root/zzp/langextract-main/ljt/note-prompt/src/api/prompt.ts)):
   恢复传递对象格式：
   ```typescript
   export function batchSharePrompts(ids: number[], departmentId?: number) {
     return request<any, void>({
       url: '/java/v1/prompts/batch-share',
       method: 'post',
       data: {
         ids,
         departmentId
       }
     })
   }
   ```

**效果**: 用户选择"全部部门"时分享到 ID=1，选择"自己的部门"时分享到对应的部门ID，分享后可以在对应部门下看到提示词。

---

## 批量分享部门选择功能实现

### 修改内容

**MyPromptsView.vue** 已支持批量分享时选择部门：

1. **状态定义**:
   ```typescript
   const shareScope = ref<'all' | 'department'>('all')
   const departments = ref<any[]>([])
   const selectedDepartment = ref<number | null>(null)
   const loadingDepartments = ref(false)
   ```

2. **部门过滤**:
   使用 `filterDepartmentsForShare()` 只显示全部部门(ID=1)和用户自己的部门

3. **分享弹窗 UI**:
   - 选择"全部部门"或"指定部门"
   - 选择指定部门时显示部门列表
   - 确认按钮在未选择部门时禁用

4. **执行分享**:
   ```typescript
   const executeShare = async () => {
     const deptId = shareScope.value === 'department' ? selectedDepartment.value : undefined
     await promptListRef.value.shareSelectedPrompts(deptId)
   }
   ```

**PromptList.vue** 修改 `shareSelectedPrompts` 方法：

```typescript
const shareSelectedPrompts = async (deptId?: number): Promise<number[]> => {
  // ...
  await batchSharePrompts(idsToShare, deptId)
}
```

### 效果

批量分享现在支持：
- 选择"全部部门" → 分享到 ID=1（所有用户可见）
- 选择"自己的部门" → 分享到对应部门ID（仅该部门用户可见）
