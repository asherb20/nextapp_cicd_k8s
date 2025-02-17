# Build Stage
## Use Node.js 22 as the base image
FROM node:22 AS builder
## Set working directory inside the container
WORKDIR /app
## Copy package.json first for caching efficiency
COPY package.json ./
## Install dependencies
RUN npm install
## Copy all source code into container
COPY . .
## Run build
RUN npm run build

# Production Stage
## Use Node.js 22 as the base image
FROM node:22
## Set working directory inside the container
WORKDIR /app
## Copy app directory from builder stage
COPY --from=builder /app ./
# Expose the port
EXPOSE 3000
# Run the application when the container starts
CMD [ "npm", "start" ]