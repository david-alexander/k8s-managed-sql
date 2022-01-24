FROM node:14

WORKDIR /app
COPY fs/package.json .
COPY fs/yarn.lock .
COPY fs/.yarn ./.yarn
COPY fs/.yarnrc.yml .
RUN yarn

COPY fs .

ENTRYPOINT [ "yarn", "run", "start" ]
