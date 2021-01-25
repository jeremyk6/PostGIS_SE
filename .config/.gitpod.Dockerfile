FROM debian:buster

ENV PGADMIN_SETUP_EMAIL="geonum@geonum"
ENV PGADMIN_SETUP_PASSWORD="geonum"
ENV HOME="/home/gitpod"
ENV PGDATA="$HOME/databases/pgsql_data"
ENV WINDOW_MANAGER="icewm"

# Installation des paquets
RUN apt update && apt upgrade -y &&\
apt install -y --no-install-recommends curl ca-certificates gnupg ruby sudo &&\
curl https://www.pgadmin.org/static/packages_pgadmin_org.pub | apt-key add &&\
sh -c 'echo "deb https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/buster pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list && apt update' &&\
apt install -y postgresql-11-pgrouting osm2pgrouting pgadmin4-web

#
# VNC & QGIS zone
#

RUN useradd -l -u 33333 -G sudo -md /home/gitpod -s /bin/bash -p gitpod gitpod

RUN sudo apt-get update && \
    sudo apt-get install -yq xvfb x11vnc xterm openjfx libopenjfx-java icewm qgis git && \
    sudo rm -rf /var/lib/apt/lists/*

# Install novnc
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc \
    && git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify
COPY .config/.novnc-index.html /opt/novnc/index.html

# Add VNC startup script
COPY .config/.start-vnc-session.sh /usr/bin/start-vnc-session.sh
RUN chmod +x /usr/bin/start-vnc-session.sh

# This is a bit of a hack. At the moment we have no means of starting background
# tasks from a Dockerfile. This workaround checks, on each bashrc eval, if the X
# server is running on screen 0, and if not starts Xvfb, x11vnc and novnc.
RUN echo "export DISPLAY=:0" >> /home/gitpod/.bashrc
RUN echo "[ ! -e /tmp/.X0-lock ] && (/usr/bin/start-vnc-session.sh &> /tmp/display-\${DISPLAY}.log)" >> /home/gitpod/.bashrc

# Configuration de IceWM
COPY .config/.icewm $HOME/.icewm
RUN chown -R gitpod:gitpod $HOME/.icewm

# Configuration de Postgre pour la connexion distante
RUN echo "listen_addresses = '*'" >> /etc/postgresql/11/main/postgresql.conf &&\
echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/11/main/pg_hba.conf &&\
sed -i 's/local   all             all                                     peer/local   all             all                                     md5/g' /etc/postgresql/11/main/pg_hba.conf

# Magie pour lancer Postgre en non-root
RUN sed -i.bkp -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers &&\
su - gitpod -c "/usr/lib/postgresql/11/bin/initdb -D $PGDATA" &&\
ruby -i -pe "sub /^#(unix_socket_directories = ).*/, %q(\1'$PGDATA')" "$PGDATA/postgresql.conf"

# Configuration Apache & pgAdmin4
RUN /usr/pgadmin4/bin/setup-web.sh --yes
RUN ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load \
    && chown -R gitpod:gitpod /etc/apache2 /var/run/apache2 /var/lock/apache2 /var/log/apache2 &&\
    chown -R gitpod:gitpod /var/lib/pgadmin /var/log/pgadmin/
COPY --chown=gitpod:gitpod .config/.apache2/ /etc/apache2/

# Configuration de la BDD pour gitpod
USER gitpod
RUN /usr/lib/postgresql/11/bin/pg_ctl start &&\
psql -h localhost postgres -c "ALTER USER gitpod WITH SUPERUSER CREATEDB CREATEROLE LOGIN;" &&\
psql -h localhost postgres -c "ALTER USER gitpod WITH PASSWORD 'geonum'" &&\
psql -h localhost postgres -c "CREATE DATABASE gitpod;" &&\
/usr/lib/postgresql/11/bin/pg_ctl stop