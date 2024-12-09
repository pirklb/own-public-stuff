FROM node:22-alpine

RUN mkdir /app && chown node:node /app

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm install
COPY / ./

ENV IDM_SERVER=idm.lkw-walter.com
ENV IDM_CLIENTID=rbpmrest

ENTRYPOINT ["node","/app/index.js"]



