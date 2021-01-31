FROM  alpine:3.9.5 AS build

ARG DAVINCI_ZIP

ADD $DAVINCI_ZIP /

RUN mkdir -p /opt/davinci && unzip $DAVINCI_ZIP -d /opt/davinci \
&& rm -rf $DAVINCI_ZIP \
&& cp -v /opt/davinci/config/application.yml.example /opt/davinci/config/application.yml

ADD bin/docker-entrypoint.sh /opt/davinci/bin/docker-entrypoint.sh

RUN chmod +x /opt/davinci/bin/docker-entrypoint.sh

FROM  openjdk:8u242-jdk AS base

LABEL MAINTAINER="edp_support@groups.163.com"

COPY --from=build /opt /opt

ENV DAVINCI3_HOME /opt/davinci
ENV OPENSSL_CONF=/etc/ssl/

WORKDIR /opt/davinci

CMD ["./bin/start-server.sh"]

EXPOSE 8080