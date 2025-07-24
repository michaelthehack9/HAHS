#!/bin/sh

# ===== Configuration =====

# Load API key from file
if [ -f key.txt ]; then
  SNIPEIT_API_KEY=$(cat key.txt)
else
  echo "❌ Error: key.txt not found. Please create it with your API key."
  exit 1
fi

if [ -z "$SNIPEIT_API_KEY" ]; then
  echo "❌ Error: key.txt is empty. Please add your API key."
  exit 1
fi

SNIPEIT_BASE_URL='http://ics.hasdhawks.org'  # No trailing slash
clear

while true; do
  echo -n "Enter Asset Tag: "
  read INPUT

  AUTH_HEADER="Authorization: Bearer $SNIPEIT_API_KEY"
  ACCEPT_HEADER="Accept: application/json"
  CONTENT_HEADER="Content-Type: application/json"

  if echo "$INPUT" | grep -q "^s"; then
    QUERY="${INPUT#s}"
    echo "🔍 Searching for asset tags containing: '$QUERY'..."

    SEARCH_URL="$SNIPEIT_BASE_URL/api/v1/hardware?search=$QUERY&limit=100"
    SEARCH_RESPONSE=$(curl -s -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" "$SEARCH_URL")

    # Prepare temp file
    TMP_MATCHES="/tmp/matches.txt"
    > "$TMP_MATCHES"
    echo "$SEARCH_RESPONSE" | jq -r '.rows[] | select(.asset_tag | length == 8 and contains("'"$QUERY"'")) | .asset_tag' > "$TMP_MATCHES"

    MATCH_COUNT=$(wc -l < "$TMP_MATCHES")

    if [ "$MATCH_COUNT" -eq 0 ]; then
      echo "❌ No matching asset tags found."
      echo ""
      continue
    elif [ "$MATCH_COUNT" -eq 1 ]; then
      ASSET_TAG=$(head -n 1 "$TMP_MATCHES")
      echo "✅ Found: $ASSET_TAG"
    else
      echo "Multiple matches found:"
      i=1
      while read -r tag; do
        echo "$i) $tag"
        i=$((i + 1))
      done < "$TMP_MATCHES"

      while true; do
        echo -n "Select a number (1-$MATCH_COUNT): "
        read CHOICE
        if echo "$CHOICE" | grep -Eq '^[0-9]+$' && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "$MATCH_COUNT" ]; then
          ASSET_TAG=$(sed -n "${CHOICE}p" "$TMP_MATCHES")
          break
        else
          echo "❌ Invalid selection."
        fi
      done
    fi
  else
    ASSET_TAG="$INPUT"
  fi

  # ==== Perform Audit ====
  AUDIT_URL="$SNIPEIT_BASE_URL/api/v1/hardware/audit"
  AUDIT_PAYLOAD=$(jq -n \
    --arg asset_tag "$ASSET_TAG" \
    --arg note "Audited via script" \
    '{asset_tag: $asset_tag, note: $note}')

  AUDIT_RESPONSE=$(curl -s -X POST \
    -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -H "$CONTENT_HEADER" \
    -d "$AUDIT_PAYLOAD" "$AUDIT_URL")

  STATUS=$(echo "$AUDIT_RESPONSE" | jq -r '.status // empty')

  echo ""
  if [ "$STATUS" = "success" ]; then
    echo "✅ Audit successfully created for Asset Tag $ASSET_TAG"
  else
    echo "❌ Audit failed:"
    echo "$AUDIT_RESPONSE"
  fi

  echo ""
done