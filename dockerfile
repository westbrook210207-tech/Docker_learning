# syntax=docker/dockerfile:1

# -----------------------------------------------------------------------------
# Stage 1: Build Environment
# -----------------------------------------------------------------------------
# We use a specific version of the official Node.js Alpine image.
# Alpine is a minimal Linux distribution, keeping the image size small.
# Pinning the exact version (e.g., 20.11.1-alpine3.19) is crucial for reproducible builds.
FROM node:20.11.1-alpine3.19 AS builder

# Set the working directory inside the container.
# All subsequent instructions (RUN, COPY, CMD) will be executed in this directory.
WORKDIR /app

# Copy ONLY package.json and package-lock.json first.
# This leverages Docker's layer caching mechanism. If dependencies haven't changed,
# Docker will reuse the cached layer for the 'npm ci' step, significantly speeding up builds.
COPY package*.json ./

# Install project dependencies.
# 'npm ci' (clean install) is preferred over 'npm install' in production/CI environments.
# It strictly installs the versions specified in package-lock.json and ensures a clean state.
RUN npm ci

# Copy the rest of the application source code into the container.
# This is done after installing dependencies to utilize the cache from the previous step.
# Make sure to have a .dockerignore file to exclude local node_modules and other unnecessary files.
COPY . .

# Run the build script (if you are using TypeScript, React, Angular, etc.).
# If this is a plain Node.js backend app, you might not need this step.
# RUN npm run build

# -----------------------------------------------------------------------------
# Stage 2: Production Environment
# -----------------------------------------------------------------------------
# Start a new, fresh image for the final production container.
# This is a "multi-stage build". It discards all the build tools and intermediate files
# from the 'builder' stage, resulting in a much smaller and more secure final image.
FROM node:20.11.1-alpine3.19 AS production

# Set the Node environment to production.
# This tells Node.js and many frameworks (like Express) to optimize for performance
# (e.g., caching templates, logging less aggressively).
ENV NODE_ENV=production

# Set the working directory for the production stage.
WORKDIR /app

# Create a non-root user and group.
# Running containers as the root user is a major security risk.
# Alpine comes with a default 'node' user that we can use.
# We ensure the app directory is owned by this non-root user.
RUN chown -R node:node /app

# Switch to the non-root 'node' user for all subsequent commands.
USER node

# Copy only the necessary files from the 'builder' stage.
# We copy the node_modules and the source code (or built artifacts).
# --chown=node:node ensures the copied files have the correct permissions.
COPY --chown=node:node --from=builder /app/node_modules ./node_modules
COPY --chown=node:node --from=builder /app ./

# Document the port that the container listens on at runtime.
# EXPOSE does not actually publish the port; it functions as documentation for whoever runs the container.
EXPOSE 3000

# Specify the default command to run when the container starts.
# Use the "exec form" (JSON array) rather than the "shell form" (string).
# This ensures that Node.js receives Unix signals (like SIGTERM) properly, allowing for graceful shutdowns.
CMD ["node", "src/index.js"]

