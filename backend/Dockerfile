# ---------- Stage 1 ----------
FROM node:18.9.1 AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .


# ---------- Stage 2 ----------
FROM gcr.io/distroless/nodejs18-debian11

WORKDIR /app

COPY --from=builder /app /app

EXPOSE 4000

CMD ["server.js"]