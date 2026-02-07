/*
 Navicat Premium Data Transfer

 Source Server         : vpn链接10服务器
 Source Server Type    : MySQL
 Source Server Version : 80039
 Source Host           : localhost:3307
 Source Schema         : generating_reports_test

 Target Server Type    : MySQL
 Target Server Version : 80039
 File Encoding         : 65001

 Date: 30/01/2026 17:49:14
*/

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for file_item
-- ----------------------------
DROP TABLE IF EXISTS `file_item`;
CREATE TABLE `file_item`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '文件唯一ID',
  `file_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件名称',
  `file_path` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件存储路径',
  `folder_id` int NOT NULL COMMENT '所属文件夹ID',
  `hotClick` int NULL DEFAULT 0 COMMENT '点击量，用于统计热度',
  `create_time` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `user_id` int NOT NULL DEFAULT 2 COMMENT '关联用户ID',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `unique_file_name`(`file_name` ASC, `folder_id` ASC) USING BTREE,
  INDEX `fk_folder`(`folder_id` ASC) USING BTREE,
  CONSTRAINT `file_item_ibfk_1` FOREIGN KEY (`folder_id`) REFERENCES `file_structure` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 31 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '文件表，用于存储文件元信息及点击量' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for file_structure
-- ----------------------------
DROP TABLE IF EXISTS `file_structure`;
CREATE TABLE `file_structure`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '文件夹唯一ID',
  `folder_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件夹名称',
  `create_time` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `user_id` int NOT NULL DEFAULT 2 COMMENT '关联用户ID',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `unique_folder_name`(`folder_name` ASC) USING BTREE COMMENT '文件夹名称唯一约束'
) ENGINE = InnoDB AUTO_INCREMENT = 21 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '文件夹表，用于存储文件目录' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for llm_config
-- ----------------------------
DROP TABLE IF EXISTS `llm_config`;
CREATE TABLE `llm_config`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `config_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '配置别名 (如: 公司DeepSeek, 本地Llama3)',
  `llm_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '配置类型: local, online, custom',
  `model_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '模型名称 (如: gpt-4o, llama3:8b)',
  `api_key` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '自动加密后的API KEY (密文)',
  `base_url` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT 'API请求地址',
  `is_enabled` tinyint(1) NULL DEFAULT 1 COMMENT '是否启用: 1-启用, 0-禁用',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `user_id` int NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_type_model_user`(`llm_type` ASC, `model_name` ASC, `user_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 25 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '大模型配置表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for public_prompts
-- ----------------------------
DROP TABLE IF EXISTS `public_prompts`;
CREATE TABLE `public_prompts`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '标题',
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '内容',
  `views_count` int NULL DEFAULT NULL COMMENT '浏览量',
  `created_at` datetime NOT NULL DEFAULT 'now()',
  `updated_at` datetime NOT NULL DEFAULT 'now()',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for report_catalogue
-- ----------------------------
DROP TABLE IF EXISTS `report_catalogue`;
CREATE TABLE `report_catalogue`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `type_id` int NOT NULL COMMENT '关联文档类型ID (外键)',
  `report_name_id` int NOT NULL COMMENT '关联报告名称ID (外键)',
  `catalogue_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '目录名称',
  `level` int NOT NULL COMMENT '目录层级',
  `sortOrder` int NOT NULL COMMENT '目录排序',
  `parent_id` int NULL DEFAULT 0 COMMENT '上级目录ID',
  `file_name` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '文件存放地址',
  `user_id` int NOT NULL DEFAULT 2 COMMENT '关联用户ID',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `fk_catalogue_type`(`type_id` ASC) USING BTREE,
  INDEX `fk_catalogue_name`(`report_name_id` ASC) USING BTREE,
  CONSTRAINT `report_catalogue_ibfk_1` FOREIGN KEY (`report_name_id`) REFERENCES `report_name` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `report_catalogue_ibfk_2` FOREIGN KEY (`type_id`) REFERENCES `report_type` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 9001 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '报告目录结构表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for report_merged_record
-- ----------------------------
DROP TABLE IF EXISTS `report_merged_record`;
CREATE TABLE `report_merged_record`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `type_id` int NOT NULL COMMENT '关联文档类型ID (外键)',
  `report_name_id` int NOT NULL COMMENT '关联报告名称ID (外键)',
  `merged_report_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '合并后的报告名称 (通常与report_name一致)',
  `file_path` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '合并文件的物理保存绝对路径',
  `create_time` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '生成时间',
  `user_id` int NOT NULL DEFAULT 2 COMMENT '关联用户ID',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `fk_merged_type`(`type_id` ASC) USING BTREE,
  INDEX `fk_merged_report`(`report_name_id` ASC) USING BTREE,
  CONSTRAINT `report_merged_record_ibfk_1` FOREIGN KEY (`report_name_id`) REFERENCES `report_name` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `report_merged_record_ibfk_2` FOREIGN KEY (`type_id`) REFERENCES `report_type` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 22 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '报告合并记录表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for report_name
-- ----------------------------
DROP TABLE IF EXISTS `report_name`;
CREATE TABLE `report_name`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `type_id` int NOT NULL COMMENT '关联文档类型ID (外键)',
  `report_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '报告名称',
  `create_time` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `user_id` int NULL DEFAULT 2,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `fk_report_name_type`(`type_id` ASC) USING BTREE,
  CONSTRAINT `report_name_ibfk_1` FOREIGN KEY (`type_id`) REFERENCES `report_type` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 149 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '报告名称信息表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for report_type
-- ----------------------------
DROP TABLE IF EXISTS `report_type`;
CREATE TABLE `report_type`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `type_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文档类型名称',
  `user_id` int NOT NULL DEFAULT 2 COMMENT '关联用户ID',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 22 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '报告类型表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for roles
-- ----------------------------
DROP TABLE IF EXISTS `roles`;
CREATE TABLE `roles`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `role_key` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT 'admin / user ',
  `role_name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '管理者/用户',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `status` tinyint NOT NULL DEFAULT 1 COMMENT '1=启用 0=停用',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `role_key`(`role_key` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 3 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for user_roles
-- ----------------------------
DROP TABLE IF EXISTS `user_roles`;
CREATE TABLE `user_roles`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `role_id` bigint NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_user_role`(`user_id` ASC, `role_id` ASC) USING BTREE,
  INDEX `idx_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_role_id`(`role_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 12 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for users
-- ----------------------------
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `username` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '登录账号',
  `password_hash` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '加密后的密码',
  `status` tinyint NOT NULL DEFAULT 1 COMMENT '1=正常 0=禁用',
  `is_deleted` tinyint NOT NULL DEFAULT 0 COMMENT '软删除',
  `last_login_at` datetime NULL DEFAULT NULL COMMENT '最近一次成功登录',
  `last_login_ip` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '最近一次登录IP',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `username`(`username` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 14 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

SET FOREIGN_KEY_CHECKS = 1;
