# ── Stage 1: Build the React app ──────────────────────────────────
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY public ./public
COPY src ./src
# Disable source maps — smaller image, no source exposure in production
ENV GENERATE_SOURCEMAP=false
ENV NODE_ENV=production
ARG REACT_APP_USERNAME
ENV REACT_APP_USERNAME=$REACT_APP_USERNAME
RUN npm run build

# ── Stage 2: Serve with nginx ──────────────────────────────────────
FROM nginx:1.27-alpine AS production
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost/ || exit 1
CMD ["nginx", "-g", "daemon off;"]
