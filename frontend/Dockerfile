FROM nginx:1.29-alpine

RUN apk upgrade --no-cache

COPY frontend/nginx.conf /etc/nginx/conf.d/default.conf
COPY frontend/docker-entrypoint.d/40-render-config.sh /docker-entrypoint.d/40-render-config.sh
COPY frontend/ssl/ /etc/nginx/ssl/
COPY frontend/index.html /usr/share/nginx/html/index.html
COPY frontend/owners/index.html /usr/share/nginx/html/owners/index.html
COPY frontend/owners/new.html /usr/share/nginx/html/owners/new.html
COPY frontend/vets.html /usr/share/nginx/html/vets.html
COPY frontend/assets/site.css /usr/share/nginx/html/assets/site.css
COPY frontend/assets/app.js /usr/share/nginx/html/assets/app.js
COPY src/main/resources/static/resources/images/pets.png /usr/share/nginx/html/assets/pets.png
COPY src/main/resources/static/resources/images/favicon.png /usr/share/nginx/html/assets/favicon.png

RUN chmod +x /docker-entrypoint.d/40-render-config.sh

EXPOSE 80 443

HEALTHCHECK --interval=10s --timeout=5s --retries=12 CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
