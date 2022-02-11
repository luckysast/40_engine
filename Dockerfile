FROM ubuntu:focal

RUN apt update && apt install -y gnupg curl

RUN curl -sL https://nginx.org/keys/nginx_signing.key | apt-key add -

RUN echo "deb https://packages.nginx.org/unit/ubuntu/ focal unit \
deb-src https://packages.nginx.org/unit/ubuntu/ focal unit" > /etc/apt/sources.list.d/unit.list

RUN apt update && DEBIAN_FRONTEND="noninteractive" apt install -y golang unit-dev unit-go unit-perl unit-php

RUN cp -r /usr/share/gocode /root/go

RUN DEBIAN_FRONTEND="noninteractive" apt install -y php-dev php-pear

RUN pecl install -o -f redis && rm -rf /tmp/pear && echo "extension=redis.so" > /etc/php/7.4/embed/conf.d/redis.ini

RUN cp /etc/php/7.4/embed/conf.d/redis.ini /etc/php/7.4/cli/conf.d/.

RUN DEBIAN_FRONTEND="noninteractive" apt install -y build-essential libplack-perl libredis-perl libjson-perl libhttp-message-perl

RUN DEBIAN_FRONTEND="noninteractive" apt install -y npm && npm install -g --unsafe-perm unit-http

RUN yes | cpan Plack::Middleware::ReviseEnv

RUN mkdir /home/code_storage && chmod 777 /home/code_storage

COPY ./unit/nodeapp /projects/unit/nodeapp

WORKDIR /projects/unit/nodeapp/

RUN npm install

RUN npm link unit-http

COPY ./unit/goapp /projects/unit/goapp

WORKDIR /projects/unit/goapp/

RUN go build main.go

COPY ./unit/phpapp /projects/unit/phpapp

COPY ./unit/perlapp /projects/unit/perlapp

COPY ./unit/config.json /var/lib/unit/conf.json

RUN ln -sf /dev/stdout /var/log/unit.log

CMD ["unitd", "--no-daemon", "--control", "unix:/var/run/control.unit.sock"]
