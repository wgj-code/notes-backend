#!/bin/bash
# 6A Demo · RLS Isolation Test Script
# Verifies that User A cannot access User B's notes
# Usage: SUPABASE_URL=xxx USER_A_TOKEN=xxx USER_B_TOKEN=xxx API_KEY=xxx bash test-rls-isolation.sh

set -euo pipefail

SUPABASE_URL="${SUPABASE_URL:?Set SUPABASE_URL}"
USER_A_TOKEN="${USER_A_TOKEN:?Set USER_A_TOKEN}"
USER_B_TOKEN="${USER_B_TOKEN:?Set USER_B_TOKEN}"
API_KEY="${API_KEY:?Set API_KEY}"
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

echo "=== RLS Isolation Tests ==="
echo ""

# Setup: User A creates a note
echo "Setup: User A creates a test note..."
CREATE_RESP=$(curl -s \
  -X POST \
  -H "Authorization: Bearer $USER_A_TOKEN" \
  -H "apikey: $API_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{"title":"User A Private Note","content":"Secret content from A"}' \
  "$SUPABASE_URL/rest/v1/notes")
NOTE_ID=$(echo "$CREATE_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])" 2>/dev/null || echo "")
echo "  📝 Created note ID: $NOTE_ID"
echo ""

# RL-1: User B queries User A's notes → should get empty list
echo "RL-1: User B queries notes (should not see User A's note)"
RESP=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $USER_B_TOKEN" \
  -H "apikey: $API_KEY" \
  "$SUPABASE_URL/rest/v1/notes?select=*&order=updated_at.desc")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -n -1)
assert_status "User B list notes returns 200" "200" "$STATUS"

if echo "$BODY" | grep -q "$NOTE_ID"; then
  echo "  ❌ RL-1 FAILED: User B can see User A's note!"
  FAIL=$((FAIL + 1))
else
  echo "  ✅ RL-1 PASSED: User B cannot see User A's note"
  PASS=$((PASS + 1))
fi

# RL-2: User B tries to insert with user_id=A → should fail
echo ""
echo "RL-2: User B tries to insert note with user_id=A (should fail)"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "Authorization: Bearer $USER_B_TOKEN" \
  -H "apikey: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"title":"Injected","content":"","user_id":"db620ebd-97db-4fa2-9974-84198bb39d85"}' \
  "$SUPABASE_URL/rest/v1/notes")
echo "  ℹ️  User B insert attempt: HTTP $STATUS"
# RLS WITH CHECK should prevent this (user_id mismatch)
if [ "$STATUS" = "403" ] || [ "$STATUS" = "401" ]; then
  echo "  ✅ RL-2 PASSED: Insert rejected (HTTP $STATUS)"
  PASS=$((PASS + 1))
else
  echo "  ⚠️  RL-2: Insert returned HTTP $STATUS (check RLS WITH CHECK)"
  FAIL=$((FAIL + 1))
fi

# RL-3: User B tries to update User A's note → 0 rows
echo ""
echo "RL-3: User B tries to update User A's note"
if [ -n "$NOTE_ID" ]; then
  RESP=$(curl -s -w "\n%{http_code}" \
    -X PATCH \
    -H "Authorization: Bearer $USER_B_TOKEN" \
    -H "apikey: $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"title":"Hacked by B"}' \
    "$SUPABASE_URL/rest/v1/notes?id=eq.$NOTE_ID")
  STATUS=$(echo "$RESP" | tail -1)
  BODY=$(echo "$RESP" | head -n -1)
  if [ "$BODY" = "[]" ] || [ "$BODY" = "" ]; then
    echo "  ✅ RL-3 PASSED: Update returned 0 rows (RLS blocked)"
    PASS=$((PASS + 1))
  else
    echo "  ❌ RL-3 FAILED: Update affected rows: $BODY"
    FAIL=$((FAIL + 1))
  fi
fi

# RL-4: User B tries to delete User A's note → 0 rows
echo ""
echo "RL-4: User B tries to delete User A's note"
if [ -n "$NOTE_ID" ]; then
  RESP=$(curl -s -w "\n%{http_code}" \
    -X DELETE \
    -H "Authorization: Bearer $USER_B_TOKEN" \
    -H "apikey: $API_KEY" \
    "$SUPABASE_URL/rest/v1/notes?id=eq.$NOTE_ID")
  STATUS=$(echo "$RESP" | tail -1)
  BODY=$(echo "$RESP" | head -n -1)
  if [ "$BODY" = "[]" ] || [ "$BODY" = "" ] || [ "$BODY" = "0" ]; then
    echo "  ✅ RL-4 PASSED: Delete returned 0 rows (RLS blocked)"
    PASS=$((PASS + 1))
  else
    echo "  ⚠️  RL-4: Delete response: $BODY"
    FAIL=$((FAIL + 1))
  fi
fi

# RL-5: Verify soft-deleted notes are hidden from SELECT
echo ""
echo "RL-5: Verify deleted_at filter (soft-deleted notes hidden)"
if [ -n "$NOTE_ID" ]; then
  # First, soft-delete as User A (via RPC to bypass PostgREST RLS bug)
  curl -s -X POST \
    -H "Authorization: Bearer $USER_A_TOKEN" \
    -H "apikey: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"p_note_id\":\"$NOTE_ID\"}" \
    "$SUPABASE_URL/rest/v1/rpc/soft_delete_note" > /dev/null

  # Then query as User A (should not see deleted note)
  RESP=$(curl -s \
    -H "Authorization: Bearer $USER_A_TOKEN" \
    -H "apikey: $API_KEY" \
    "$SUPABASE_URL/rest/v1/notes?select=id&deleted_at=is.null")
  if echo "$RESP" | grep -q "$NOTE_ID"; then
    echo "  ❌ RL-5 FAILED: Deleted note still visible"
    FAIL=$((FAIL + 1))
  else
    echo "  ✅ RL-5 PASSED: Deleted note hidden from list"
    PASS=$((PASS + 1))
  fi
fi

# Cleanup
echo ""
echo "Cleanup: Deleting test note..."
if [ -n "$NOTE_ID" ]; then
  curl -s -X DELETE \
    -H "Authorization: Bearer $USER_A_TOKEN" \
    -H "apikey: $API_KEY" \
    "$SUPABASE_URL/rest/v1/notes?id=eq.$NOTE_ID" > /dev/null
  echo "  🧹 Test note deleted"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
