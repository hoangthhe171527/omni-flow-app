# Tạo team → chọn thành viên → tạo dự án — thiết kế

**Ngày:** 2026-09-10
**Phạm vi:** `omni-flow-app` (chính), `omni-flow-api` (một trường mới), `omni-flow` (web — hiện nền)
**Dự án con:** #3 trong ba. #1 "Dòng việc sống" đã xong; #2 "Avatar" là spec riêng.
**Từ vựng:** **team** = org unit `type=team`; **dự án** = `omni_projects`; **nhóm việc** = `section`.

---

## 1. Vấn đề

Tạo team xong thì rơi vào hư không.

Màn "Team mới" hiện chỉ có hai ô — tên và mô tả — rồi `Navigator.pop(true)`.
Người vừa tạo quay lại một danh sách team, và **cái team vừa tạo trống rỗng**:
không người, không dự án. Muốn dùng được nó họ phải tự đoán ra hai bước tiếp
theo và tự đi tìm hai màn khác.

Hai thứ thiếu:

1. **Không chọn được thành viên.** API `POST /teams` **đã nhận `member_ids`
   từ lâu** (`CreateTeamRequest`, và `MongoTeamRepository::create` ghi thẳng
   vào org unit). App chỉ gửi `name` + `description`. Một trường server sẵn
   sàng nhận mà client chưa bao giờ gửi — cùng họ với những lỗi im lặng khác
   của dự án này, chỉ khác chiều.
2. **Không có đường sang tạo dự án.** Team không có dự án thì không có bảng
   việc, không có nhóm việc, không có gì để giao. Nó là một cái tên.

Và một thứ nữa người dùng nêu: **màn tạo dự án trống trải** — chỉ toàn ô nhập
trên nền trắng.

---

## 2. Những gì đã chốt

| Câu hỏi | Chốt |
|---|---|
| Chọn thành viên ở đâu | **Một ô TRONG form tạo team**, mở sheet chọn người. Không phải màn riêng. |
| Bắt buộc chọn không | **Không.** Tạo team một mình rồi thêm sau là chuyện bình thường. |
| Sau khi tạo team | **Đi thẳng sang màn tạo dự án**, `team_id` điền sẵn. |
| Nền màn tạo dự án | **Bộ nền có sẵn**, không phải ảnh tải lên. |

### 2.1 Vì sao không làm màn thứ ba

Ba màn nối tiếp cho một việc hai trường là bắt người dùng bấm "Tiếp" hai lần
để làm cái họ đã nhìn thấy hết ngay từ đầu. Ô "Thành viên" nằm trong form, mở
một sheet, chọn xong quay lại — bấm "Tạo team" **một lần**.

Cái đáng nối tiếp là **team → dự án**, vì đó là hai thực thể khác nhau với hai
bộ trường khác nhau.

### 2.2 Vì sao nền là BỘ CÓ SẴN, không phải ảnh tải lên

Ảnh tải lên nghe hay hơn, nhưng nó mang theo ba việc mà bộ nền có sẵn không có:
một endpoint upload nữa, dung lượng lưu trữ, và bài toán **chữ đè lên ảnh** —
tên dự án viết trên một tấm ảnh sáng hoặc rối sẽ không đọc được, và người tạo
không biết trước điều đó lúc chọn.

Tám gradient dựng theo bảng màu Viomni luôn đủ tương phản với chữ trắng, không
tốn byte nào, và làm xong trong một task. Khi nào có người thật sự đòi ảnh
riêng thì mở rộng — lúc đó mới biết họ đòi để làm gì.

---

## 3. Dữ liệu & API

### 3.1 Thành viên: không đổi gì ở server

`POST /teams` đã nhận `member_ids` (`CreateTeamRequest` dòng 22–23), và
`MongoTeamRepository::create()` ghi nó vào org unit. App chỉ cần **gửi**.

Lưu ý phải nhớ khi đụng vào vùng này: `OrgUnit` **không dùng**
`BelongsToTenant`, nên không có global scope — mọi truy vấn tự
`where('tenant_id', …)`. `MongoTeamRepository` đã làm đúng; đừng thêm truy vấn
mới nào bỏ qua nó.

### 3.2 Nền dự án: một trường chuỗi

Thêm `cover` vào `CreateProjectRequest` và `UpdateProjectRequest`:

