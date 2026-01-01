# Use an official Node.js runtime as a base image
FROM node:16-alpine

# Set the working directory in the container to /app
WORKDIR /app

# Copy the package.json and package-lock.json files
# This is a best practice to leverage Docker's layer caching
COPY package*.json ./

# Install the application's dependencies
RUN npm install

# Copy the rest of the application's source code into the image
COPY . .

# Your app binds to port 3000, so you'll want to expose it
EXPOSE 3000

# The command to start the development server
CMD ["npm", "start"]
