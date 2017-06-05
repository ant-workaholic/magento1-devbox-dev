#/bin/bash
FROM ihorchernin/magento1-devbox


#####################################
# Soft for developers               #
#####################################
# Added SSH                         #
# Added XDebug (use SSH connection) #
# Removed mysqld service            #
# Added sendmail                    #

#Install sertificates for *.cc domain
RUN mkdir -p /etc/nginx/cert \
  && openssl req -new -x509 -days 365 -sha1 -newkey rsa:1024 -nodes \
          -keyout /etc/apache/cert/server.key \
          -out /etc/apache/cert/server.crt \
          -subj '/C=UA/ST=Kiev/L=Kiev/O=My Inc./OU=Department/CN=*.cc' \
  # Xdebug
  # tools
  # Sudo
  # Sendmail
  # openssh-server
  && yum -y update \
  && yum install -y net-tools \
                    htop \
                    nano \
                    php-pecl-xdebug \
                    sudo \
                    openssh-server \
                    sendmail \
  && yum -y clean all \

  ####### Enable SSH access ########
  # https://docs.docker.com/engine/examples/running_ssh_service/
  && mkdir /var/run/sshd -p \
  && echo 'root:dev' | chpasswd \
  && echo 'magento:dev' | chpasswd \

  # SSH login fix. Otherwise user is kicked off after login
  && sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd \
  && echo 'export VISIBLE=now' >> /etc/profile \
  # prevent notices on SSH login
  && touch /var/log/lastlog

ENV NOTVISIBLE 'in users profile'
EXPOSE 22

ADD init-files /init-files

RUN cp /init-files/sshd_config /etc/ssh/sshd_config \
  && ssh-keygen -t rsa1 -f /etc/ssh/ssh_host_rsa_key \
  && ssh-keygen -t dsa  -f /etc/ssh/ssh_host_dsa_key \
  # Install authorized key for root and magento user
  && cp /init-files/id_rsa.pub /root/ \
  && mkdir -p /root/.ssh /home/magento/.ssh \
  && cat /root/id_rsa.pub >> /root/.ssh/authorized_keys \
  && rm -f /root/id_rsa.pub \
  && chmod og-rwx -R /root/.ssh \
  && cp -r /root/.ssh /home/magento/ \
  && chown magento:magento -R /home/magento/.ssh \
  ####### EOB Enable ssh access #######

  # Copy supervisord files
  && cp /init-files/supervisord_*.ini /etc/supervisord.d/ \

  # Get Xdebug switcher and disable XDebug
  # && curl -Ls https://raw.github.com/rikby/xdebug-switcher/master/download | bash && xd_swi off
  # Add static file (v0.6.0)
  && cp /init-files/xd_swi /usr/local/bin/xd_swi \
  && chmod +x /usr/local/bin/xd_swi && xd_swi off \

  # Added Xdebug config for SSH connections
  && cp /init-files/xdebug.ini /etc/php.d/xdebug.ini.join \
  && xd_file=$(php -i | grep xdebug.ini | grep -oE '/.+xdebug.ini')  \
  && cat /etc/php.d/xdebug.ini.join >> ${xd_file}  \
  && rm -f /etc/php.d/xdebug.ini.join  \
  && xd_swi restart-command -- sudo supervisorctl restart php-fpm \

  # Add magento user into sudoers
  && echo 'magento ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers \

  # remove second time this config because it appears somehow
  && rm -f /etc/nginx/conf.d/default.conf

