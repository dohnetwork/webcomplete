FROM debian:buster
#FROM ubuntu:18.04
LABEL maintainer="doh"

# Let the container know that there is no tty
ENV DEBIAN_FRONTEND noninteractive
ENV NGINX_VERSION 1.19.10-1~buster
ENV php_conf /etc/php/7.4/fpm/php.ini
ENV fpm_conf /etc/php/7.4/fpm/pool.d/www.conf
ENV COMPOSER_VERSION 2.0.13

# Install Basic Requirements
RUN buildDeps='curl gcc make autoconf libc-dev zlib1g-dev pkg-config' \
    && set -x \
    && apt-get update \
    && apt-get install --no-install-recommends $buildDeps --no-install-suggests -q -y gnupg2 dirmngr wget apt-transport-https lsb-release ca-certificates \
    && \
    NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
	  found=''; \
	  for server in \
		  ha.pool.sks-keyservers.net \
		  hkp://keyserver.ubuntu.com:80 \
		  hkp://p80.pool.sks-keyservers.net:80 \
		  pgp.mit.edu \
	  ; do \
		  echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
		  apt-key adv --batch --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
	  done; \
    test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
    echo "deb http://nginx.org/packages/mainline/debian/ buster nginx" >> /etc/apt/sources.list \
    && wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -q -y \
            apt-utils \
            nano \
            zip \
            unzip \
            python-pip \
            python-setuptools \
            git \
            libmemcached-dev \
            libmemcached11 \
            libmagickwand-dev \
            nginx=${NGINX_VERSION} \
            php7.4-fpm \
            php7.4-cli \
            php7.4-bcmath \
            php7.4-dev \
            php7.4-common \
            php7.4-opcache \
            php7.4-readline \
            php7.4-mbstring \
            php7.4-curl \
            php7.4-gd \
            php7.4-imagick \
            php7.4-mysql \
            php7.4-zip \
            php7.4-pgsql \
            php7.4-intl \
            php7.4-xml \
            php-pear \
    && pecl -d php_suffix=7.4 install -o -f redis memcached \
    && mkdir -p /run/php \
    && pip install wheel \
    && pip install supervisor supervisor-stdout \
    && echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d \
    && rm -rf /etc/nginx/conf.d/default.conf \
    && sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" ${php_conf} \
    && sed -i -e "s/memory_limit\s*=\s*.*/memory_limit = 256M/g" ${php_conf} \
    && sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" ${php_conf} \
    && sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" ${php_conf} \
    && sed -i -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" ${php_conf} \
    && sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.4/fpm/php-fpm.conf \
    && sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" ${fpm_conf} \
    && sed -i -e "s/pm.max_children = 5/pm.max_children = 4/g" ${fpm_conf} \
    && sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" ${fpm_conf} \
    && sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" ${fpm_conf} \
    && sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" ${fpm_conf} \
    && sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" ${fpm_conf} \
    && sed -i -e "s/www-data/nginx/g" ${fpm_conf} \
    && sed -i -e "s/^;clear_env = no$/clear_env = no/" ${fpm_conf} \
    && echo "extension=redis.so" > /etc/php/7.4/mods-available/redis.ini \
    && echo "extension=memcached.so" > /etc/php/7.4/mods-available/memcached.ini \
    && echo "extension=imagick.so" > /etc/php/7.4/mods-available/imagick.ini \
    && ln -sf /etc/php/7.4/mods-available/redis.ini /etc/php/7.4/fpm/conf.d/20-redis.ini \
    && ln -sf /etc/php/7.4/mods-available/redis.ini /etc/php/7.4/cli/conf.d/20-redis.ini \
    && ln -sf /etc/php/7.4/mods-available/memcached.ini /etc/php/7.4/fpm/conf.d/20-memcached.ini \
    && ln -sf /etc/php/7.4/mods-available/memcached.ini /etc/php/7.4/cli/conf.d/20-memcached.ini \
    && ln -sf /etc/php/7.4/mods-available/imagick.ini /etc/php/7.4/fpm/conf.d/20-imagick.ini \
    && ln -sf /etc/php/7.4/mods-available/imagick.ini /etc/php/7.4/cli/conf.d/20-imagick.ini \
    # Install Composer
    && curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
    && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
    && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
    && php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION} \
    && rm -rf /tmp/composer-setup.php \
    # Clean up
    && rm -rf /tmp/pear \
    && apt-get purge -y --auto-remove $buildDeps \
    && apt-get clean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*

