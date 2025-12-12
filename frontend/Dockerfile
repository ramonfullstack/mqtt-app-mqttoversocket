FROM nginx:alpine

# Copy frontend files
COPY index.html /usr/share/nginx/html/
COPY js /usr/share/nginx/html/js/
COPY css /usr/share/nginx/html/css/

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
