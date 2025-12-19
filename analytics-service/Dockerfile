# Builder stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --silent
COPY . .

# Production stage
FROM node:18-alpine
WORKDIR /app
RUN apk add --no-cache ca-certificates
COPY --from=builder /app ./
RUN addgroup -S app && adduser -S app -G app
USER app

EXPOSE 4000
ENV NODE_ENV=production
CMD ["node", "server.js"]
