#!/usr/bin/env bash
#
# Chép phản hồi THẬT của API vào test/contract/fixtures/.
#
# App đã ba lần đoán một tên trường mà API không gửi — `assignee_names`,
# `stats`, `project_name` — và cả ba đều im lặng: không lỗi, không log, chỉ là
# null hoặc 0 mãi mãi. Test hợp đồng đọc những bản ghi này để phát hiện lần thứ
# tư, và bản ghi phải là phản hồi thật chứ không phải hình dạng ai đó tưởng
# tượng ra.
#
# Chạy lại mỗi khi hình dạng phản hồi đổi:
#
#   tool/capture_contract.sh http://localhost:8000 manager@omnicrm.vn demo1234
#
# Cần một tenant có ít nhất: một team, một kế hoạch có nhóm việc, và một công
# việc đã gán người + có checklist. Bản ghi thiếu dữ liệu làm test hợp đồng
# xanh một cách vô nghĩa.
set -euo pipefail

BASE="${1:-http://localhost:8000}"
EMAIL="${2:?email}"
PASSWORD="${3:?password}"
OUT="$(dirname "$0")/../test/contract/fixtures"

mkdir -p "$OUT"

api() { curl -sS -H "Authorization: Bearer $TOKEN" "$BASE/api/v1$1"; }

echo "Đăng nhập $EMAIL…"
LOGIN=$(curl -sS -X POST "$BASE/api/v1/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
TOKEN=$(echo "$LOGIN" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
[ -n "$TOKEN" ] || { echo "Không lấy được token: $LOGIN"; exit 1; }

# Token đăng nhập chưa có tenant. Mọi endpoint công việc đều đòi nó.
TENANT=$(api /auth/tenants | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
TOKEN=$(curl -sS -X POST "$BASE/api/v1/auth/switch-tenant" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"tenant_id\":\"$TENANT\"}" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

capture() { echo "  $2.json"; api "$1" > "$OUT/$2.json"; }

capture "/teams?per_page=5" teams_index
capture "/projects?per_page=5" projects_index

# Lấy một kế hoạch CÓ việc, để tasks_index không rỗng.
PLAN=$(grep -o '"id":"[^"]*"' "$OUT/projects_index.json" | head -1 | cut -d'"' -f4)
capture "/tasks?project_id=$PLAN&per_page=5" tasks_index

TASK=$(grep -o '"id":"[^"]*"' "$OUT/tasks_index.json" | head -1 | cut -d'"' -f4)
capture "/tasks/$TASK" tasks_show

echo
echo "Xong. Đọc lại các file trước khi commit — chúng là dữ liệu thật của một"
echo "tenant, nên đừng chép từ production."
