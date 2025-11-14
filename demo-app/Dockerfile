FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --omit=dev

# Copy application code
COPY . .

# Build frontend if needed
RUN if [ -d "frontend" ]; then cd frontend && npm ci && npm run build; fi

EXPOSE 3000

CMD ["npm", "start"]
