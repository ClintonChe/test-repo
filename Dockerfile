# Use an official Nginx runtime as a parent image
FROM nginx:alpine

# Copy the static content from the repository to the Nginx html directory
COPY . /usr/share/nginx/html

# Expose port 80 to the outside world
EXPOSE 80