```php
'cover' => ['nullable', 'string', 'max:32'],
```

**Là TÊN nền, không phải URL** — ví dụ `teal-1`, `amber-2`. Client dịch tên đó
thành gradient. Lưu URL sẽ mời người sau nhét một địa chỉ ảnh bất kỳ vào và
biến trường này thành một đường upload không ai thiết kế.

Không cần migration: `omni_projects` là tài liệu Mongo, dự án cũ không có khoá
này và client đọc ra `null` → nền mặc định.

### 3.3 Nền đi ra những đâu

`ProjectDTO::toArray()` trả nguyên `attributes`, nên `cover` tự đi ra cùng mọi
phản hồi dự án. Không phải sửa gì thêm.

---

## 4. App

### 4.1 Form tạo team

```
┌─ Team mới ─────────────────┐
│ Tên team                   │
│ [Tổ phục chế            ]  │
│                            │
│ Mô tả                      │
│ [Đàn cơ và đàn điện     ]  │
│                            │
│ Thành viên            3 ▸  │  ← chạm mở sheet
│ (HN)(T)(M)                 │  ← ảnh/chữ cái đầu người đã chọn
│                            │
│ [      Tạo team        ]   │
└────────────────────────────┘
```

Ô "Thành viên" hiện **số người đã chọn** và một dải avatar nhỏ. Trống thì ghi
"Chưa chọn ai — thêm sau cũng được", để người dùng biết bỏ qua là hợp lệ chứ
không phải mình đang bỏ sót.

### 4.2 Sheet chọn người

Tái dùng `teamMembersProvider` đã có (`memberships` + `identity/users`, đã gộp
sẵn tên). Danh sách có ô tìm kiếm, mỗi dòng một checkbox.

**Quyền:** danh sách này cần `membership.members.read`. Tạo team đã đòi
`organization.org_units.create` (vai `manager` trở lên), nên ai mở được màn này
thì cũng đọc được danh bạ — không có vai nào rơi vào cảnh thấy ô "Thành viên"
rồi bấm ra danh sách rỗng. **Vẫn phải kiểm bằng chạy thật**, vì hai quyền này
do từng workspace tự cấu hình.

### 4.3 Tạo xong → sang màn dự án

`pushReplacement`, **không** `push`: bấm Back từ màn "Dự án mới" phải về danh
sách team, không quay lại một form tạo team đã dùng xong. Quay lại đó rồi bấm
"Tạo team" lần nữa là tạo ra một team trùng tên mà người dùng không định tạo.

Màn "Dự án mới" nhận `teamId` qua tham số route và **điền sẵn**, không cho đổi
ở luồng này — người dùng vừa tạo đúng cái team đó xong.

### 4.4 Màn tạo dự án, có nền

```
┌─ Dự án mới ────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │  ← nền đang chọn, cao 120dp
│ ▓   Phục chế tháng 10   ▓ │  ← tên hiện luôn TRÊN nền
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │
│                            │
│ Tên dự án                  │
│ [Phục chế tháng 10      ]  │
│                            │
│ Nền                        │
│ ●○○○○○○○                   │  ← 8 chấm màu, cuộn ngang
│                            │
│ Nhóm việc                  │
│ …                          │
│ [      Tạo dự án       ]   │
└────────────────────────────┘
```

Tên dự án hiện **ngay trên dải nền** trong lúc gõ — người tạo thấy kết quả
thật, không phải đoán. Đây cũng là lý do bộ nền phải đủ tương phản với chữ
trắng: nó được kiểm bằng mắt ngay tại chỗ chọn.

`lib/design/tokens/omni_covers.dart` *(mới)* — bảng `tên → List<Color>`. Một
nguồn sự thật; web đọc cùng danh sách tên nhưng dựng gradient riêng bằng CSS.

### 4.5 Nền hiện lại ở đâu

Trên **thẻ dự án** trong màn "Team & dự án" — một dải mỏng ở đầu thẻ. Không có
chỗ này thì chọn nền xong không thấy ở đâu cả, và cả tính năng là một ô cấu
hình không có hậu quả.

---

## 5. Web

`omni-flow` đọc `cover` và vẽ dải gradient tương ứng trên thẻ dự án ở
`_app.projects.index.tsx`. **Chỉ đọc, không cho chọn** ở vòng này — người tạo
dự án trên app là người chọn nền, và web chưa có yêu cầu nào về việc đó.

