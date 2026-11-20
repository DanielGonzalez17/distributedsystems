FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY catalog.js /usr/share/nginx/catalog.js
COPY catalog.css /usr/share/nginx/catalog.css
COPY site1/ /usr/share/nginx/html/
EXPOSE 80
