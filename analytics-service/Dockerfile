# Use official Node.js image
FROM node:18-alpine

# Set working directory inside container
WORKDIR /app

# Copy package files first (for better caching)
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the app
COPY . .

# Expose the port your app runs on
# (change 3000 if your app uses a different port)
EXPOSE 4000

# Start the app
CMD ["node", "server.js"]
