FROM maven:3.6-jdk-8
MAINTAINER Nathan Walker <nathan@rylath.net>, Sean Óg Crudden <og.crudden@gmail.com>

ARG AGENCYID="1"
ARG AGENCYNAME="GOHART"
ARG GTFS_URL="http://gohart.org/google/google_transit.zip"
ARG GTFSRTVEHICLEPOSITIONS="http://realtime.prod.obahart.org:8088/vehicle-positions"
ARG TRANSITCLOCK_PROPERTIES="config/transitclock.properties"

ENV AGENCYID ${AGENCYID}
ENV AGENCYNAME ${AGENCYNAME}
ENV GTFS_URL ${GTFS_URL}
ENV GTFSRTVEHICLEPOSITIONS ${GTFSRTVEHICLEPOSITIONS}
ENV TRANSITCLOCK_PROPERTIES ${TRANSITCLOCK_PROPERTIES}

ENV TRANSITCLOCK_CORE /transitclock-core

RUN apt-get update \
        && apt-get install -y postgresql-client \
        && apt-get install -y git-core \
        && apt-get install -y vim

RUN apt-get install -y locales locales-all
ENV LC_ALL pl_PL.utf8
ENV LANG pl_PL.utf8
ENV LANGUAGE pl_PL.utf8

ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH
RUN mkdir -p "$CATALINA_HOME"
WORKDIR $CATALINA_HOME

ENV TOMCAT_MAJOR 8
ENV TOMCAT_VERSION 8.0.43
ENV TOMCAT_TGZ_URL https://archive.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz

RUN set -x \
        && curl -fSL "$TOMCAT_TGZ_URL" -o tomcat.tar.gz \
        && tar -xvf tomcat.tar.gz --strip-components=1 \
        && rm bin/*.bat \
        && rm tomcat.tar.gz*

EXPOSE 8093


# Install json parser so we can read API key for CreateAPIKey output

RUN wget http://stedolan.github.io/jq/download/linux64/jq

RUN chmod +x ./jq

RUN cp jq /usr/bin/

WORKDIR /
RUN mkdir /usr/local/transitclock
RUN mkdir /usr/local/transitclock/db
RUN mkdir /usr/local/transitclock/config
RUN mkdir /usr/local/transitclock/logs
RUN mkdir /usr/local/transitclock/cache
RUN mkdir /usr/local/transitclock/data
RUN mkdir /usr/local/transitclock/test
RUN mkdir /usr/local/transitclock/test/config

WORKDIR /usr/local/transitclock

ADD bin/one-jar-boot-0.97.jar /usr/local/transitclock/bin/one-jar-boot-0.97.jar

#RUN  curl -s https://api.github.com/repos/TheTransitClock/transitime/releases/latest | jq -r ".assets[].browser_download_url" | grep 'Core.jar\|api.war\|web.war' | xargs -L1 wget
RUN git clone https://github.com/goeuropa/transitime-1.git /transitime-core
WORKDIR /transitime-core
RUN git checkout goeuropa
RUN mvn install -DskipTests
RUN cp /transitime-core/transitclock/target/*.jar /usr/local/transitclock/
RUN cp /transitime-core/transitclockApi/target/api.war  /usr/local/tomcat/webapps
RUN cp /transitime-core/transitclockWebapp/target/web.war  /usr/local/tomcat/webapps


#ADD transitime/transitclockWebapp/target/web.war /usr/local/transitclock/
#ADD transitime/transitclockApi/target/api.war /usr/local/transitclock/
#ADD transitime/transitclock/target/Core.jar /usr/local/transitclock/

# Deploy API which talks to core using RMI calls.
# RUN mv api.war  /usr/local/tomcat/webapps

# Deploy webapp which is a UI based on the API.
# RUN mv web.war  /usr/local/tomcat/webapps

WORKDIR /usr/local/transitclock

# Scripts required to start transiTime.
ADD bin/check_db_up.sh /usr/local/transitclock/bin/check_db_up.sh
ADD bin/generate_sql.sh /usr/local/transitclock/bin/generate_sql.sh
ADD bin/create_tables.sh /usr/local/transitclock/bin/create_tables.sh
ADD bin/create_api_key.sh /usr/local/transitclock/bin/create_api_key.sh
ADD bin/create_webagency.sh /usr/local/transitclock/bin/create_webagency.sh
ADD bin/import_gtfs.sh /usr/local/transitclock/bin/import_gtfs.sh
ADD bin/start_transitclock.sh /usr/local/transitclock/bin/start_transitclock.sh
ADD bin/get_api_key.sh /usr/local/transitclock/bin/get_api_key.sh
ADD bin/import_avl.sh /usr/local/transitclock/bin/import_avl.sh
ADD bin/process_avl.sh /usr/local/transitclock/bin/process_avl.sh
ADD bin/update_traveltimes.sh /usr/local/transitclock/bin/update_traveltimes.sh
ADD bin/set_config.sh /usr/local/transitclock/bin/set_config.sh

# Handy utility to allow you connect directly to database
ADD bin/connect_to_db.sh /usr/local/transitclock/bin/connect_to_db.sh

ENV PATH="/usr/local/transitclock/bin:${PATH}"

# This is a way to copy in test data to run a regression test.
ADD data/avl.csv /usr/local/transitclock/data/avl.csv
ADD data/gtfs_hart_old.zip /usr/local/transitclock/data/gtfs_hart_old.zip

RUN \
        sed -i 's/\r//' /usr/local/transitclock/bin/*.sh &&\
        chmod 777 /usr/local/transitclock/bin/*.sh

ADD config/postgres_hibernate.cfg.xml /usr/local/transitclock/config/hibernate.cfg.xml
ADD ${TRANSITCLOCK_PROPERTIES} /usr/local/transitclock/config/transitclock.properties

# This adds the transitime configs to test.
ADD config/test/* /usr/local/transitclock/config/test/

EXPOSE 8093

ENV TZ=Europe/Warsaw
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

CMD ["/start_transitclock.sh"]