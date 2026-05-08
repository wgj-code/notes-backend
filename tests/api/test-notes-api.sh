#!/bin/bash
# 6A Demo · Notes API Test Script
# Usage: SUPABASE_URL=https://xxx.supabase.co ACCESS_TOKEN=xxx API_KEY=xxx bash test-notes-api.sh

set -euo pipefail

SUPABASE_URL="${SUPABASE_URL:?Set SUPABASE_URL}"
ACCESS_TOKEN="${ACCESS_TOKEN:?Set ACCESS_TOKEN (Supabase auth token)}"
API_KEY="${API_KEY:?Set API_KEY (Supabase anon key)}"
PASS=0
FAIL=0

assert_status() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✅ $desc (HTTP $actual)"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $desc — expected HTTP $expected, got $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -q "$needle"; then
    echo "  ✅ $desc"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $desc — '$needle' not found"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Notes API Tests ==="
echo ""

# AT-1: List notes (authenticated)
echo "AT-1: GET /notes (authenticated)"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "apikey: $API_KEY" \
  "$SUPABASE_URL/rest/v1/notes?select=*&order=updated_at.desc")
assert_status "List notes returns 200" "200" "$STATUS"

# AT-2: Create note
echo "AT-2: POST /notes (create)"
CREATE_RESP=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "apikey: $API_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{"title":"API Test Note","content":"Created by test script"}' \
  "$SUPABASE_URL/rest/v1/notes")
CREATE_STATUS=$(echo "$CREATE_RESP" | tail -1)
CREATE_BODY=$(echo "$CREATE_RESP" | head -n -1)
assert_status "Create note returns 201" "201" "$CREATE_STATUS"

NOTE_ID=$(echo "$CREATE_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])" 2>/dev/null || echo "")
if [ -n "$NOTE_ID" ]; then
  assert_contains "Created note has title" "API Test Note" "$CREATE_BODY"
  echo "  📝 Created note ID: $NOTE_ID"
else
  echo "  ⚠️  Could not extract note ID"
  FAIL=$((FAIL + 1))
fi

# AT-3: Update note
if [ -n "$NOTE_ID" ]; then
  echo "AT-3: PATCH /notes/:id (update)"
  UPDATE_RESP=$(curl -s -w "\n%{http_code}" \
    -X PATCH \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "apikey: $API_KEY" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{"title":"Updated Title"}' \
    "$SUPABASE_URL/rest/v1/notes?id=eq.$NOTE_ID&select=*")
  UPDATE_STATUS=$(echo "$UPDATE_RESP" | tail -1)
  UPDATE_BODY=$(echo "$UPDATE_RESP" | head -n -1)
  assert_status "Update note returns 200" "200" "$UPDATE_STATUS"
  assert_contains "Updated note has new title" "Updated Title" "$UPDATE_BODY"
fi

# AT-4: Soft delete note (via RPC to bypass PostgREST RLS bug)
if [ -n "$NOTE_ID" ]; then
  echo "AT-4: RPC soft_delete_note"
  DELETE_RESP=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "apikey: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"p_note_id\":\"$NOTE_ID\"}" \
    "$SUPABASE_URL/rest/v1/rpc/soft_delete_note")
  DELETE_STATUS=$(echo "$DELETE_RESP" | tail -1)
  assert_status "Soft delete returns 204" "204" "$DELETE_STATUS"
fi

# AT-5: No token returns empty array (Supabase PostgREST standard: auth.uid()=null → RLS filters all)
echo "AT-5: GET /notes (no token → 200 empty)"
RESP=$(curl -s -w "\n%{http_code}" \
  -H "apikey: $API_KEY" \
  "$SUPABASE_URL/rest/v1/notes?select=*")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -n -1)
assert_status "No token returns 200" "200" "$STATUS"
if [ "$BODY" = "[]" ]; then
  echo "  ✅ Returns empty array (RLS blocks all rows)"
  PASS=$((PASS + 1))
else
  echo "  ❌ Expected empty array, got: $BODY"
  FAIL=$((FAIL + 1))
fi

# AT-6: RLS isolation (this requires a second user token — placeholder)
echo "AT-6: RLS isolation (requires second user token — run manually)"
echo "  ⏭️  Skipped (needs USER_B_ACCESS_TOKEN)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
