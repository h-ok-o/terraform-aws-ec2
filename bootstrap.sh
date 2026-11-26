#!/bin/bash
# Amorçage court : installe nginx, lit le secret de SON environnement,
# publie une page qui affiche l'environnement et l'état du secret.
# Le secret n'est jamais écrit ni affiché ; seule une empreinte tronquée l'est.
set -euo pipefail

ENVIRONMENT="${environment}"
SECRET_PATH="${secret_parameter_path}"

dnf install -y nginx

# IMDSv2 : jeton de session puis lecture de la région
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region)

# Lecture du secret depuis Parameter Store grâce au profil IAM de l'instance
SECRET_STATUS="non"
FINGERPRINT="-"
if VALUE=$(aws ssm get-parameter --name "$SECRET_PATH" --with-decryption \
     --region "$REGION" --query Parameter.Value --output text 2>/dev/null); then
  SECRET_STATUS="oui"
  FINGERPRINT=$(printf '%s' "$VALUE" | sha256sum | cut -c1-8)
fi
unset VALUE

cat > /usr/share/nginx/html/index.html <<HTML
<!doctype html>
<html lang="fr">
<head><meta charset="utf-8"><title>NovaSphere Spaces</title></head>
<body>
  <h1>NovaSphere Spaces</h1>
  <p>Environnement : $ENVIRONMENT</p>
  <p>secret chargé : $SECRET_STATUS (empreinte : $FINGERPRINT)</p>
</body>
</html>
HTML

systemctl enable --now nginx
