# https://hub.docker.com/_/nginx
FROM nginx

COPY src/html /usr/share/nginx/html
