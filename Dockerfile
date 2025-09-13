FROM public.ecr.aws/nginx/nginx:alpine
RUN rm -rf /usr/share/nginx/html/*
COPY ./Brain-Tasks-App/dist /usr/share/nginx/html
RUN rm /etc/nginx/conf.d/default.conf
RUN echo 'server { listen 3000; server_name localhost; root /usr/share/nginx/html; index index.html index.htm; location / { try_files $uri $uri/ /index.html; } }' > /etc/nginx/conf.d/default.conf
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]
