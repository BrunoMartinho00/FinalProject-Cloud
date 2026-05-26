#!/bin/bash
# Script para construir e enviar versões para o DockerHub

# O teu utilizador
IMAGE_NAME="trevorlynn/product-service"

# Lê a versão que escreveste (ex: 1.0.1). Se não escreveres nada, usa "latest"
VERSION=${1:-"latest"}

echo "--- A construir a versão: $VERSION ---"

# 1. Construir
docker build -t ${IMAGE_NAME}:${VERSION} .

# 2. Se a versão não for "latest", cria também a tag latest
if [ "$VERSION" != "latest" ]; then
    echo "--- A atualizar a tag latest ---"
    docker tag ${IMAGE_NAME}:${VERSION} ${IMAGE_NAME}:latest
    docker push ${IMAGE_NAME}:latest
fi

# 3. Enviar a versão específica
echo "--- A enviar para o DockerHub ---"
docker push ${IMAGE_NAME}:${VERSION}

echo "--- Feito! ---"
