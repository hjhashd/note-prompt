-- --------------------------------------------------
-- 数据库完整初始化脚本 v2
-- 说明：本脚本用于全新安装或重置数据库，包含所有核心功能模块及新扩展模块
-- 模块：部门、用户、角色、文件管理、LLM配置、报告生成、AI Prompt管理、积分系统、系统日志
-- 警告：运行本脚本将删除现有表并清空所有数据！
-- --------------------------------------------------

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- 清理旧表 (按依赖顺序删除)
-- ----------------------------
DROP TABLE IF EXISTS `activity_point_records`;
DROP TABLE IF EXISTS `activity_user_wallet`;
DROP TABLE IF EXISTS `sys_entity_relations`;
DROP TABLE IF EXISTS `sys_operation_logs`;
DROP TABLE IF EXISTS `ai_chat_history`;
DROP TABLE IF EXISTS `ai_user_interactions`;
DROP TABLE IF EXISTS `ai_prompt_tag_relation`;
DROP TABLE IF EXISTS `ai_prompt_tags`;
DROP TABLE IF EXISTS `ai_prompts`;
DROP TABLE IF EXISTS `report_chapter_content`;
DROP TABLE IF EXISTS `report_merged_record`;
DROP TABLE IF EXISTS `report_catalogue`;
DROP TABLE IF EXISTS `report_name`;
DROP TABLE IF EXISTS `report_type`;
DROP TABLE IF EXISTS `public_prompts`;
DROP TABLE IF EXISTS `llm_config`;
DROP TABLE IF EXISTS `file_item`;
DROP TABLE IF EXISTS `file_structure`;
DROP TABLE IF EXISTS `user_roles`;
DROP TABLE IF EXISTS `roles`;
DROP TABLE IF EXISTS `users`;
DROP TABLE IF EXISTS `sys_departments`;

