# Compile once on the native builder architecture; the staged Play app is
# architecture-independent and is copied into each target runtime image.
FROM --platform=$BUILDPLATFORM eclipse-temurin:11-jdk AS build
WORKDIR /src

# Run the legacy Scala 2.13.4 build without JIT compilation. This avoids
# JVMCI/Graal compiler assertion failures observed on the Java 11 builder.
ENV JAVA_TOOL_OPTIONS="-Xint"

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://raw.githubusercontent.com/paulp/sbt-extras/master/sbt -o /usr/local/bin/sbt \
    && chmod +x /usr/local/bin/sbt

COPY . .
RUN sbt clean stage \
    && echo '--- generated cerebro launcher: Java detection ---' \
    && grep -n -C 8 -E 'No java installations|JAVA_HOME|javaHome|java_cmd|java_opts|java executable' target/universal/stage/bin/cerebro || true

# Runtime stage follows the requested target platform (amd64 or arm64).
FROM eclipse-temurin:11-jre
# The generated sbt-native-packager launcher also probes the conventional
# /usr/lib/jvm location when discovering Java installations.
ENV JAVA_HOME=/usr/lib/jvm/default-java \
    PATH="/usr/lib/jvm/default-java/bin:${PATH}" \
    CEREBRO_PORT=9000
WORKDIR /var/lib/cerebro

RUN mkdir -p /usr/lib/jvm \
    && ln -sfn /opt/java/openjdk /usr/lib/jvm/default-java \
    && test -x "${JAVA_HOME}/bin/java" \
    && "${JAVA_HOME}/bin/java" -version \
    && groupadd --system --gid 10001 cerebro \
    && useradd --system --uid 10001 --gid cerebro --home-dir /var/lib/cerebro cerebro \
    && mkdir -p /opt/cerebro /var/lib/cerebro \
    && chown -R cerebro:cerebro /opt/cerebro /var/lib/cerebro

COPY --from=build --chown=cerebro:cerebro /src/target/universal/stage/ /opt/cerebro/

USER cerebro
EXPOSE 9000
VOLUME ["/var/lib/cerebro"]

ENTRYPOINT ["/opt/cerebro/bin/cerebro"]
CMD ["-Dhttp.address=0.0.0.0"]
