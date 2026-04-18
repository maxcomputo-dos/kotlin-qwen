# Usa una imagen base de Ubuntu 22.04
FROM ubuntu:22.04

# Evita preguntas interactivas durante la instalación
ENV DEBIAN_FRONTEND=noninteractive

# Instala dependencias básicas
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    zip \
    gnupg \
    lsb-release \
    ca-certificates \
    xz-utils \
    sudo \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# ==================== JAVA 21 (Temurin) ====================
RUN mkdir -p /usr/local/java && \
    curl -fsSL "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.5%2B11/OpenJDK21U-jdk_x64_linux_hotspot_21.0.5_11.tar.gz" \
    -o /tmp/java.tar.gz && \
    tar -xzf /tmp/java.tar.gz -C /usr/local/java --strip-components=1 && \
    rm /tmp/java.tar.gz

ENV JAVA_HOME=/usr/local/java
ENV PATH=$JAVA_HOME/bin:$PATH

# ==================== GRADLE 9.3.1 ====================
RUN mkdir -p /opt/gradle && \
    curl -fsSL "https://services.gradle.org/distributions/gradle-9.3.1-bin.zip" -o /tmp/gradle.zip && \
    unzip -d /opt/gradle /tmp/gradle.zip && \
    rm /tmp/gradle.zip

ENV GRADLE_HOME=/opt/gradle/gradle-9.3.1
ENV PATH=$GRADLE_HOME/bin:$PATH

# ==================== ANDROID SDK ====================
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=$ANDROID_HOME
RUN mkdir -p $ANDROID_HOME/cmdline-tools && \
    curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -o /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d $ANDROID_HOME/cmdline-tools && \
    mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip

# Instala plataformas y build tools necesarias (Android 34 y 35)
RUN yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager \
    "platforms;android-34" \
    "platforms;android-35" \
    "build-tools;34.0.0" \
    "build-tools;35.0.0" \
    "platform-tools" || true

ENV PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

# ==================== NODE.JS LTS (v20) y pnpm ====================
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

RUN npm install -g pnpm

# ==================== QWEN CLI ====================
RUN npm install -g @qwen-code/qwen-code

# ==================== CREAR USUARIO NODE ====================
# Crear usuario 'node' con UID 1000 (compatible con Codespaces)
RUN groupadd --gid 1000 node \
    && useradd --uid 1000 --gid node --shell /bin/bash --create-home node

# Otorgar permisos de sudo sin contraseña (opcional, pero útil)
RUN echo "node ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Ajustar permisos de directorios clave para el usuario node
RUN chown -R node:node $ANDROID_HOME \
    && chown -R node:node /opt/gradle \
    && chown -R node:node /usr/local/java \
    && mkdir -p /home/node/.gradle && chown node:node /home/node/.gradle \
    && mkdir -p /home/node/.android && chown node:node /home/node/.android

# Cambiar al usuario node
USER node
WORKDIR /home/node

# Configurar variables de entorno para el usuario
ENV ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    JAVA_HOME=/usr/local/java \
    GRADLE_HOME=/opt/gradle/gradle-9.3.1 \
    PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$JAVA_HOME/bin:$GRADLE_HOME/bin:$PATH

# Comando por defecto
CMD [ "/bin/bash" ]
