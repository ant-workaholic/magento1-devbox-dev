#/bin/bash
FROM ihorchernin/magento1-devbox

RUN yum -y update \
    yum clean all

RUN yum -y install openssh-server passwd \
    yum clean all

RUN yum install -y net-tools \
                        htop \
                        nano \
                        php-pecl-xdebug \
                        sudo \
                        sendmail

RUN mkdir /var/run/sshd

RUN yum install php56w-devel
RUN yum install gcc gcc-c++ autoconf automake --skip-broken
RUN pecl install Xdebug

RUN echo 'root:dev' | chpasswd
RUN echo 'magento:dev' | chpasswd
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# SSH login fix. Otherwise user is kicked off after login
RUN echo 'export VISIBLE=now' >> /etc/profile \
  # prevent notices on SSH login
  && touch /var/log/lastlog

EXPOSE 22

ADD init-files /init-files

COPY /init-files/supervisord_*.ini /etc/supervisord.d/

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
  && chown magento:magento -R /home/magento/.ssh

RUN cp /init-files/xdebug.ini /etc/php.d/xdebug.ini.join \
  && xd_file=$(php -i | grep xdebug.ini | grep -oE '/.+xdebug.ini')  \
  && cat /etc/php.d/xdebug.ini.join >> ${xd_file}  \
  && rm -f /etc/php.d/xdebug.ini.join

RUN cp /init-files/xd_swi /usr/local/bin/xd_swi \
      && chmod +x /usr/local/bin/xd_swi && xd_swi off