FROM php:7.3

MAINTAINER ctwj

# 设置时区
RUN /bin/cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo 'Asia/Shanghai' > /etc/timezone

# 通过apt安装 包
RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        vim \
        curl \
        wget \
        git \
        zip \
        libz-dev \
        libssl-dev \
    && apt-get clean \
    && apt-get autoremove

# 安装 composer
RUN curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer \
    && composer self-update --clean-backups
    #&& composer config -g repositories.packagist composer https://packagist.phpcomposer.com

# 安装redis mongodb
RUN pecl install redis && docker-php-ext-enable redis \
    && pecl install mongodb && docker-php-ext-enable mongodb \
    && pecl clear-cache

# 安装 pdo_mysql gd iconv
RUN docker-php-ext-install pdo_mysql  \
    && docker-php-ext-install -j$(nproc) iconv \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd

# 编译安装 hiredis
RUN wget https://github.com/redis/hiredis/archive/v0.13.3.tar.gz -O hiredis.tar.gz \
    && mkdir -p hiredis \
    && tar -xf hiredis.tar.gz -C hiredis --strip-components=1 \
    && rm hiredis.tar.gz \
    && ( \
        cd hiredis \
        && make -j$(nproc) \
        && make install \
        && ldconfig \
    ) \
    && rm -r hiredis

# 编译安装 swoole
RUN wget https://github.com/swoole/swoole-src/archive/v4.4.2.tar.gz -O swoole.tar.gz \
    && mkdir -p swoole \
    && tar -xf swoole.tar.gz -C swoole --strip-components=1 \
    && rm swoole.tar.gz \
    && ( \
        cd swoole \
        && phpize \
        && ./configure --enable-async-redis --enable-mysqlnd --enable-coroutine --enable-openssl --enable-http2 \
        && make -j$(nproc) \
        && make install \
    ) \
    && rm -r swoole \
    && docker-php-ext-enable swoole

# 编译安装 inotify
RUN wget http://pecl.php.net/get/inotify-2.0.0.tgz -O inotify.tgz \
    && mkdir -p inotify \
    && tar -xf inotify.tgz -C inotify --strip-components=1 \
    && rm inotify.tgz \
    && ( \
        cd inotify \
        && phpize \
        && ./configure \
        && make \
        && make install \
    ) \
    && rm -r inotify \
    && docker-php-ext-enable inotify

# 编译安装 yaconf
RUN wget https://codeload.github.com/laruence/yaconf/zip/master -O yaconf.zip \
    && mkdir -p inotify \
    && unzip yaconf.zip  \
    && rm yaconf.zip  \
    && ( \
        cd yaconf-master \
        && phpize \
        && ./configure \
        && make \
        && make install \
    ) \
    && rm -r yaconf-master \
    && docker-php-ext-enable yaconf \
    && sed -i '$a\yaconf.directory=/var/www/easyswoole/config' /usr/local/etc/php/conf.d/docker-php-ext-pdo_mysql.ini


RUN wget https://github.com/easy-swoole/easyswoole/archive/3.2.6.zip -O  easyswoole.zip \
    && unzip easyswoole.zip -d /var/www \
    && mv /var/www/easyswoole-3.2.6 /var/www/easyswoole

# 进入工作目录
WORKDIR /var/www/easyswoole

# 运行composer 安装依赖
RUN composer install --no-dev\
    && composer dump-autoload -o \
    && composer clearcache

# easyswoole框架安装
RUN php bin/easyswoole install

#COPY nginx_default /etc/nginx/sites-enabled/default

# 指定在docker允许时指定的端口进行转发
EXPOSE 9501

# 运行容器时执行命令
CMD sh -c 'php bin/easyswoole start -d'