Tên nền không khớp bảng → rơi về nền mặc định, không vỡ.

---

## 6. Kiểm thử

| Mối nối | Cách kiểm |
|---|---|
| `member_ids` thật sự đến server | **Live test**: tạo team kèm 2 người → đọc lại `/teams/{id}` phải thấy đủ 2. Đây là kiểu lỗi "client không gửi thứ server chờ" đã xảy ra nhiều lần. |
| `cover` lưu và đọc lại được | **Live test**: tạo dự án `cover: 'teal-1'` → đọc lại phải còn nguyên. |
| Dự án cũ không có `cover` | Feature test API: `GET /projects` trên tài liệu không có khoá → không lỗi; app vẽ nền mặc định. |
| Bỏ qua thành viên vẫn tạo được | Widget test: không chọn ai → nút "Tạo team" vẫn bật. |
| Back không quay lại form cũ | Widget test điều hướng: sau khi tạo, ngăn xếp không còn `CreateTeamPage`. |
| Chọn nền đổi ngay phần xem trước | Widget test: chạm chấm thứ ba → dải nền đổi màu. |

**Bài kiểm chạy thật:** tạo một team kèm 2 thợ trên app → tạo dự án ngay sau đó
→ mở **web** kiểm tra team có đủ người và dự án nằm đúng team. Đây là chỗ hai
client từng nói hai chuyện khác nhau ("tạo dự án trên điện thoại lại là tạo
team trên web"), nên nó phải được kiểm bằng mắt trên cả hai.

---

## 7. Cố ý không làm

| Thứ | Vì sao |
|---|---|
| Màn riêng cho bước chọn thành viên | §2.1 — một ô trong form là đủ. |
| Ảnh nền tải lên | §2.2 — bộ có sẵn không có bài toán chữ đè lên ảnh. |
| Chọn nền trên web | Người tạo dự án là người chọn. Web chỉ hiện. |
| Đặt vai trò cho từng thành viên lúc tạo | `member_roles` đã có ở API cho dự án, nhưng thêm một bảng vai trò vào form tạo team là biến hai ô thành một màn quản trị. |
| Bắt buộc phải tạo dự án sau khi tạo team | Đi thẳng sang, nhưng thoát ra được. Team chưa có dự án vẫn là trạng thái hợp lệ. |

---

## 8. Rủi ro

| # | Rủi ro | Nếu sai |
|---|---|---|
| ~~R1~~ | ~~Vai tạo được team cũng đọc được danh bạ~~ | **Đã gỡ 2026-09-10.** `SystemRolePresets::manager()` có CẢ HAI: `organization.org_units.create` (tạo team) và `membership.members.read` (đọc danh bạ). Đã kiểm thêm bằng gọi thật: `/memberships` và `/identity/users` đều trả 200. Vẫn giữ ghi chú: vai do từng workspace tự cấu hình được, nên một workspace gỡ `members.read` khỏi `manager` sẽ thấy ô "Thành viên" rỗng — sheet phải chịu được danh sách rỗng mà không vỡ. |
| R2 | `POST /projects` nhận `team_id` của team vừa tạo | Đã có `TeamExists` rule, và live test hiện tại đã kiểm "team_id trỏ vào hư không bị TỪ CHỐI". Rủi ro thấp. |
| R3 | Tám nền đủ tương phản với chữ trắng | Kiểm bằng mắt lúc dựng bảng màu; phần xem trước ở §4.4 làm chính việc đó lộ ra ngay. |

**R1 là rủi ro chặn** — kiểm trước khi viết sheet chọn người.

---

## 9. Thứ tự thi công

1. **Kiểm R1** — đăng nhập vai `manager`, gọi `/memberships` và `/identity/users`.
2. **API §3.2** — thêm `cover` vào hai request, kèm feature test dự án cũ không có khoá.
3. **`omni_covers.dart` §4.4** — bảng tám nền.
4. **Sheet chọn người §4.2** + ô "Thành viên" §4.1, kèm live test `member_ids`.
5. **Điều hướng §4.3** — `pushReplacement`, `teamId` điền sẵn.
6. **Màn dự án có nền §4.4** + thẻ dự án hiện nền §4.5.
7. **Web §5** — đọc `cover`.
8. **Bài kiểm chạy thật §6** — app tạo, web kiểm.
