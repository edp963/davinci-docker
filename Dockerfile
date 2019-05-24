FROM java:8-jre

LABEL MAINTAINER="edp_support@groups.163.com"

RUN cd / \
	&& mkdir -p /opt/davinci\
	&& wget https://github.com/edp963/davinci/releases/download/v0.3.0-beta.5/davinci-assembly_3.0.1-0.3.1-SNAPSHOT-dist-beta.5.zip \
	&& unzip davinci-assembly_3.0.1-0.3.1-SNAPSHOT-dist-beta.5.zip -d /opt/davinci

ADD phantomjs-2.1.1 /opt/phantomjs-2.1.1
RUN chmod +x /opt/phantomjs-2.1.1/phantomjs
ADD bin/start.sh /opt/davinci/bin/start.sh
RUN chmod +x /opt/davinci/bin/start.sh
ADD config/application.yml /opt/davinci/config/application.yml

ENV DAVINCI3_HOME /opt/davinci
ENV PHANTOMJS_HOME /opt/phantomjs-2.1.1

WORKDIR /opt/davinci

CMD ["./bin/start-server.sh"]

EXPOSE 8080