-- ----------------------------
-- 1. 部门管理模块
-- ----------------------------
CREATE TABLE `sys_departments` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '部门ID',
  `dept_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '部门名称',
  `parent_id` int DEFAULT 0 COMMENT '父部门ID',
  `ancestors` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT '' COMMENT '祖级列表',
  `order_num` int DEFAULT 0 COMMENT '显示顺序',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='部门表' ROW_FORMAT=Dynamic;

-- ----------------------------
-- 2. 用户与权限模块
-- ----------------------------

-- 用户主表
CREATE TABLE `users` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '用户ID',
  `username` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '登录账号',
  `password_hash` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '密码哈希',
  `status` tinyint NOT NULL DEFAULT 1 COMMENT '状态: 1-正常, 0-禁用',
  `is_deleted` tinyint NOT NULL DEFAULT 0 COMMENT '逻辑删除: 1-已删除, 0-未删除',
  `last_login_at` datetime DEFAULT NULL COMMENT '最后登录时间',
  `last_login_ip` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '最后登录IP',
  `real_name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '真实姓名',
  `department_id` int DEFAULT NULL COMMENT '所属部门ID',
  `shulingtong_sk` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '数灵童SK(关联知识库)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '注册时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `username` (`username`) USING BTREE,
  KEY `idx_user_dept` (`department_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=14 CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户表' ROW_FORMAT=Dynamic;

-- 角色定义表
CREATE TABLE `roles` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '角色ID',
  `role_key` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '角色标识',
  `role_name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '角色名称',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '描述',
  `status` tinyint NOT NULL DEFAULT 1 COMMENT '状态: 1-正常, 0-禁用',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `role_key` (`role_key`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=3 CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='角色表' ROW_FORMAT=Dynamic;

-- 用户角色关联表
CREATE TABLE `user_roles` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `role_id` bigint NOT NULL COMMENT '角色ID',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '关联时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_user_role` (`user_id`,`role_id`) USING BTREE,
  KEY `idx_user_id` (`user_id`) USING BTREE,
  KEY `idx_role_id` (`role_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=12 CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户角色关联表' ROW_FORMAT=Dynamic;

-- ----------------------------
-- 3. 基础资源与配置模块
-- ----------------------------

-- 文件目录结构表
CREATE TABLE `file_structure` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '目录ID',
  `folder_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件夹名称',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `user_id` int NOT NULL DEFAULT 2 COMMENT '所属用户',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `unique_folder_name` (`folder_name`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=21 CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='文件目录表' ROW_FORMAT=Dynamic;

-- 文件项表
CREATE TABLE `file_item` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '文件ID',
  `file_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件名称',
  `file_path` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '物理存储路径',
  `folder_id` int NOT NULL COMMENT '所属目录ID',
  `hotClick` int DEFAULT 0 COMMENT '点击热度',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '上传时间',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `user_id` int NOT NULL DEFAULT 2 COMMENT '上传人',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `unique_file_name` (`file_name`,`folder_id`) USING BTREE,
  KEY `fk_folder` (`folder_id`) USING BTREE,
  CONSTRAINT `file_item_ibfk_1` FOREIGN KEY (`folder_id`) REFERENCES `file_structure` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=31 CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='文件列表表' ROW_FORMAT=Dynamic;

-- LLM 模型配置表
CREATE TABLE `llm_config` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '配置ID',
  `config_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '配置别名',
  `llm_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '模型厂商类型',
  `model_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '模型名称',
  `api_key` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci COMMENT 'API秘钥',
  `base_url` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '接口地址',
  `is_enabled` tinyint(1) DEFAULT 1 COMMENT '是否启用: 1-是, 0-否',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `user_id` int DEFAULT NULL COMMENT '所属用户',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_type_model_user` (`llm_type`,`model_name`,`user_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=25 CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='LLM模型配置表' ROW_FORMAT=Dynamic;

-- 公共 Prompt 表 (旧版)
CREATE TABLE `public_prompts` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '标题',
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT 'Prompt内容',
  `views_count` int DEFAULT 0 COMMENT '查看次数',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=2 CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='公共Prompt模板表(基础版)' ROW_FORMAT=Dynamic;

-- ----------------------------
-- 4. 报告生成业务模块
-- ----------------------------

-- 报告类型定义
CREATE TABLE `report_type` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '类型ID',
  `type_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '类型名称',
  `user_id` int NOT NULL DEFAULT 2 COMMENT '创建人',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=22 CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='报告分类表' ROW_FORMAT=Dynamic;

-- 报告实例主表
CREATE TABLE `report_name` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '报告ID',
  `type_id` int NOT NULL COMMENT '所属分类ID',
  `report_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '报告标题',
  `storage_dir` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '物理存储文件夹名称',
  `status` tinyint DEFAULT 0 COMMENT '状态: 0-草稿, 1-生成中, 2-已完成',
  `template_id` int DEFAULT NULL COMMENT '引用的模板ID',
  `description` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '需求描述',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `user_id` int DEFAULT 2 COMMENT '所属用户',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `fk_report_name_type` (`type_id`) USING BTREE,
  KEY `idx_storage_dir` (`storage_dir`) USING BTREE,
  CONSTRAINT `report_name_ibfk_1` FOREIGN KEY (`type_id`) REFERENCES `report_type` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=149 CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='报告主记录表' ROW_FORMAT=Dynamic;

-- 报告目录结构表
CREATE TABLE `report_catalogue` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '目录ID',
  `type_id` int NOT NULL COMMENT '分类ID',
  `report_name_id` int NOT NULL COMMENT '所属报告ID',
  `catalogue_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '目录名称',
  `level` int NOT NULL COMMENT '层级(1/2/3...)',
  `sortOrder` int NOT NULL COMMENT '同级排序',
  `parent_id` int DEFAULT 0 COMMENT '父目录ID',
  `file_name` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '关联文件名',
  `user_id` int NOT NULL DEFAULT 2 COMMENT '所属用户',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `fk_catalogue_type` (`type_id`) USING BTREE,
  KEY `fk_catalogue_name` (`report_name_id`) USING BTREE,
  CONSTRAINT `report_catalogue_ibfk_1` FOREIGN KEY (`report_name_id`) REFERENCES `report_name` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `report_catalogue_ibfk_2` FOREIGN KEY (`type_id`) REFERENCES `report_type` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=9001 CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='报告目录大纲表' ROW_FORMAT=Dynamic;

-- 报告章节详细内容表
CREATE TABLE `report_chapter_content` (
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

-- 报告合并导出记录表
CREATE TABLE `report_merged_record` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `type_id` int NOT NULL COMMENT '分类ID',
  `report_name_id` int NOT NULL COMMENT '所属报告ID',
  `merged_report_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '导出文件名',
  `file_path` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件下载路径',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '生成时间',
  `user_id` int NOT NULL DEFAULT 2 COMMENT '所属用户',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `fk_merged_type` (`type_id`) USING BTREE,
  KEY `fk_merged_report` (`report_name_id`) USING BTREE,
  CONSTRAINT `report_merged_record_ibfk_1` FOREIGN KEY (`report_name_id`) REFERENCES `report_name` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `report_merged_record_ibfk_2` FOREIGN KEY (`type_id`) REFERENCES `report_type` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=22 CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='报告导出记录表' ROW_FORMAT=Dynamic;

-- ----------------------------
-- 5. 高级 AI Prompt 管理模块
-- ----------------------------

-- Prompt 核心管理表
CREATE TABLE `ai_prompts` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `uuid` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '全局唯一UUID',
  `origin_prompt_id` bigint DEFAULT NULL COMMENT '溯源ID(原始模板)',
  `parent_prompt_id` bigint DEFAULT NULL COMMENT '派生ID(父版本)',
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '标题',
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci COMMENT '描述',
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT 'Prompt主体内容',
  `user_input_example` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci COMMENT '输入示例',
  `variables_json` json DEFAULT NULL COMMENT '动态变量配置',
  `model_config_json` json DEFAULT NULL COMMENT '建议模型参数',
  `status` tinyint DEFAULT 1 COMMENT '状态: 1-启用, 0-禁用',
  `is_template` tinyint DEFAULT 0 COMMENT '是否公共模板: 1-是, 0-否',
  `user_id` bigint NOT NULL COMMENT '创建人ID',
  `user_name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '创建人姓名',
  `department_id` int DEFAULT NULL COMMENT '所属部门',
  `view_count` int DEFAULT 0 COMMENT '浏览量',
  `like_count` int DEFAULT 0 COMMENT '点赞数',
  `favorite_count` int DEFAULT 0 COMMENT '收藏数',
  `copy_count` int DEFAULT 0 COMMENT '被派生数',
  `apply_report_count` int DEFAULT 0 COMMENT '应用次数',
  `share_count` int DEFAULT 0 COMMENT '分享数',
  `heat_score` double DEFAULT 0 COMMENT '综合热度分',
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
CREATE TABLE `ai_prompt_directories` (
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
CREATE TABLE `ai_prompt_directory_rel` (
  `directory_id` int NOT NULL COMMENT '目录ID',
  `prompt_id` bigint NOT NULL COMMENT 'Prompt ID',
  PRIMARY KEY (`directory_id`,`prompt_id`) USING BTREE,
  KEY `idx_rel_prompt` (`prompt_id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Prompt目录关联表' ROW_FORMAT=Dynamic;

-- Prompt 标签表
CREATE TABLE `ai_prompt_tags` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '标签ID',
  `tag_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '标签名称',
  `type` tinyint DEFAULT 1 COMMENT '1-系统标签, 2-个人标签',
  `user_id` bigint DEFAULT NULL COMMENT '个人标签所属用户',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Prompt标签定义表' ROW_FORMAT=Dynamic;

-- Prompt 标签关联表
CREATE TABLE `ai_prompt_tag_relation` (
  `prompt_id` bigint NOT NULL COMMENT 'Prompt ID',
  `tag_id` int NOT NULL COMMENT '标签ID',
  PRIMARY KEY (`prompt_id`,`tag_id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Prompt标签关联表' ROW_FORMAT=Dynamic;

-- 用户交互记录表
CREATE TABLE `ai_user_interactions` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `target_id` bigint NOT NULL COMMENT '目标ID',
  `target_type` tinyint NOT NULL COMMENT '1-Prompt',
  `action_type` tinyint NOT NULL COMMENT '1-点赞, 2-收藏, 3-分享, 4-派生',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '动作发生时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_user_target_action` (`user_id`,`target_id`,`target_type`,`action_type`) USING BTREE,
  KEY `idx_interaction_user` (`user_id`) USING BTREE,
  KEY `idx_interaction_target` (`target_id`,`target_type`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI行为交互记录表' ROW_FORMAT=Dynamic;

-- AI 聊天对话记录表
CREATE TABLE `ai_chat_history` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `session_id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '会话ID',
  `prompt_id` bigint DEFAULT NULL COMMENT '引用的Prompt ID',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `role` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '角色: user/assistant/system',
  `raw_query` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci COMMENT '原始输入',
  `final_prompt` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci COMMENT '最终发送Prompt',
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '响应内容',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '记录时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_session` (`session_id`) USING BTREE,
  KEY `idx_chat_user` (`user_id`) USING BTREE,
  KEY `idx_chat_prompt` (`prompt_id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI聊天历史记录表' ROW_FORMAT=Dynamic;

-- ----------------------------
-- 6. 系统审计与图谱模块
-- ----------------------------

-- 操作日志审计表
CREATE TABLE `sys_operation_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `user_id` bigint NOT NULL COMMENT '操作人ID',
  `department_id` int DEFAULT NULL COMMENT '所属部门',
  `module` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '模块名',
  `action` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '行为',
  `target_id` bigint DEFAULT NULL COMMENT '目标ID',
  `ip_address` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT 'IP地址',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '发生时间',
  `create_date` date GENERATED ALWAYS AS (cast(`create_time` as date)) STORED COMMENT '生成日期(用于统计)',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_stat_time` (`create_date`) USING BTREE,
  KEY `idx_stat_action` (`action`) USING BTREE,
  KEY `idx_stat_user` (`user_id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='系统操作审计日志' ROW_FORMAT=Dynamic;

-- 实体关系图谱表
CREATE TABLE `sys_entity_relations` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `from_id` bigint NOT NULL COMMENT '源实体ID',
  `from_type` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '源类型',
  `to_id` bigint NOT NULL COMMENT '目标实体ID',
  `to_type` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '目标类型',
  `relation_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '关系描述',
  `weight` float DEFAULT 1.0 COMMENT '关系权重',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '建立时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_graph_from` (`from_type`,`from_id`) USING BTREE,
  KEY `idx_graph_to` (`to_type`,`to_id`) USING BTREE,
  KEY `idx_graph_relation` (`relation_type`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='通用实体关系模型表' ROW_FORMAT=Dynamic;

-- ----------------------------
-- 7. 积分激励系统模块
-- ----------------------------

-- 积分钱包表
CREATE TABLE `activity_user_wallet` (
  `user_id` bigint NOT NULL COMMENT '关联用户ID',
  `total_points` int DEFAULT 0 COMMENT '历史累计总积分',
  `current_points` int DEFAULT 0 COMMENT '当前可用积分',
  `exchange_amount` decimal(10,2) DEFAULT 0.00 COMMENT '已兑换金额',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`user_id`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='积分钱包表' ROW_FORMAT=Dynamic;

-- 积分变动明细表
CREATE TABLE `activity_point_records` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `event_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '事件(login/share/gen)',
  `points` int NOT NULL COMMENT '积分变动值',
  `source_type` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '关联业务类型',
  `source_id` bigint NOT NULL COMMENT '业务ID',
  `related_type` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '附加关联类型',
  `related_id` bigint DEFAULT NULL COMMENT '附加关联ID',
  `target_user_id` bigint DEFAULT NULL COMMENT '目标用户(如被点赞人)',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '记录时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_prevent_spam` (`user_id`,`event_type`,`source_type`,`source_id`,`related_type`,`related_id`) USING BTREE COMMENT '幂等性校验(防重计分)',
  KEY `idx_point_user_time` (`user_id`,`create_time`) USING BTREE,
  KEY `idx_point_event` (`event_type`) USING BTREE
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='积分变动流水表' ROW_FORMAT=Dynamic;

SET FOREIGN_KEY_CHECKS = 1;
