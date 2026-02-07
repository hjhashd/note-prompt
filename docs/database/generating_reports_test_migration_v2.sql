-- --------------------------------------------------
-- 数据库增量迁移脚本 v2
-- 说明：本脚本用于在保留现有数据的基础上，增加新功能模块（部门、报告内容、AI Prompt管理、积分系统、日志等）
-- 包含：新表创建 (CREATE TABLE IF NOT EXISTS) 和 现有表字段/索引添加 (通过 information_schema 检查实现幂等性)
-- --------------------------------------------------

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- 1. 创建部门表 (sys_departments)
-- ----------------------------
CREATE TABLE IF NOT EXISTS `sys_departments` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '部门ID',
  `dept_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '部门名称',
  `parent_id` int DEFAULT 0 COMMENT '父部门ID',
  `ancestors` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT '' COMMENT '祖级列表',
  `order_num` int DEFAULT 0 COMMENT '显示顺序',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='部门表' ROW_FORMAT=Dynamic;

-- ----------------------------
-- 2. 升级用户表 (users) - 增加字段和索引
-- ----------------------------

-- 为现有字段补全注释
SET @__sql := (
  SELECT IF(
    COUNT(*) > 0,
    'ALTER TABLE `users` 
     MODIFY COLUMN `id` bigint NOT NULL AUTO_INCREMENT COMMENT ''用户ID'',
     MODIFY COLUMN `username` varchar(64) NOT NULL COMMENT ''登录账号'',
     MODIFY COLUMN `password_hash` varchar(255) NOT NULL COMMENT ''加密后的密码'',
     MODIFY COLUMN `status` tinyint NOT NULL DEFAULT 1 COMMENT ''1=正常 0=禁用'',
     MODIFY COLUMN `is_deleted` tinyint NOT NULL DEFAULT 0 COMMENT ''逻辑删除'',
     MODIFY COLUMN `last_login_at` datetime NULL DEFAULT NULL COMMENT ''最近一次成功登录'',
     MODIFY COLUMN `last_login_ip` varchar(64) NULL DEFAULT NULL COMMENT ''最近一次登录IP'',
     MODIFY COLUMN `created_at` datetime NOT NULL COMMENT ''创建时间'',
     MODIFY COLUMN `updated_at` datetime NOT NULL COMMENT ''更新时间''',
    'SELECT 1'
  )
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

-- 增加 real_name 字段
SET @__sql := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE `users` ADD COLUMN `real_name` varchar(64) NULL COMMENT ''真实姓名''',
    'SELECT 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'real_name'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

-- 增加 department_id 字段
SET @__sql := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE `users` ADD COLUMN `department_id` int NULL COMMENT ''部门ID''',
    'SELECT 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'department_id'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

-- 增加 shulingtong_sk 字段
SET @__sql := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE `users` ADD COLUMN `shulingtong_sk` varchar(255) NULL COMMENT ''数灵童用户SK(用于知识库关联)''',
    'SELECT 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'shulingtong_sk'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

-- 增加部门索引
SET @__sql := (
  SELECT IF(
    COUNT(*) = 0,
    'CREATE INDEX `idx_user_dept` ON `users`(`department_id`)',
    'SELECT 1'
  )
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND INDEX_NAME = 'idx_user_dept'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

-- 统一时间字段默认值
SET @__sql := (
  SELECT IF(
    COUNT(*) > 0,
    'ALTER TABLE `users` MODIFY COLUMN `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT ''创建时间'', MODIFY COLUMN `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT ''更新时间''',
    'SELECT 1'
  )
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

-- ----------------------------
-- 3. 升级报告主表 (report_name)
-- ----------------------------

-- 为现有字段补全注释
SET @__sql := (
  SELECT IF(
    COUNT(*) > 0,
    'ALTER TABLE `report_name` 
     MODIFY COLUMN `id` int NOT NULL AUTO_INCREMENT COMMENT ''报告ID'',
     MODIFY COLUMN `type_id` int NOT NULL COMMENT ''关联文档类型ID (外键)'',
     MODIFY COLUMN `report_name` varchar(255) NOT NULL COMMENT ''报告名称'',
     MODIFY COLUMN `create_time` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT ''创建时间'',
     MODIFY COLUMN `user_id` int NULL DEFAULT 2 COMMENT ''所属用户ID''',
    'SELECT 1'
  )
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'report_name'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

-- 增加 status 字段
SET @__sql := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE `report_name` ADD COLUMN `status` tinyint DEFAULT 0 COMMENT ''状态: 0-草稿, 1-生成中, 2-已完成''',
    'SELECT 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'report_name' AND COLUMN_NAME = 'status'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

-- 增加 template_id 字段
SET @__sql := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE `report_name` ADD COLUMN `template_id` int NULL COMMENT ''使用的报告模版ID''',
    'SELECT 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'report_name' AND COLUMN_NAME = 'template_id'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

-- 增加 description 字段
SET @__sql := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE `report_name` ADD COLUMN `description` varchar(500) NULL COMMENT ''报告需求描述''',
    'SELECT 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'report_name' AND COLUMN_NAME = 'description'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

-- 增加 storage_dir 字段 (物理存储文件夹名)
SET @__sql := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE `report_name` ADD COLUMN `storage_dir` varchar(500) NULL COMMENT ''物理存储文件夹名称'' AFTER `report_name`',
    'SELECT 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'report_name' AND COLUMN_NAME = 'storage_dir'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

-- 增加 storage_dir 索引
SET @__sql := (
  SELECT IF(
    COUNT(*) = 0,
    'CREATE INDEX `idx_storage_dir` ON `report_name`(`storage_dir`)',
    'SELECT 1'
  )
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'report_name' AND INDEX_NAME = 'idx_storage_dir'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

-- ----------------------------
-- 4. 创建报告章节内容表 (report_chapter_content)
-- ----------------------------
CREATE TABLE IF NOT EXISTS `report_chapter_content` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `catalogue_id` int NOT NULL COMMENT '目录节点ID',
  `content_md` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci COMMENT 'Markdown内容',
  `content_html` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci COMMENT 'HTML内容',
  `version` int DEFAULT 1 COMMENT '版本号',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_catalogue` (`catalogue_id`) USING BTREE,
  KEY `idx_catalogue_id` (`catalogue_id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='报告章节内容表' ROW_FORMAT=Dynamic;

-- ----------------------------
-- 5. 创建 AI Prompt 管理系统相关表
-- ----------------------------

-- Prompt 主表
CREATE TABLE IF NOT EXISTS `ai_prompts` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `uuid` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '唯一UUID',
  `origin_prompt_id` bigint DEFAULT NULL COMMENT '原始模板ID(溯源)',
  `parent_prompt_id` bigint DEFAULT NULL COMMENT '父级Prompt ID(派生)',
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '标题',
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci COMMENT '描述信息',
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT 'Prompt内容',
  `user_input_example` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci COMMENT '用户输入示例',
  `variables_json` json DEFAULT NULL COMMENT '变量配置(JSON)',
  `model_config_json` json DEFAULT NULL COMMENT '模型参数配置(JSON)',
  `status` tinyint DEFAULT 1 COMMENT '状态: 1-启用, 0-禁用',
  `is_template` tinyint DEFAULT 0 COMMENT '是否为公共模板: 1-是, 0-否',
  `user_id` bigint NOT NULL COMMENT '创建者ID',
  `user_name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '创建者姓名',
  `department_id` int DEFAULT NULL COMMENT '所属部门ID',
  `view_count` int DEFAULT 0 COMMENT '查看数',
  `like_count` int DEFAULT 0 COMMENT '点赞数',
  `favorite_count` int DEFAULT 0 COMMENT '收藏数',
  `copy_count` int DEFAULT 0 COMMENT '复制/派生数',
  `apply_report_count` int DEFAULT 0 COMMENT '应用到报告次数',
  `share_count` int DEFAULT 0 COMMENT '分享次数',
  `heat_score` double DEFAULT 0 COMMENT '热度分',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_ai_prompts_uuid` (`uuid`) USING BTREE,
  KEY `idx_prompt_user` (`user_id`) USING BTREE,
  KEY `idx_prompt_dept` (`department_id`) USING BTREE,
  KEY `idx_prompt_status` (`status`) USING BTREE,
  KEY `idx_lineage` (`origin_prompt_id`,`parent_prompt_id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI Prompt管理表' ROW_FORMAT=Dynamic;

-- Prompt 目录表
CREATE TABLE IF NOT EXISTS `ai_prompt_directories` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '目录ID',
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '目录名称',
  `owner_id` bigint DEFAULT NULL COMMENT '所有者ID(NULL或0代表公共)',
  `parent_id` int DEFAULT 0 COMMENT '父目录ID',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_dir_owner` (`owner_id`) USING BTREE,
  KEY `idx_dir_parent` (`parent_id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Prompt目录表' ROW_FORMAT=Dynamic;

-- Prompt 目录关联表
CREATE TABLE IF NOT EXISTS `ai_prompt_directory_rel` (
  `directory_id` int NOT NULL COMMENT '目录ID',
  `prompt_id` bigint NOT NULL COMMENT 'Prompt ID',
  PRIMARY KEY (`directory_id`,`prompt_id`) USING BTREE,
  KEY `idx_rel_prompt` (`prompt_id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Prompt目录关联表' ROW_FORMAT=Dynamic;

-- Prompt 标签表
CREATE TABLE IF NOT EXISTS `ai_prompt_tags` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '标签ID',
  `tag_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '标签名称',
  `type` tinyint DEFAULT 1 COMMENT '类型: 1-系统标签, 2-个人标签',
  `user_id` bigint DEFAULT NULL COMMENT '个人标签所属用户ID',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Prompt标签表' ROW_FORMAT=Dynamic;

-- Prompt 标签关联表
CREATE TABLE IF NOT EXISTS `ai_prompt_tag_relation` (
  `prompt_id` bigint NOT NULL COMMENT 'Prompt ID',
  `tag_id` int NOT NULL COMMENT '标签ID',
  PRIMARY KEY (`prompt_id`,`tag_id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Prompt标签关联表' ROW_FORMAT=Dynamic;

-- 用户交互记录表 (点赞/收藏等)
CREATE TABLE IF NOT EXISTS `ai_user_interactions` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `target_id` bigint NOT NULL COMMENT '目标ID',
  `target_type` tinyint NOT NULL COMMENT '目标类型: 1-Prompt',
  `action_type` tinyint NOT NULL COMMENT '动作类型: 1-点赞, 2-收藏, 3-分享, 4-复制',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '发生时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_user_target_action` (`user_id`,`target_id`,`target_type`,`action_type`) USING BTREE,
  KEY `idx_interaction_user` (`user_id`) USING BTREE,
  KEY `idx_interaction_target` (`target_id`,`target_type`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户交互行为记录表' ROW_FORMAT=Dynamic;

-- AI 聊天历史记录表
CREATE TABLE IF NOT EXISTS `ai_chat_history` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `session_id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '会话ID',
  `prompt_id` bigint DEFAULT NULL COMMENT '引用的Prompt ID',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `role` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '角色: user/assistant/system',
  `raw_query` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci COMMENT '原始输入',
  `final_prompt` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci COMMENT '最终发送给AI的Prompt',
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '对话内容',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '记录时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_session` (`session_id`) USING BTREE,
  KEY `idx_chat_user` (`user_id`) USING BTREE,
  KEY `idx_chat_prompt` (`prompt_id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI聊天历史记录表' ROW_FORMAT=Dynamic;

-- ----------------------------
-- 6. 系统日志与关系表
-- ----------------------------

-- 操作日志表
CREATE TABLE IF NOT EXISTS `sys_operation_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `user_id` bigint NOT NULL COMMENT '操作人ID',
  `department_id` int DEFAULT NULL COMMENT '操作人所属部门ID',
  `module` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '功能模块',
  `action` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '操作行为',
  `target_id` bigint DEFAULT NULL COMMENT '操作目标ID',
  `ip_address` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT 'IP地址',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '发生时间',
  `create_date` date GENERATED ALWAYS AS (cast(`create_time` as date)) STORED COMMENT '发生日期(用于统计)',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_stat_time` (`create_date`) USING BTREE,
  KEY `idx_stat_action` (`action`) USING BTREE,
  KEY `idx_stat_user` (`user_id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='系统操作日志表' ROW_FORMAT=Dynamic;

-- 实体关系表 (通用关联模型)
CREATE TABLE IF NOT EXISTS `sys_entity_relations` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `from_id` bigint NOT NULL COMMENT '源实体ID',
  `from_type` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '源实体类型',
  `to_id` bigint NOT NULL COMMENT '目标实体ID',
  `to_type` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '目标实体类型',
  `relation_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '关系类型',
  `weight` float DEFAULT 1.0 COMMENT '权重/强度',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '建立时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_graph_from` (`from_type`,`from_id`) USING BTREE,
  KEY `idx_graph_to` (`to_type`,`to_id`) USING BTREE,
  KEY `idx_graph_relation` (`relation_type`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='通用实体关系表' ROW_FORMAT=Dynamic;

-- ----------------------------
-- 7. 积分系统相关表
-- ----------------------------

-- 用户积分钱包表
CREATE TABLE IF NOT EXISTS `activity_user_wallet` (
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `total_points` int DEFAULT 0 COMMENT '累计总积分',
  `current_points` int DEFAULT 0 COMMENT '当前可用积分',
  `exchange_amount` decimal(10,2) DEFAULT 0.00 COMMENT '累计兑换金额',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`user_id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户积分钱包表' ROW_FORMAT=Dynamic;

-- 积分变动记录表
CREATE TABLE IF NOT EXISTS `activity_point_records` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `event_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '事件类型(如: login, report_gen)',
  `points` int NOT NULL COMMENT '变动积分值',
  `source_type` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '来源类型',
  `source_id` bigint NOT NULL COMMENT '来源ID',
  `related_type` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '关联类型',
  `related_id` bigint DEFAULT NULL COMMENT '关联ID',
  `target_user_id` bigint DEFAULT NULL COMMENT '目标用户ID(如打赏对象)',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '记录时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_prevent_spam` (`user_id`,`event_type`,`source_type`,`source_id`,`related_type`,`related_id`) USING BTREE COMMENT '防重复计分唯一索引',
  KEY `idx_point_user_time` (`user_id`,`create_time`) USING BTREE,
  KEY `idx_point_event` (`event_type`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='积分变动记录表' ROW_FORMAT=Dynamic;

-- ----------------------------
-- 8. 升级公共 Prompt 表 (public_prompts)
-- ----------------------------

-- 为现有字段补全注释
SET @__sql := (
  SELECT IF(
    COUNT(*) > 0,
    'ALTER TABLE `public_prompts` 
     MODIFY COLUMN `id` bigint NOT NULL AUTO_INCREMENT COMMENT ''Prompt ID'',
     MODIFY COLUMN `title` varchar(255) NOT NULL COMMENT ''标题'',
     MODIFY COLUMN `content` text NOT NULL COMMENT ''Prompt主体内容''',
    'SELECT 1'
  )
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'public_prompts'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

SET @__sql := (
  SELECT IF(
    COUNT(*) > 0,
    'ALTER TABLE `public_prompts` MODIFY COLUMN `views_count` int NULL DEFAULT 0 COMMENT ''查看次数'', MODIFY COLUMN `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT ''创建时间'', MODIFY COLUMN `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT ''更新时间''',
    'SELECT 1'
  )
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'public_prompts'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

-- ----------------------------
-- 9. 为其他存量表补全注释
-- ----------------------------

-- 升级角色表注释
SET @__sql := (
  SELECT IF(
    COUNT(*) > 0,
    'ALTER TABLE `roles` 
     MODIFY COLUMN `id` bigint NOT NULL AUTO_INCREMENT COMMENT ''角色ID'',
     MODIFY COLUMN `role_key` varchar(32) NOT NULL COMMENT ''角色标识'',
     MODIFY COLUMN `role_name` varchar(64) NOT NULL COMMENT ''角色名称'',
     MODIFY COLUMN `description` varchar(255) NULL DEFAULT NULL COMMENT ''描述'',
     MODIFY COLUMN `status` tinyint NOT NULL DEFAULT 1 COMMENT ''1=启用 0=停用'',
     MODIFY COLUMN `created_at` datetime NOT NULL COMMENT ''创建时间'',
     MODIFY COLUMN `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT ''更新时间''',
    'SELECT 1'
  )
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'roles'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

-- 升级用户角色关联表注释
SET @__sql := (
  SELECT IF(
    COUNT(*) > 0,
    'ALTER TABLE `user_roles` 
     MODIFY COLUMN `id` bigint NOT NULL AUTO_INCREMENT COMMENT ''关联ID'',
     MODIFY COLUMN `user_id` bigint NOT NULL COMMENT ''用户ID'',
     MODIFY COLUMN `role_id` bigint NOT NULL COMMENT ''角色ID'',
     MODIFY COLUMN `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT ''关联时间''',
    'SELECT 1'
  )
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_roles'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

-- 升级 LLM 配置表注释 (补全缺失字段)
SET @__sql := (
  SELECT IF(
    COUNT(*) > 0,
    'ALTER TABLE `llm_config` 
     MODIFY COLUMN `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT ''创建时间'',
     MODIFY COLUMN `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT ''更新时间'',
     MODIFY COLUMN `user_id` int NULL DEFAULT NULL COMMENT ''关联用户ID''',
    'SELECT 1'
  )
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'llm_config'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;

-- 升级报告类型表注释
SET @__sql := (
  SELECT IF(
    COUNT(*) > 0,
    'ALTER TABLE `report_type` 
     MODIFY COLUMN `id` int NOT NULL AUTO_INCREMENT COMMENT ''类型ID'',
     MODIFY COLUMN `type_name` varchar(255) NOT NULL COMMENT ''文档类型名称'',
     MODIFY COLUMN `user_id` int NOT NULL DEFAULT 2 COMMENT ''关联用户ID''',
    'SELECT 1'
  )
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'report_type'
);
PREPARE __stmt FROM @__sql; EXECUTE __stmt; DEALLOCATE PREPARE __stmt;


-- ---------------------------- 
-- 13. 提示词目录表 (ai_prompt_directories) 
-- 复用旧系统的 folders 和 public_folders 概念，但合并为一张表 
-- ---------------------------- 
DROP TABLE IF EXISTS `ai_prompt_directories`; 
CREATE TABLE `ai_prompt_directories` ( 
  `id` int NOT NULL AUTO_INCREMENT, 
  `dir_name` varchar(100) NOT NULL COMMENT '目录名称', 
  `parent_id` int DEFAULT 0 COMMENT '父级目录ID (0为根目录)', 
  `owner_id` bigint DEFAULT NULL COMMENT '所属人ID (NULL代表系统公共目录/广场目录)', 
  `is_public` tinyint DEFAULT 0 COMMENT '是否公开: 0-私有, 1-公开(广场)', 
  `icon` varchar(50) DEFAULT 'folder' COMMENT '目录图标', 
  `sort_order` int DEFAULT 0 COMMENT '排序', 
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP, 
  PRIMARY KEY (`id`), 
  INDEX `idx_parent` (`parent_id`), 
  INDEX `idx_owner` (`owner_id`) 
) COMMENT = '提示词文件夹/目录结构'; 

-- ---------------------------- 
-- 14. 提示词-目录关联表 (ai_prompt_directory_rel) 
-- 替代旧系统的 folder_prompts 和 public_folder_prompts 
-- ---------------------------- 
DROP TABLE IF EXISTS `ai_prompt_directory_rel`; 
CREATE TABLE `ai_prompt_directory_rel` ( 
  `id` bigint NOT NULL AUTO_INCREMENT, 
  `directory_id` int NOT NULL COMMENT '目录ID', 
  `prompt_id` bigint NOT NULL COMMENT '提示词ID', 
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP, 
  PRIMARY KEY (`id`), 
  UNIQUE INDEX `uk_dir_prompt` (`directory_id`, `prompt_id`) 
) COMMENT = '提示词与目录的归属关系';

SET FOREIGN_KEY_CHECKS = 1;
