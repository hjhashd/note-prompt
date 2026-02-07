# 构建阶段
FROM node:20-alpine AS build-stage

WORKDIR /app

# 安装依赖
COPY package*.json ./
RUN npm install

# 复制源码并构建
COPY . .
RUN npm run build

# 运行阶段
FROM nginx:alpine AS production-stage

# 复制编译产物
COPY --from=build-stage /app/dist /usr/share/nginx/html

# 复制 Nginx 配置模板
COPY docker/nginx/default.conf.template /etc/nginx/templates/default.conf.template

# 暴露端口
EXPOSE 80

# 启动 Nginx，Docker 官方镜像会自动使用 envsubst 处理 /etc/nginx/templates/*.template
CMD ["nginx", "-g", "daemon off;"]
