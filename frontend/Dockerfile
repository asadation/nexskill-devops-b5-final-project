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

# Install AWS CLI v2
RUN apk add --no-cache curl unzip bash \
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" \
    && unzip /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# Remove default nginx html
RUN rm -rf /usr/share/nginx/html/*

# Copy build output
COPY --from=build /app/build /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Runtime command: copy config from S3 then start nginx
CMD ["/bin/sh","-c","aws s3 cp s3://terraform-bucket-aw123/frontend/app.js /usr/share/nginx/html/app.js && nginx -g 'daemon off;'"]
