services:
  db:
    image: postgres:alpine
    restart: always
    volumes:
      - db:/var/lib/postgresql/data
    env_file:
      - db.env

  redis:
    image: redis:alpine
    restart: always

  app:
    image: nextcloud:production-fpm-alpine
    restart: always
    volumes:
      - nextcloud:/var/www/html
    environment:
      - POSTGRES_HOST=db
      - REDIS_HOST=redis
    env_file:
      - db.env
    depends_on:
      - db
      - redis

  web:
    build: ./web
    restart: always
    ports:
      - 127.0.0.1:8080:80
    volumes:
      - nextcloud:/var/www/html:ro
    depends_on:
      - app

  cron:
    image: nextcloud:production-fpm-alpine
    restart: always
    volumes:
      - nextcloud:/var/www/html
    entrypoint: /cron.sh
    depends_on:
      - db
      - redis

  ghost:
    image: ghost
    restart: always
    ports:
      - 8081:2368
    volumes:
      - ghost-data:/var/lib/ghost/content
    environment:
      - url=https://${url}

volumes:
  db:
  nextcloud:
  ghost-data:
