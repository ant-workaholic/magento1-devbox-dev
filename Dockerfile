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
RUN mkdir -p /etc/httpd/cert && \
    openssl req -new -x509 -days 365 -sha1 -newkey rsa:1024 -nodes \
          -keyout /etc/httpd/cert/server.key \
          -out /etc/httpd/cert/server.crt \
          -subj '/C=UA/ST=Kiev/L=Kiev/O=My Inc./OU=Department/CN=*.cc'

# Xdebug
# tools
# Sudo
# Sendmail
# openssh-server
RUN yum -y update && yum install -y net-tools \
  htop \
  nano \
  php-pecl-xdebug \
  sudo \
  openssh-server \
  sendmail && \
  yum -y clean all

####### Enable SSH access ########
# https://docs.docker.com/engine/examples/running_ssh_service/
RUN mkdir /var/run/sshd -p
RUN echo 'root:dev' | chpasswd
RUN echo 'magento:dev' | chpasswd

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV NOTVISIBLE 'in users profile'
RUN echo 'export VISIBLE=now' >> /etc/profile

EXPOSE 22
# ---------
# prevent notices on SSH login
RUN touch /var/log/lastlog

COPY init-files/sshd_config /etc/ssh/sshd_config
RUN ssh-keygen -t rsa1 -f /etc/ssh/ssh_host_rsa_key && \
    ssh-keygen -t dsa  -f /etc/ssh/ssh_host_dsa_key

# Install authorized key for root and magento user
COPY init-files/id_rsa.pub /root/
RUN mkdir -p /root/.ssh /home/magento/.ssh && \
    cat /root/id_rsa.pub >> /root/.ssh/authorized_keys && \
    rm -f /root/id_rsa.pub && \
    chmod og-rwx -R /root/.ssh && \
    cp -r /root/.ssh /home/magento/ && \
    chown magento:magento -R /home/magento/.ssh

####### EOB Enable ssh access #######

# Copy supervisord files
ADD init-files/supervisord_*.ini /etc/supervisord.d/

# Get Xdebug switcher and disable XDebug
#RUN curl -Ls https://raw.github.com/rikby/xdebug-switcher/master/download | bash && xd_swi off
# Add static file (v0.6.0)
COPY init-files/xd_swi /usr/local/bin/xd_swi
RUN chmod +x /usr/local/bin/xd_swi && xd_swi off

# Added Xdebug config for SSH connections
COPY init-files/xdebug.ini /etc/php.d/xdebug.ini.join
RUN xd_file=$(php -i | grep xdebug.ini | grep -oE '/.+xdebug.ini') && \
  cat /etc/php.d/xdebug.ini.join >> ${xd_file} && \
  rm -f /etc/php.d/xdebug.ini.join && \
  xd_swi restart-command -- sudo supervisorctl restart php-fpm

# Add magento user into sudoers
RUN echo 'magento ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
