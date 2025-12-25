# Replace "FROM <minimal-image>" with the Node.js image
FROM node:18

# Set working directory
WORKDIR /app

# Copy source files and install dependencies
COPY package*.json ./
RUN npm install --production

COPY . .

EXPOSE 4000

# Set environment variables as needed, then start the app
CMD ["npm", "start"]
