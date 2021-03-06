FROM debian:buster

ENV PGADMIN_SETUP_EMAIL="geonum@geonum"
ENV PGADMIN_SETUP_PASSWORD="geonum"
ENV HOME="/workspace/home"
ENV PGDATA="$HOME/databases/pgsql_data"
ENV WINDOW_MANAGER="icewm"

# Changement de la locale en français

RUN apt update && apt upgrade -y && apt install -y locales locales-all
ENV LC_ALL fr_FR.UTF-8
ENV LANG fr_FR.UTF-8
ENV LANGUAGE fr_FR.UTF-8

# Création de l'utilisateur Gitpod
RUN mkdir /workspace &&\
useradd -l -u 33333 -G sudo -md $HOME -s /bin/bash -p gitpod gitpod

# Installation des paquets
RUN apt install -y --no-install-recommends curl wget ca-certificates gnupg software-properties-common ruby sudo &&\
curl https://www.pgadmin.org/static/packages_pgadmin_org.pub | apt-key add &&\
sh -c 'echo "deb https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/buster pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list' &&\
wget -qO - https://qgis.org/downloads/qgis-2020.gpg.key | sudo gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/qgis-archive.gpg --import &&\
chmod a+r /etc/apt/trusted.gpg.d/qgis-archive.gpg &&\
add-apt-repository "deb https://qgis.org/debian `lsb_release -c -s` main" &&\
apt update && apt install -yq xvfb x11vnc xterm openjfx libopenjfx-java icewm qgis git postgresql-11-pgrouting osm2pgrouting osm2pgsql osmctools pgadmin4-web && \
sudo rm -rf /var/lib/apt/lists/*

#
# VNC zone
#

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
RUN echo "export DISPLAY=:0" >> $HOME/.bashrc
RUN echo "[ ! -e /tmp/.X0-lock ] && (/usr/bin/start-vnc-session.sh &> /tmp/display-\${DISPLAY}.log)" >> $HOME/.bashrc

# Configuration de IceWM
COPY .config/.icewm $HOME/.icewm
RUN chown -R gitpod:gitpod $HOME/.icewm

#
# PostgreSQL/pgAdmin zone
#

# Configuration de Postgre pour la connexion distante
RUN echo "listen_addresses = '*'" >> /etc/postgresql/11/main/postgresql.conf &&\
echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/11/main/pg_hba.conf &&\
sed -i 's/local   all             all                                     peer/local   all             all                                     md5/g' /etc/postgresql/11/main/pg_hba.conf

# Magie pour lancer Postgre en non-root
RUN sed -i.bkp -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers &&\
su - gitpod -c "/usr/lib/postgresql/11/bin/initdb --locale=fr_FR.utf8 -D $PGDATA" &&\
ruby -i -pe "sub /^#(unix_socket_directories = ).*/, %q(\1'$PGDATA')" "$PGDATA/postgresql.conf"

# Configuration Apache & pgAdmin4
COPY .config/.servers.json /tmp/servers.json
RUN /usr/pgadmin4/bin/setup-web.sh --yes &&\
/usr/pgadmin4/venv/bin/python3 /usr/pgadmin4/web/setup.py --load-servers /tmp/servers.json --user geonum@geonum
RUN ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load \
    && chown -R gitpod:gitpod /etc/apache2 /var/run/apache2 /var/lock/apache2 /var/log/apache2 &&\
    chown -R gitpod:gitpod /var/lib/pgadmin /var/log/pgadmin/ &&\
    sed -i 's/ENHANCED_COOKIE_PROTECTION = True/ENHANCED_COOKIE_PROTECTION = False/g' /usr/pgadmin4/web/config.py 
COPY --chown=gitpod:gitpod .config/.apache2/ /etc/apache2/

# Configuration de la BDD pour gitpod
USER gitpod
RUN /usr/lib/postgresql/11/bin/pg_ctl start &&\
psql -h localhost postgres -c "ALTER USER gitpod WITH SUPERUSER CREATEDB CREATEROLE LOGIN;" &&\
psql -h localhost postgres -c "ALTER USER gitpod WITH PASSWORD 'geonum'" &&\
psql -h localhost postgres -c "CREATE DATABASE gitpod;" &&\
/usr/lib/postgresql/11/bin/pg_ctl stop

# Comme workspace est écrasé à la création du conteneur, on déplace son contenu dans un autre dossier dont on
# redéplacera le contenu dans /workspace au lancement du conteneur pour permettre la persistance des données
USER root
RUN cp -R /workspace /workspace.old && chown -R gitpod:gitpod /workspace.old