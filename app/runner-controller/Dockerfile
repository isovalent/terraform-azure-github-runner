FROM node:22-slim AS build

WORKDIR /usr/src/app
COPY . .

EXPOSE 80

RUN yarn --production

FROM gcr.io/distroless/nodejs22-debian12

ENV NODE_ENV=production

COPY --from=build /usr/src/app /usr/src/app
WORKDIR /usr/src/app

CMD ["app.js"]
