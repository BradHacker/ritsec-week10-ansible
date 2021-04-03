# Base Image
FROM ubuntu:20.04

# Install Webmin
RUN apt update && \
  apt install -y wget gnupg gnupg1 gnupg2 && \
  echo "deb http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list && \
  wget -q -O- http://www.webmin.com/jcameron-key.asc | apt-key add && \
  apt update && \
  DEBIAN_FRONTEND=noninteractive apt install -yq webmin

# Expose Admin Port
EXPOSE 10000