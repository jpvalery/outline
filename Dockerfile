# syntax=docker/dockerfile:1.2
ARG APP_PATH=/opt/outline
FROM node:14-buster AS deps-common

ARG APP_PATH
WORKDIR $APP_PATH
COPY ./package.json ./yarn.lock ./

# ---
FROM deps-common AS deps-dev
RUN yarn install --no-optional --frozen-lockfile --network-timeout 100000 && \
  yarn cache clean

# ---
FROM deps-common AS deps-prod
RUN yarn install --production=true --frozen-lockfile --network-timeout 100000 && \
  yarn cache clean

# ---
FROM node:14-buster AS builder

ARG APP_PATH
WORKDIR $APP_PATH

COPY . .
COPY --from=deps-dev $APP_PATH/node_modules ./node_modules
RUN yarn build

# ---
FROM node:14-buster AS runner

ARG APP_PATH
WORKDIR $APP_PATH
ENV NODE_ENV production

COPY --from=builder $APP_PATH/build ./build
COPY --from=builder $APP_PATH/server ./server
COPY --from=builder $APP_PATH/public ./public
COPY --from=builder $APP_PATH/.sequelizerc ./.sequelizerc
COPY --from=deps-prod $APP_PATH/node_modules ./node_modules
COPY --from=builder $APP_PATH/package.json ./package.json

RUN addgroup --gid 1001 --system nodejs && \
  adduser --system nodejs --uid 1001 && \
  chown -R nodejs:nodejs $APP_PATH/build

USER nodejs

EXPOSE 3000
CMD ["yarn", "start"]
