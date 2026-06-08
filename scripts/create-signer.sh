#!/usr/bin/env bash
# Create a self-signed code-signing certificate for DesktopNavigator.
# Idempotent — bails out if "DesktopNavigatorSigner" already exists.

set -euo pipefail

if security find-identity -v -p codesigning | grep -q "DesktopNavigatorSigner"; then
    echo "==> DesktopNavigatorSigner already exists. Skipping."
    exit 0
fi

CONF=$(mktemp -t dn-cert-conf)
KEY=$(mktemp -t dn-signer.key)
CRT=$(mktemp -t dn-signer.crt)
P12=$(mktemp -t dn-signer.p12)
trap 'rm -f "$CONF" "$KEY" "$CRT" "$P12"' EXIT

cat > "$CONF" <<'EOF'
[req]
distinguished_name = req_dn
prompt = no
x509_extensions = v3_ext

[req_dn]
CN = DesktopNavigatorSigner
O = cloudcodetree

[v3_ext]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF

echo "==> Generating self-signed code-signing cert (10 year validity)..."
# Use macOS's bundled LibreSSL (/usr/bin/openssl) rather than Homebrew's
# OpenSSL — modern OpenSSL produces PKCS#12 files that `security import` cannot
# parse, even with -legacy.
/usr/bin/openssl req -x509 -newkey rsa:2048 \
    -keyout "$KEY" \
    -out "$CRT" \
    -days 3650 -nodes -sha256 \
    -config "$CONF" >/dev/null 2>&1

/usr/bin/openssl pkcs12 -export \
    -in "$CRT" \
    -inkey "$KEY" \
    -out "$P12" \
    -passout pass:dummypass \
    -name "DesktopNavigatorSigner" >/dev/null

echo "==> Importing into login keychain..."
security import "$P12" \
    -k ~/Library/Keychains/login.keychain-db \
    -P "dummypass" \
    -T /usr/bin/codesign \
    -T /usr/bin/security >/dev/null

echo "==> Trusting cert for code signing in login keychain..."
security add-trusted-cert -r trustRoot -p codeSign \
    -k ~/Library/Keychains/login.keychain-db \
    "$CRT"

echo
echo "==> Done. Code-signing identity available:"
security find-identity -v -p codesigning | grep DesktopNavigatorSigner
