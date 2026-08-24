FROM apache/spark:3.5.6-scala2.12-java17-python3-ubuntu

USER root
COPY jobs /opt/demo/jobs
RUN mkdir -p /opt/spark/jars-extra && chown -R 185:0 /opt/demo /opt/spark/jars-extra
USER 185

