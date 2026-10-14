# ZEGA-ALERT backend — production image
FROM node:20-alpine

ENV NODE_ENV=production
WORKDIR /app

# Install production dependencies first (better layer caching)
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Application source
COPY . .

# Writable uploads dir (used only when Firebase Storage is not configured)
RUN mkdir -p uploads

EXPOSE 5000
CMD ["npm", "run", "start:deploy"]