# Supervisor config
COPY ./supervisord.conf /etc/supervisord.conf

# Override nginx's default config
COPY ./default.conf /etc/nginx/conf.d/default.conf

# Override default nginx welcome page
COPY html /usr/share/nginx/html

# Copy Scripts
COPY ./start.sh /start.sh

EXPOSE 80
#################################################################
#RUN  apt-get install --no-install-recommends --no-install-suggests -q -y  \
#&&  curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -

#Download appropriate package for the OS version
#Choose only ONE of the following, corresponding to your OS version
#Debian 10
##RUN curl https://packages.microsoft.com/config/debian/10/prod.list > /etc/apt/sources.list.d/mssql-release.list
#exit
##RUN  apt-get update
##RUN  ACCEPT_EULA=Y apt-get install -y msodbcsql17
# optional: for bcp and sqlcmd
##RUN ACCEPT_EULA=Y apt-get install -y mssql-tools
##RUN echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
##RUN source ~/.bashrc
# optional: for unixODBC development headers
##RUN sudo apt-get install -y unixodbc-dev
# optional: kerberos library for debian-slim distributions
##RUN sudo apt-get install -y libgssapi-krb5-2

# install Microsoft SQL Server requirements.
ENV ACCEPT_EULA=Y
RUN apt-get update -y && apt-get update \
  && apt-get install -y --no-install-recommends curl gcc g++ gnupg unixodbc-dev php7.4-dev build-essential make \
  && pecl install sqlsrv \ 
  && pecl install pdo_sqlsrv \
  && echo "; priority=20\nextension=sqlsrv.so\n" > /etc/php/7.4/mods-available/sqlsrv.ini \
  && echo "; priority=30\nextension=pdo_sqlsrv.so\n" > /etc/php/7.4/mods-available/pdo_sqlsrv.ini \
  && phpenmod -v 7.4 sqlsrv pdo_sqlsrv
##printf "; priority=20\nextension=sqlsrv.so\n" > /etc/php/8.0/mods-available/sqlsrv.ini
##printf "; priority=30\nextension=pdo_sqlsrv.so\n" > /etc/php/8.0/mods-available/pdo_sqlsrv.ini

#  && echo "extension=pdo_sqlsrv.so" >> `php --ini | grep "Scan for additional .ini files" | sed -e "s|.*:\s*||"`/30-pdo_sqlsrv.ini \
#    && echo "extension=sqlsrv.so" >> `php --ini | grep "Scan for additional .ini files" | sed -e "s|.*:\s*||"`/30-sqlsrv.ini \
#    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*


# Add SQL Server ODBC Driver 17 for Ubuntu 18.04
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
  && curl https://packages.microsoft.com/config/debian/10/prod.list > /etc/apt/sources.list.d/mssql-release.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends --allow-unauthenticated msodbcsql17 mssql-tools libgssapi-krb5-2 \
  && echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile \
  && echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
RUN apt-get install -y locales && echo "en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" > /etc/locale.gen && locale-gen
#RUN sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
#RUN locale-gen
#RUN  pecl install sqlsrv
# && apt-get -y --no-install-recommends install msodbcsql17 unixodbc-dev \
#    && pecl install sqlsrv \
#    && pecl install pdo_sqlsrv \
#    && echo "extension=pdo_sqlsrv.so" >> `php --ini | grep "Scan for additional .ini files" | sed -e "s|.*:\s*||"`/30-pdo_sqlsrv.ini \
#    && echo "extension=sqlsrv.so" >> `php --ini | grep "Scan for additional .ini files" | sed -e "s|.*:\s*||"`/30-sqlsrv.ini \
#    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

##############################################################3



CMD ["/start.sh"]
