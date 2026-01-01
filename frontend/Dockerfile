# ---------- Build stage ----------
FROM node:18 AS build

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm install

# Copy source
COPY . .

# Build-time argument for backend URL
ARG REACT_APP_LINK_SERVICE_URL
ENV REACT_APP_LINK_SERVICE_URL=$REACT_APP_LINK_SERVICE_URL

# Build React app
RUN npm run build

# ---------- Production stage ----------
FROM nginx:alpine

RUN apk add --no-cache aws-cli

RUN rm -rf /usr/share/nginx/html/*
COPY --from=build /app/build /usr/share/nginx/html

EXPOSE 80

CMD ["/bin/sh","-c","aws s3 cp s3://terraform-bucket-aw123/frontend/config.js /usr/share/nginx/html/config.js && nginx -g 'daemon off;'"]
