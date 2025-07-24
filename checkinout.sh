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
  echo -n "Enter Asset Tag (or 's<search>') [q to quit]: "
  read INPUT
  [ "$INPUT" = "q" ] && exit 0

  AUTH_HEADER="Authorization: Bearer $SNIPEIT_API_KEY"
  ACCEPT_HEADER="Accept: application/json"
  CONTENT_HEADER="Content-Type: application/json"

  # --- Asset tag resolve (supports s<search>) ---
  if echo "$INPUT" | grep -q "^s"; then
    QUERY="${INPUT#s}"
    echo "🔍 Searching for asset tags containing: '$QUERY'..."
    SEARCH_URL="$SNIPEIT_BASE_URL/api/v1/hardware?search=$QUERY&limit=100"
    SEARCH_RESPONSE=$(curl -s -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" "$SEARCH_URL")

    TMP_MATCHES="/tmp/matches_assets.txt"
    > "$TMP_MATCHES"

    echo "$SEARCH_RESPONSE" \
      | jq -r '.rows[] | select(.asset_tag and (.asset_tag | length == 8) and (.asset_tag | contains("'"$QUERY"'"))) | .asset_tag' \
      > "$TMP_MATCHES"

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

  # --- Get asset info ---
  ASSET_URL="$SNIPEIT_BASE_URL/api/v1/hardware?search=$ASSET_TAG&limit=100"
  RESPONSE=$(curl -s -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -H "$CONTENT_HEADER" "$ASSET_URL")

  # Ensure we grab the exact match
  ASSET=$(echo "$RESPONSE" | jq -r --arg TAG "$ASSET_TAG" '.rows[] | select(.asset_tag == $TAG)')
  if [ -z "$ASSET" ] || [ "$ASSET" = "null" ]; then
    echo "❌ Asset tag '$ASSET_TAG' not found."
    echo ""
    continue
  fi

  ASSET_ID=$(echo "$ASSET" | jq '.id')
  MODEL_NAME=$(echo "$ASSET" | jq -r '.model.name // "Unknown Model"')
  CURRENT_USER=$(echo "$ASSET" | jq -r '.assigned_to.name // empty')
  echo ""
  echo "📦 Asset:"
  echo "  Tag:    $ASSET_TAG"
  echo "  Model:  $MODEL_NAME"
  if [ -n "$CURRENT_USER" ]; then
    echo "  Status: Checked out to $CURRENT_USER"
  else
    echo "  Status: Not checked out"
  fi
  echo ""

  # --- If checked out, check it in ---
  if [ -n "$CURRENT_USER" ]; then
    echo "↩️  Checking it in..."
    CHECKIN_URL="$SNIPEIT_BASE_URL/api/v1/hardware/$ASSET_ID/checkin"
    CHECKIN_PAYLOAD=$(jq -n --arg note "Checked in via script" '{note: $note}')

    CHECKIN_RESPONSE=$(curl -s -X POST \
      -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -H "$CONTENT_HEADER" \
      -d "$CHECKIN_PAYLOAD" "$CHECKIN_URL")

    STATUS=$(echo "$CHECKIN_RESPONSE" | jq -r '.status // empty')
    if [ "$STATUS" = "success" ]; then
      echo "✅ Successfully checked in."
    else
      echo "❌ Check-in failed:"
      echo "$CHECKIN_RESPONSE"
      echo ""
      continue
    fi
    echo ""
  else
    echo "ℹ️  Asset was not checked out. Skipping check-in."
    echo ""
  fi

  # --- Prompt to checkout to a user ---
  while true; do
    echo -n "Enter LAST NAME to checkout to (blank to skip checkout): "
    read LNAME
    [ -z "$LNAME" ] && { echo "Skipping checkout."; echo ""; break; }

    echo "🔍 Searching users by last name '$LNAME'..."
    USERS_URL="$SNIPEIT_BASE_URL/api/v1/users?search=$LNAME&limit=100"
    USERS_RESPONSE=$(curl -s -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" "$USERS_URL")

    TMP_USERS="/tmp/matches_users.txt"
    > "$TMP_USERS"

    # Print "id|name" to temp file
    echo "$USERS_RESPONSE" \
      | jq -r '.rows[] | select(.last_name | test("'"$LNAME"'"; "i")) | "\(.id)|\(.name)"' \
      > "$TMP_USERS"

    USER_COUNT=$(wc -l < "$TMP_USERS")

    if [ "$USER_COUNT" -eq 0 ]; then
      echo "❌ No users found."
      continue
    elif [ "$USER_COUNT" -eq 1 ]; then
      LINE=$(head -n 1 "$TMP_USERS")
      USER_ID=$(echo "$LINE" | cut -d'|' -f1)
      USER_NAME=$(echo "$LINE" | cut -d'|' -f2-)
      echo "✅ Found: $USER_NAME (ID: $USER_ID)"
    else
      echo "Multiple users found:"
      i=1
      while IFS='|' read -r id name; do
        echo "$i) $name (ID: $id)"
        i=$((i + 1))
      done < "$TMP_USERS"

      while true; do
        echo -n "Select a number (1-$USER_COUNT): "
        read CHOICE
        if echo "$CHOICE" | grep -Eq '^[0-9]+$' && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "$USER_COUNT" ]; then
          LINE=$(sed -n "${CHOICE}p" "$TMP_USERS")
          USER_ID=$(echo "$LINE" | cut -d'|' -f1)
          USER_NAME=$(echo "$LINE" | cut -d'|' -f2-)
          break
        else
          echo "❌ Invalid selection."
        fi
      done
    fi

    echo "📤 Checking out asset $ASSET_TAG to $USER_NAME..."
    CHECKOUT_URL="$SNIPEIT_BASE_URL/api/v1/hardware/$ASSET_ID/checkout"
    CHECKOUT_PAYLOAD=$(jq -n \
      --arg note "Checked out via script" \
      --arg uid "$USER_ID" \
      '{checkout_to_type: "user", assigned_to: ($uid | tonumber), note: $note}')

    CHECKOUT_RESPONSE=$(curl -s -X POST \
      -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -H "$CONTENT_HEADER" \
      -d "$CHECKOUT_PAYLOAD" "$CHECKOUT_URL")

    STATUS=$(echo "$CHECKOUT_RESPONSE" | jq -r '.status // empty')
    if [ "$STATUS" = "success" ]; then
      echo "✅ Successfully checked out to $USER_NAME"
    else
      echo "❌ Checkout failed:"
      echo "$CHECKOUT_RESPONSE"
    fi

    echo ""
    break
  done
done
