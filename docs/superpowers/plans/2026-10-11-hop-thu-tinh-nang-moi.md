# Hộp thư — tính năng mới trên API `feat/hop-thu-mobile` · Kế hoạch triển khai

> **Cho agent thực thi:** BẮT BUỘC dùng superpowers:subagent-driven-development (khuyến nghị) hoặc superpowers:executing-plans để làm từng task. Các bước dùng checkbox (`- [ ]`). TDD: test đỏ → làm → xanh → `dart format` + `flutter analyze` → commit.

**Mục tiêu:** Dựng trên app (`lib/modules/inbox`) các tính năng mà GĐ3 đã gác lại vì "chưa có API":
- đánh dấu chưa đọc, tắt/bật thông báo, ghim/bỏ ghim, chặn/bỏ chặn (trong menu bấm giữ và trang Thông tin), cùng mục "Đã ghim" ở đầu Hộp thư;
- cảm xúc nội bộ trên tin: thanh cảm xúc, bấm đúp thả tim, realtime;
- gửi tệp và ghi âm, mở theo khả năng gửi của từng kênh;
- tin gửi lỗi vì kênh không hỗ trợ gửi thì hiện đúng lý do.

**Kiến trúc:** Giữ nguyên tầng dữ liệu và realtime đang có (`InboxListController`, `ThreadController`, `ThreadRealtimeSignal`, poll dự phòng).
- **Dữ liệu.** Thêm trường vào `Conversation` (`isPinned`, `isMuted`, `blockedAt`, `outboundCapabilities`) và `Message` (`teamReactions`, `errorCode`), cùng các phương thức `InboxApi` tương ứng. Mọi khoá được khoá lại bằng test hợp đồng dựng từ JSON thật của API.
- **Mục "Đã ghim"** là một provider riêng (`pinnedConversationsProvider`, một trang `pinned=1&per_page=50`). Danh sách chính gửi `pinned=0`. Hai danh sách loại trừ nhau ở cả server lẫn khi vá tại chỗ.
- **Thao tác hội thoại** đều đi qua `ConversationActions`, dùng chung cho menu xem trước và trang Thông tin.
- **Cảm xúc nội bộ** sửa tại chỗ trong `ThreadController`. Hiện cập nhật lạc quan, lỗi thì trả lại như cũ và báo; sự kiện `message.team_reaction` vá tại chỗ, không tải lại luồng tin.
- **Composer** nhận `OutboundCapabilities` của hội thoại để quyết định hiện nút nào và cảnh báo gì.

**Công nghệ:**
- Đã có: Flutter (SDK ^3.11.5), flutter_riverpod ^2.5.1, dio, image_picker, url_launcher.
- **Gói mới:** `file_picker` (chọn tệp), `record` (ghi âm), `path_provider` (thư mục tạm cho bản ghi). `path_provider` hiện chỉ là phụ thuộc bắc cầu, nay khai trực tiếp.

**Spec:** `docs/superpowers/specs/giao-dien-moi/README.md` (mục **Hội thoại**, **Hộp thư**, **Thông tin hội thoại**) + `Thread.dc.html` (thanh cảm xúc, `@keyframes burst`/`pop`, bấm đúp), `ThreadInfo.dc.html` (Tắt TB, công tắc Ghim, "Chặn khách này"), `InboxPeek.dc.html` (menu). Quy tắc chung: `.superpowers/sdd/common-implementer-rules.md`. Kế hoạch trước đó: `2026-10-09-giao-dien-moi-gd3-hop-thu.md` (bảng "Phán quyết API" của plan đó nay **hết hiệu lực** cho các mục dưới đây).

**API:** `D:\_omnicrm\omni-flow-api`, nhánh `feat/hop-thu-mobile` (commit `7ebd739` lúc viết plan). Plan API: `omni-flow-api/docs/superpowers/plans/2026-10-10-hop-thu-mobile-api.md`. Không đổi nhánh API. Nếu cây làm việc khác nhánh, đọc bằng `git show feat/hop-thu-mobile:<đường dẫn>`. Phát hành: **API lên trước app** (runbook "Hộp thư mobile" trong `omni-flow-api/DEPLOY.md`).

## Global Constraints

- Repo `D:\_omnicrm\omni-flow-app`, nhánh đang mở `feat/giao-dien-moi-gd1`, commit trên nhánh này. Không đổi nhánh, không push, không worktree, không thư mục ngoài repo.
- Flutter: `D:\_tools\flutter\bin\flutter` (không có trên PATH). Đường dẫn Windows dùng PowerShell, vì Git Bash nuốt dấu `\`.
- **Phán quyết thiết kế (common-implementer-rules):**
  - Không có API thì không dựng; không nút chết, không báo thành công giả.
  - Chữ ≥12px, độ đậm ≤600, không `fontSize` thô ngoài `lib/design` (cỡ mới thì thêm token vào `lib/design/tokens/omni_typography.dart`).
  - Vùng chạm tối thiểu 44×44.
  - Màu lấy qua token, `OmniColors.byBrightness`, `colorScheme`; giao diện tối phải đúng.
  - `lib/design` không import `modules/` hay `security/`.
  - Mọi hiệu ứng tắt khi `OmniMotion.enabled(context) == false` (`Duration.zero`, không chạy hoạt ảnh lặp).
  - Sau `await` không dùng `ref`/`context` có thể đã huỷ: lấy `ProviderScope.containerOf` + `ScaffoldMessenger` trước khi chờ, rồi kiểm `mounted`.
  - Nút điều hướng ẩn khi thiếu quyền vào route đích. Giữ mọi năng lực đang có.
- **Quyền** (đối chiếu `routes.php` và `RequirePermission`; danh sách quyền sau dấu `:` nghĩa là **có một trong số đó** là đủ):

  | Thao tác | Middleware API | Điều kiện trên app |
  |---|---|---|
  | Chưa đọc | `inbox.write` | `access.canUpdate` |
  | Ghim / tắt TB | `inbox.read` hoặc `inbox.read.own` | mọi người vào được Hộp thư (không cần `inbox.write`) |
  | Chặn / bỏ chặn | `inbox.write` **và** (`inbox.read` hoặc `inbox.read.all`) | `access.canBlock` = ghi được **và** `readScope == AccessScope.all`. Sale `.own` bị 403, nên phải **ẩn** mục này. |
  | Cảm xúc nội bộ | `inbox.write` | `access.canReact` |

- **Lỗi client↔server im lặng** (memory `viomni-silent-client-server-bugs`): mỗi khoá đọc hay gửi đều có test hợp đồng khẳng định **đúng tên khoá**, **đúng method + path** và **đúng kiểu giá trị**. Thêm trường vào `Conversation`/`Message` thì phải sửa đủ các chỗ sau, sót chỗ nào là mất dữ liệu lặng:
  - constructor;
  - `fromJson`;
  - `copyWith`;
  - `Conversation.unassigned()`;
  - `Message.requeued()`/`optimistic` (chỉ khi trường có nghĩa với tin nháp).

  `test/modules/inbox/conversation_test.dart` giữ quy tắc copyWith.
- **Trước khi commit:** `D:\_tools\flutter\bin\dart format lib test` và `D:\_tools\flutter\bin\flutter analyze` phải sạch (CI chặn, xem memory `viomni-ci-formatters-before-push`). Lúc làm chạy test tập trung; trước mỗi commit chạy cả bộ một lần (chạy nền trước, timeout rộng).
- **Bẫy khi viết test** (memory `viomni-test-harness-gotchas`):
  - màn bọc `SurfaceBackdrop` phải override `backgroundProvider.overrideWith(FixedBackground.new)`;
  - cửa sổ test 800×600;
  - đổi theme cần `pumpAndSettle`;
  - trang có poll phải gỡ (`pumpWidget(SizedBox())`) trước khi bài test kết thúc;
  - `Dismissible` cần hai lần `moveBy`.
- Plugin gốc (`file_picker`, `record`, `image_picker`) **không gọi trực tiếp trong widget**. Chúng đi qua callback hoặc provider tiêm được, để test widget không chạm kênh nền tảng.
- Commit tiếng Việt, mỗi task một commit, kết thúc bằng dòng trống + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Chỉ stage tệp của task.

## Hợp đồng API (đã đọc routes, controller, DTO, test trên `feat/hop-thu-mobile`)

| Việc | Method + path (`/api/v1` + …) | Body / query | `data` trả về, lỗi |
|---|---|---|---|
| Chưa đọc | `POST /inbox/conversations/{id}/unread` | — | `{unread_count: int}` (≥1, giữ số cũ nếu đã >0); 404 `Not found.` ngoài phạm vi |
| Ghim | `POST /inbox/conversations/{id}/pin` | — | `{conversation_id, is_pinned}`; **422** `{success:false, code:"pin_limit_reached", message, errors:{conversation_id:[…]}, data:{conversation_id, is_pinned:false}}` khi vượt 50 |
| Bỏ ghim | `DELETE /inbox/conversations/{id}/pin` | — | `{conversation_id, is_pinned:false}`; luôn 200, kể cả hội thoại đã ra khỏi phạm vi |
| Tắt / bật TB | `POST` / `DELETE /inbox/conversations/{id}/mute` | — | `{conversation_id, is_muted}`; DELETE luôn 200 |
| Chặn / bỏ chặn | `POST` / `DELETE /inbox/conversations/{id}/block` | — | **hội thoại đầy đủ** (như `GET {id}`), có `blocked_at` (ISO hoặc null) và `blocked_by`; 403 cho sale `.own` |
| Mục ghim | `GET /inbox/conversations?pinned=1` | `pinned` ∈ `0,1,true,false`; giá trị khác → **422** | như list; `pinned=0` loại hội thoại TÔI ghim |
| Đã chặn | `GET /inbox/conversations?blocked=1` | như trên | mặc định list/facet **ẩn** hội thoại đã chặn |
| Cảm xúc nội bộ | `POST /inbox/conversations/{id}/messages/{messageId}/team-reactions` | `{emoji}`: bắt buộc, ≤16 ký tự, **chỉ ký tự ngoài ASCII** | `{message_id, team_reactions:[{user_id, user_name, emoji, at}]}`. Cùng emoji = bỏ, khác = thay (mỗi người 1). Lỗi: 404 `Message not found.`, 422 emoji sai. |
| Gửi tin | `POST /inbox/conversations/{id}/messages` | `attachments` **≤10**, `attachments.*.type` ∈ `image,video,audio,file` | như cũ |
| Tải tệp | `POST /inbox/media` (multipart `file`) | ≤25MB, MIME theo `config/media.php` | `{url, type: image\|video\|audio\|file, name}` |

**Khoá mới trên mọi hội thoại** (`present()`):
- `is_pinned` (bool), `is_muted` (bool): theo **người xem**. Mảng thô `pinned_by`/`muted_by` không bao giờ ra ngoài.
- `blocked_at`: có thể vắng hoặc null.
- `outbound_capabilities` = `{can_send: bool, text, image, file, audio, video}`, mỗi giá trị ∈ `native | docs_only | link | none`:
  - `facebook`, `zalo_personal`, `facebook_personal`: tất cả `native`;
  - `zalo` (OA): `file: docs_only`, `audio: link`, `video: link`, còn lại `native`;
  - kênh khác: `can_send:false`, tất cả `none`.

**Khoá mới trên mọi tin:**
- `team_reactions`: **luôn có**, mặc định `[]`.
- `error_code`: tin `failed` của kênh không có đường gửi có `error_code: "channel_send_unsupported"`, kèm `error` là câu tiếng Việt do server dịch. Lượt gửi lại thành công thì `error_code` về null.

**Realtime:**
- `conversation.{id}`:
  - `message.team_reaction` `{conversation_id, message_id, team_reactions}`, **tách** khỏi `message.reaction` (cảm xúc của KHÁCH);
  - `message.sent` lúc lỗi `{conversation_id, message_id, status:"failed", error, error_code}`.
- `tenant.{t}.inbox` `conversation.updated`: thêm lý do `unread`, `blocked`, `unblocked`.
- Ghim và tắt TB **không** phát sự kiện, **không** đổi `updated_at`.

**Thông báo:** tắt TB thì server bỏ push OS và bỏ `inbox.unassigned`; dòng chuông vẫn ghi, kèm `muted:true`. App hiện không bật toast hay âm thanh cho `notification.created` (`notifications_providers.dart` chỉ tăng tín hiệu), nên **app không phải làm thêm gì** cho tắt TB ngoài hiển thị trạng thái.

## Phán quyết thiết kế cho đợt này

| Câu hỏi | Phán quyết |
|---|---|
| "Đã ghim" có theo bộ lọc không? | **Có.** `pinned=1` cộng cùng query của bộ lọc, còn danh sách chính dùng `pinned=0` cộng cùng query. Hai mục gộp lại đúng bằng kết quả của bộ lọc, không trùng, không sót. Riêng tab "Đã chặn" thì ẩn mục ghim. |
| Mục ghim dài | Hiện tối đa 5 dòng, sau đó dòng "Xem thêm N" để bung hoặc thu (giữ trạng thái trong `State`). |
| Mở lại hội thoại đã chặn để bỏ chặn | Thêm chip lọc **"Đã chặn"** (`InboxQuickFilter.blocked` → `blocked=1`, không kèm `status`), chỉ hiện khi `canBlock` và không hiện số vì facet không có. Thiếu chip này thì không đường nào tới được "Bỏ chặn". |
| Chặn | Luôn hỏi lại (`showOmniConfirm(destructive: true)`): "Chặn khách này?" / "Hội thoại sẽ ẩn khỏi Hộp thư của cả đội. Tin mới vẫn được lưu nhưng không báo, không tính chưa đọc." Bỏ chặn không hỏi. |
| Chưa đọc ở trang Thông tin | Xong thì về thẳng Hộp thư (`context.goNamed(InboxRoutes.list)`). Ở lại hội thoại là đang đọc, nên dấu "chưa đọc" mất nghĩa (Messenger cũng làm vậy). |
| Hiển thị tắt TB | Trên dòng hội thoại: biểu tượng chuông gạch (`Icons.notifications_off_outlined`, 14, màu phụ) cạnh giờ. Trang Thông tin: nút tròn "Tắt TB" ↔ "Đã tắt" (`ThreadInfo.dc.html` `muteL`). |
| Cảm xúc của khách và của đội | Cảm xúc **khách** (`reaction`) giữ nguyên: vòng tròn ở góc bong bóng. Cảm xúc **nội bộ** (`team_reactions`) là viên thuốc **dưới** bong bóng, theo bản mẫu: `margin-top:-6`, bo 9, nền `surface`, viền `outlineVariant`, chữ 12. Gom theo emoji, ví dụ "❤️ 2"; viên có cảm xúc của tôi thì viền màu chính. Semantics: "Cảm xúc nội bộ: ❤️ Lan, Minh". Chạm viên mở sheet chỉ đọc liệt kê tên người thả. |
| Thanh cảm xúc | 6 emoji theo bản mẫu: `👍 ❤️ 😂 😮 🙏 ✅` (đều ngoài ASCII, hợp luật server). Mỗi nút **44×44** (không phải 36 như bản mẫu vì guard thắng). Khung bo 24, `pop .35s` lệch nhau 30ms. Emoji của tôi có nền `accent`. Chỉ hiện khi `canReact` và tin đã có id server (không phải nháp, không phải ghi chú). |
| Bấm đúp | Thả hoặc bỏ ❤️ của tôi (gửi `❤️`, server tự đảo). Tim 44px `#E5484D` bay lên theo `burst .8s` (0% mờ, co .3 → 25% hiện, phóng 1.25 → 45% .95 → 70% 1 → 100% mờ, co .9, lên 28px), ở mép trong 24px. Chỉ bay khi **thả**, không bay khi bỏ. Rung nhẹ (`HapticFeedback.lightImpact`). Tắt hiệu ứng thì không có tim bay. |
| Cập nhật lạc quan | Có, kèm hoàn tác: lỗi thì trả danh sách cũ + snackbar "Không thả được cảm xúc. Vui lòng thử lại." Phản hồi server **thay** danh sách lạc quan. |
| Tệp | Mục **"Tệp"** trong khay `+`, chỉ hiện khi `file != none`. Đuôi cho phép khớp `config/media.php` kind `file`: `pdf, doc, docx, xls, xlsx, ppt, pptx, txt, csv`. Ảnh vẫn đi nút ảnh. |
| Ghi âm | Nút mic trong cụm công cụ (+ · máy ảnh · ảnh · mic, thu thành › khi gõ), tooltip "Ghi âm". Chỉ hiện khi `audio != none`. Chạm để bắt đầu; thanh ghi thay ô nhập (chấm đỏ + mm:ss + Huỷ + Gửi). Tối đa **5 phút** thì tự dừng; dưới 1 giây thì bỏ và báo "Ghi âm quá ngắn." Gửi ngay thành một tin chỉ có tệp `audio`. |
| Định dạng ghi âm | **WAV PCM 16-bit, 16 kHz, mono** (≈1,9MB/phút; 5 phút ≈ 9,6MB < 25MB). Lý do: `/inbox/media` kiểm MIME **dò từ nội dung**, mà `.m4a` (AAC) thường bị libmagic dò ra `audio/x-m4a`, không có trong danh sách cho phép, nên sẽ bị 422 lặng ở máy thật. `audio/wav` và `audio/x-wav` đều được phép. Báo cáo kiến nghị server thêm `audio/x-m4a` để sau này đổi sang AAC cho nhẹ. |
| Kênh không gửi được (`can_send:false` hoặc `text: none`) | Không hiện composer. Thay bằng dòng "Kênh này chưa gửi tin được từ Hộp thư — hãy trả lời trên ứng dụng của kênh." (cùng chỗ `_ReadOnlyBar`). |
| Thiếu khoá `outbound_capabilities` (API cũ) | `null` = chưa biết: giữ hành vi cũ (chữ + ảnh), **ẩn** Tệp và Ghi âm. |
| Cảnh báo Zalo OA | **Ghi âm** (`audio: link`): trước lượt ghi đầu tiên mỗi lần mở hội thoại, hỏi "Zalo OA không nhận tin thoại — bản ghi sẽ gửi dưới dạng đường link, khách bấm để nghe." [Huỷ] [Vẫn ghi âm]. **Tệp** (`file: docs_only`): tệp ngoài `pdf/doc/docx/csv` hoặc lớn hơn 5MB thì hỏi "Zalo OA chỉ gửi PDF, DOC, DOCX, CSV dưới 5MB thành tệp — tệp này sẽ gửi dưới dạng đường link." [Huỷ] [Vẫn gửi]. Với `file: link` thì hỏi như vậy cho mọi tệp. |
| Trần số tệp | Mỗi tin ≤ **10** tệp (ảnh + tệp đang chờ). Chọn ảnh dùng `pickMultiImage(limit: còn lại)` **và** luôn cắt bớt phía app (vì một số trình chọn bỏ qua `limit`), rồi báo "Mỗi tin tối đa 10 tệp — đã bỏ N tệp." Đầy 10 thì nút ảnh, máy ảnh và Tệp bị vô hiệu. Tệp lớn hơn 25MB thì từ chối trước khi tải: "Tệp vượt 25MB, không gửi được." |
| Tin lỗi `channel_send_unsupported` | Bong bóng lỗi hiện `error` của server, hoặc câu dự phòng "Kênh này chưa hỗ trợ gửi tin đi từ Hộp thư — tin chưa đến khách." **Không có nút "Gửi lại"** vì gửi lại không bao giờ thành công; vẫn có "Xoá" nếu đang có. |
| "Báo giá" trong khay | Vẫn **không hiện** (app không có module báo giá). |
| Phát lại ghi âm trong bong bóng | Ngoài phạm vi. Tệp `audio` hiện như dòng tệp đính kèm như hiện nay, chạm thì mở link. Ghi vào báo cáo. |

## Review Focus

1. **Không trùng, không sót giữa hai danh sách.** Ghim một dòng thì nó rời danh sách chính và vào "Đã ghim" ngay. Bỏ ghim thì nó về đúng chỗ theo `last_message_at` (hoặc không chèn, nếu cũ hơn trang đã tải mà server còn trang). Tin mới đến hội thoại đã ghim **không** chèn nó vào danh sách chính. Test ở Task 2.
2. **Người chỉ có `inbox.read`:** menu có Ghim và Tắt TB (cả hai là `$read`) nhưng không có Chưa đọc, Chặn hay thanh cảm xúc. **Sale `.own` có `inbox.write`:** có Chưa đọc, cảm xúc, Ghim, Tắt TB, **không** có Chặn và không có chip "Đã chặn". Test ở Task 3 và Task 4.
3. **Cảm xúc nội bộ không đè cảm xúc của khách.** Tin có `reaction:"😮"` (khách) và `team_reactions:[❤️]` hiện **cả hai**. Sự kiện `message.reaction` vẫn tải lại như cũ, còn `message.team_reaction` vá tại chỗ và **không** tải lại. Test ở Task 4.
4. **Bấm đúp không phá chạm khác:** chạm ảnh vẫn mở trình xem (trễ ≤300ms do nhận dạng bấm đúp), chạm link vẫn mở, vuốt trả lời và bấm giữ vẫn chạy. Test ở Task 4.
5. **Zalo OA:** nút Ghi âm có, nhưng phải qua cảnh báo; tệp `.xlsx` phải qua cảnh báo. **TikTok:** không có composer. **API cũ thiếu khoá:** không có Tệp và Ghi âm. Test ở Task 5 và Task 6.
6. **Gửi 11 ảnh** không bao giờ tới server (cắt còn 10 + báo). Test ở Task 5.

---

## Cấu trúc tệp

| Tệp | Trách nhiệm |
|---|---|
| `lib/modules/inbox/domain/outbound_capabilities.dart` (mới) | `OutboundMode`, `OutboundCapabilities` (parse, các câu hỏi `canSendFiles`…) |
| `lib/modules/inbox/domain/conversation.dart` | `isPinned`, `isMuted`, `blockedAt`, `isBlocked`, `outboundCapabilities` |
| `lib/modules/inbox/domain/message.dart` | `TeamReaction`, `Message.teamReactions`, `Message.errorCode`, `isChannelUnsupported` |
| `lib/modules/inbox/domain/inbox_permissions.dart` | `InboxAccess.canReact`, `canBlock` |
| `lib/modules/inbox/domain/inbox_filter.dart` | `InboxQuickFilter.blocked`; `matches` loại hội thoại đã chặn |
| `lib/modules/inbox/data/inbox_api.dart` | `markUnread`, `setPinned`, `setMuted`, `setBlocked`, `toggleTeamReaction`; `list(pinned:)` |
| `lib/modules/inbox/application/inbox_providers.dart` | `pinned=0` cho danh sách chính, `PinnedConversationsController`, `reconcile` chèn được |
| `lib/modules/inbox/application/thread_controller.dart` | `toggleTeamReaction`, `applyTeamReactions` |
| `lib/modules/inbox/application/inbox_realtime.dart` | `message.team_reaction` → vá tại chỗ |
| `lib/modules/inbox/application/voice_recorder.dart` (mới) | Giao diện `VoiceRecorder` + bản `record`, `voiceRecorderProvider` |
| `lib/modules/inbox/presentation/inbox_page.dart` | Mục "Đã ghim", rỗng = cả hai rỗng, chọn nhiều gồm cả mục ghim |
| `lib/modules/inbox/presentation/widgets/inbox_pinned_section.dart` (mới) | Tiêu đề "Đã ghim", ≤5 dòng + "Xem thêm N" |
| `lib/modules/inbox/presentation/widgets/conversation_row.dart` | Chuông gạch khi `isMuted` |
| `lib/modules/inbox/presentation/widgets/inbox_filter_bar.dart` | Chip "Đã chặn" (khi `canBlock`) |
| `lib/modules/inbox/presentation/widgets/conversation_actions.dart` | Thao tác mới + `peekMenuFor` mới; bỏ chú thích "chưa có API" |
| `lib/modules/inbox/presentation/thread_info_page.dart` | Tắt TB, công tắc Ghim, Chưa đọc, Chặn/Bỏ chặn |
| `lib/modules/inbox/presentation/widgets/message_actions_overlay.dart` | Thanh cảm xúc; bỏ chú thích "API cảm xúc chưa có" |
| `lib/modules/inbox/presentation/widgets/team_reactions.dart` (mới) | Viên cảm xúc nội bộ + sheet người thả |
| `lib/modules/inbox/presentation/widgets/heart_burst.dart` (mới) | Tim bay khi bấm đúp |
| `lib/modules/inbox/presentation/widgets/message_bubble.dart` | Bấm đúp, viên cảm xúc nội bộ, ẩn "Gửi lại" cho `channel_send_unsupported` |
| `lib/modules/inbox/presentation/widgets/message_composer.dart` | Tệp, Ghi âm, trần 10, cảnh báo theo khả năng kênh |
| `lib/modules/inbox/presentation/widgets/voice_record_bar.dart` (mới) | Thanh đang ghi |
| `lib/modules/inbox/presentation/thread_page.dart` | Truyền khả năng kênh, nối cảm xúc, chọn tệp, ghi âm; ẩn composer khi kênh không gửi được |
| `lib/design/tokens/omni_typography.dart` | `OmniChatType.reaction` (emoji thanh cảm xúc), `OmniChatType.reactionChip` |
| `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`, `ios/Runner/Info.plist` | `file_picker`, `record`, `path_provider`; `RECORD_AUDIO`; `NSMicrophoneUsageDescription` |

---

### Task 1: Nền dữ liệu và hợp đồng: trường mới, `InboxApi`, quyền, test hợp đồng cho mọi khoá

**Files:**
- Create:
  - `lib/modules/inbox/domain/outbound_capabilities.dart`
  - `test/inbox/inbox_api_hop_thu_contract_test.dart`
- Modify:
  - `lib/modules/inbox/domain/conversation.dart`
  - `lib/modules/inbox/domain/message.dart`
  - `lib/modules/inbox/domain/inbox_permissions.dart`
  - `lib/modules/inbox/domain/inbox_filter.dart`
  - `lib/modules/inbox/data/inbox_api.dart`
- Test:
  - `test/inbox/inbox_api_hop_thu_contract_test.dart`
  - `test/modules/inbox/conversation_test.dart` (copyWith/unassigned giữ trường mới)
  - `test/inbox/inbox_filter_test.dart`
  - `test/inbox/conversation_parsing_test.dart`

**Interfaces:**
- Produces:
  - `enum OutboundMode { native, docsOnly, link, none; static OutboundMode parse(Object?) }`. Ánh xạ `'native'`, `'docs_only'`, `'link'`; giá trị lạ hoặc thiếu → `none`.
  - `class OutboundCapabilities { final bool canSend; final OutboundMode text, image, file, audio, video; static OutboundCapabilities? fromJson(Object? raw) /* không phải Map → null */; bool get canSendText; bool get canSendImages; bool get canSendFiles; bool get canSendVoice; }`
    - `canSendText` = `canSend && text != none`;
    - `canSendImages` = `canSendText && image != none`;
    - `canSendFiles` và `canSendVoice` cũng phải qua `canSendText`.
  - `Conversation`:
    - `final bool isPinned` (`json.flag('is_pinned')`);
    - `final bool isMuted` (`json.flag('is_muted')`);
    - `final DateTime? blockedAt` (`DateUtilsX.parse(json['blocked_at'])`), `bool get isBlocked => blockedAt != null`;
    - `final OutboundCapabilities? outboundCapabilities` (`OutboundCapabilities.fromJson(json['outbound_capabilities'])`).

    Cả bốn trường phải có trong constructor, `copyWith`, `unassigned()`.
  - `class TeamReaction { userId, userName?, emoji, at? ; fromJson ; toJson? (không cần) }`.
  - `Message`:
    - `final List<TeamReaction> teamReactions` (mặc định `const []`, đọc `json.mapList('team_reactions')`);
    - `final String? errorCode` (`json.str('error_code')`), `bool get isChannelUnsupported => errorCode == 'channel_send_unsupported'`;
    - `copyWith({List<TeamReaction>? teamReactions, String? errorCode, …})`.

    `requeued()` **bỏ** `errorCode` (lượt mới), giữ `teamReactions` rỗng.
  - `InboxAccess`:
    - `bool get canReact` (capability `'react'` khi ghi được);
    - `bool get canBlock` (ghi được **và** `readScope == AccessScope.all`; truyền cờ qua constructor `_`).
  - `InboxQuickFilter.blocked` (label "Đã chặn"):
    - `toQuery` → `{'blocked': '1'}`, không kèm `status`;
    - `matches` → `c.isBlocked`;
    - mọi nhánh khác của `matches` trả `false` khi `c.isBlocked`;
    - `InboxFacets.countFor(blocked)` → `0` và **không** dùng để hiện số (Task 2 ẩn số).
  - `InboxApi`:
    - `Future<int> markUnread(String id)` → `POST $_base/$id/unread`, đọc `data.unread_count`;
    - `Future<bool> setPinned(String id, bool on)` → `POST|DELETE $_base/$id/pin`, đọc `data.is_pinned`;
    - `Future<bool> setMuted(String id, bool on)` → `POST|DELETE $_base/$id/mute`, đọc `data.is_muted`;
    - `Future<Conversation> setBlocked(String id, bool on)` → `POST|DELETE $_base/$id/block`, `Conversation.fromJson(response.object)`;
    - `Future<List<TeamReaction>> toggleTeamReaction(String conversationId, String messageId, String emoji)` → `POST $_base/$cid/messages/$mid/team-reactions` body `{'emoji': emoji}`, đọc `data.team_reactions`;
    - `list(...)` thêm tham số `bool? pinned`: `true` → `'pinned': '1'`, `false` → `'pinned': '0'`, null → không gửi.
  - `static const maxAttachmentsPerMessage = 10;` và `static const maxUploadBytes = 25 * 1024 * 1024;` đặt trong `InboxApi`. Ghi chú nguồn: `SendMessageRequest` `max:10`, `uploadMedia` `max:25600`.

- [ ] **Step 1: Viết test hợp đồng hỏng.** Dùng `FakeAdapter` (`test/support/fake_http_adapter.dart`) để ghi lại request. JSON lấy **nguyên hình dạng** từ các test API: `ConversationViewerStateContractTest`, `PinConversationTest`, `TeamReactionTest`, `BlockConversationTest`, `OutboundCapabilitiesTest`.

```dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/domain/outbound_capabilities.dart';

import '../support/fake_http_adapter.dart';

/// Hợp đồng Hộp thư mobile — đối chiếu `omni-flow-api` nhánh
/// `feat/hop-thu-mobile` (routes.php, InboxController, InboxDTO::forViewer,
/// MessageDTO, OutboundCapabilities). Mỗi khoá một khẳng định: đây là kiểu
/// lỗi client↔server im lặng của dự án.
void main() {
  (InboxApi, FakeAdapter) api(Object data, {int status = 200, String? raw}) {
    final adapter = FakeAdapter(status, raw ?? envelope(data));
    return (InboxApi(ApiClient(Dio()..httpClientAdapter = adapter)), adapter);
  }

  group('hội thoại: khoá theo người xem + khả năng gửi', () {
    final json = {
      'id': 'c1', 'channel': 'zalo', 'status': 'open',
      'is_pinned': true, 'is_muted': true,
      'blocked_at': '2026-10-10T03:00:00.000Z', 'blocked_by': 'u9',
      'outbound_capabilities': {
        'can_send': true, 'text': 'native', 'image': 'native',
        'file': 'docs_only', 'audio': 'link', 'video': 'link',
      },
    };

    test('đọc is_pinned / is_muted / blocked_at / outbound_capabilities', () {
      final c = Conversation.fromJson(json);
      expect(c.isPinned, isTrue);
      expect(c.isMuted, isTrue);
      expect(c.isBlocked, isTrue);
      final cap = c.outboundCapabilities!;
      expect(cap.canSend, isTrue);
      expect(cap.file, OutboundMode.docsOnly);
      expect(cap.audio, OutboundMode.link);
      expect(cap.canSendVoice, isTrue);
    });

    test('kênh không gửi được (can_send:false, mọi loại none)', () {
      final cap = OutboundCapabilities.fromJson({
        'can_send': false, 'text': 'none', 'image': 'none',
        'file': 'none', 'audio': 'none', 'video': 'none',
      })!;
      expect(cap.canSendText, isFalse);
      expect(cap.canSendFiles, isFalse);
      expect(cap.canSendVoice, isFalse);
    });

    test('API cũ thiếu khoá → null (không đoán), cờ mặc định false', () {
      final c = Conversation.fromJson({'id': 'c', 'channel': 'facebook'});
      expect(c.outboundCapabilities, isNull);
      expect(c.isPinned, isFalse);
      expect(c.isMuted, isFalse);
      expect(c.isBlocked, isFalse);
    });

    test('mảng thô pinned_by/muted_by KHÔNG được dùng thay cờ', () {
      final c = Conversation.fromJson({
        'id': 'c', 'channel': 'zalo', 'pinned_by': ['me'], 'muted_by': ['me'],
      });
      expect(c.isPinned, isFalse);
      expect(c.isMuted, isFalse);
    });
  });

  group('tin: team_reactions + error_code', () {
    test('team_reactions tách khỏi reaction của khách', () {
      final m = Message.fromJson({
        'id': 'm1', 'direction': 'in', 'text': 'hi', 'reaction': '😮',
        'team_reactions': [
          {'user_id': 'u1', 'user_name': 'Lan', 'emoji': '❤️',
           'at': '2026-10-10T03:00:00.000Z'},
        ],
      });
      expect(m.reaction, '😮');
      expect(m.teamReactions.single.userId, 'u1');
      expect(m.teamReactions.single.userName, 'Lan');
      expect(m.teamReactions.single.emoji, '❤️');
      expect(m.teamReactions.single.at, isNotNull);
    });

    test('failed + error_code channel_send_unsupported', () {
      final m = Message.fromJson({
        'id': 'm2', 'direction': 'out', 'status': 'failed',
        'error': 'Kênh này chưa hỗ trợ gửi tin đi từ Hộp thư — …',
        'error_code': 'channel_send_unsupported',
      });
      expect(m.isChannelUnsupported, isTrue);
      expect(m.requeued().errorCode, isNull);
    });
  });

  test('POST …/unread → data.unread_count', () async {
    final (a, http) = api({'unread_count': 1});
    expect(await a.markUnread('c1'), 1);
    final r = http.requests.single;
    expect(r.method, 'POST');
    expect(r.uri.path, '/api/v1/inbox/conversations/c1/unread');
  });

  test('ghim/bỏ ghim: POST|DELETE …/pin → data.is_pinned', () async {
    final (on, h1) = api({'conversation_id': 'c1', 'is_pinned': true});
    expect(await on.setPinned('c1', true), isTrue);
    expect(h1.requests.single.method, 'POST');
    expect(h1.requests.single.uri.path, '/api/v1/inbox/conversations/c1/pin');
    final (off, h2) = api({'conversation_id': 'c1', 'is_pinned': false});
    expect(await off.setPinned('c1', false), isFalse);
    expect(h2.requests.single.method, 'DELETE');
  });

  test('422 pin_limit_reached → ValidationException.reason', () async {
    final (a, _) = api(const {}, status: 422, raw: jsonEncode({
      'success': false, 'code': 'pin_limit_reached',
      'message': 'Bạn đã ghim tối đa 50 hội thoại — bỏ ghim bớt rồi ghim lại.',
      'errors': {'conversation_id': ['…']},
      'data': {'conversation_id': 'c1', 'is_pinned': false},
    }));
    await expectLater(
      a.setPinned('c1', true),
      throwsA(isA<ValidationException>()
          .having((e) => e.reason, 'reason', 'pin_limit_reached')
          .having((e) => e.message, 'message', contains('tối đa 50'))),
    );
  });

  test('tắt/bật TB: POST|DELETE …/mute → data.is_muted', () async { /* như pin */ });

  test('chặn: POST|DELETE …/block → hội thoại đầy đủ', () async {
    final (a, h) = api({'id': 'c1', 'channel': 'zalo',
        'blocked_at': '2026-10-10T03:00:00.000Z', 'is_pinned': false});
    final c = await a.setBlocked('c1', true);
    expect(c.isBlocked, isTrue);
    expect(h.requests.single.uri.path, '/api/v1/inbox/conversations/c1/block');
    // DELETE trả blocked_at null → isBlocked false.
  });

  test('cảm xúc nội bộ: POST …/team-reactions {emoji}', () async {
    final (a, h) = api({'message_id': 'm1', 'team_reactions': [
      {'user_id': 'u1', 'user_name': 'Lan', 'emoji': '❤️', 'at': '…'},
    ]});
    final list = await a.toggleTeamReaction('c1', 'm1', '❤️');
    expect(list.single.emoji, '❤️');
    final r = h.requests.single;
    expect(r.uri.path, '/api/v1/inbox/conversations/c1/messages/m1/team-reactions');
    expect(r.data, {'emoji': '❤️'});
  });

  test('list pinned → query pinned=1 / pinned=0, null → không gửi', () async {
    // 3 lượt: pinned:true, false, null; khẳng định queryParameters['pinned'].
  });

  test('gửi tin: attachments.type chỉ image|video|audio|file', () async {
    // send(... attachments: [MessageAttachment(url:'u', type:'audio', name:'a.wav')])
    // → body.attachments[0] == {'url':'u','type':'audio','name':'a.wav'}
  });
}
```

  Thêm vào `test/inbox/inbox_filter_test.dart`:
  - `InboxQuickFilter.blocked.toQuery` là đúng `{'blocked': '1'}` (không `status`);
  - `matches` trả `false` cho hội thoại đã chặn ở mọi tab trừ "Đã chặn";
  - tab "Đã chặn" trả `false` cho hội thoại chưa chặn.

  Thêm vào `conversation_test.dart`: `copyWith()` không đối số và `unassigned()` giữ `isPinned`, `isMuted`, `blockedAt`, `outboundCapabilities`.

- [ ] **Step 2: Chạy, thấy đỏ.** `D:\_tools\flutter\bin\flutter test test/inbox/inbox_api_hop_thu_contract_test.dart test/inbox/inbox_filter_test.dart test/modules/inbox/conversation_test.dart`. Kỳ vọng: lỗi biên dịch (chưa có `OutboundCapabilities`, `markUnread`…).
- [ ] **Step 3: Làm.**
  - Ghi chú nguồn đầu `outbound_capabilities.dart`: `omni-flow-api/modules/Channels/Domain/Support/OutboundCapabilities.php`.
  - Kiểm `ApiClient.delete` trả envelope (`api_client.dart:52`) và `ValidationException.reason` lấy từ `code` (`api_exception_mapper.dart:135`).
  - `markUnread` đọc `response.object.intOr('unread_count', 1)`.
- [ ] **Step 4: Chạy lại cho xanh; chạy `test/inbox` + `test/modules/inbox` để chắc không vỡ chỗ dùng `InboxQuickFilter.values`.** Bộ lọc có thể đang lặp `values`; nếu vậy thì loại `blocked` khỏi các chỗ đó, vì Task 2 mới thêm chip.
- [ ] **Step 5: Format, analyze, cả bộ test, rồi commit.** Message: `feat(hop-thu): trường và API mới — ghim, tắt TB, chặn, chưa đọc, cảm xúc nội bộ, khả năng gửi theo kênh`.

---

### Task 2: Mục "Đã ghim" ở đầu Hộp thư, danh sách chính `pinned=0`, chip "Đã chặn", chuông gạch

**Files:**
- Create:
  - `lib/modules/inbox/presentation/widgets/inbox_pinned_section.dart`
  - `test/modules/inbox/inbox_pinned_section_test.dart`
- Modify:
  - `lib/modules/inbox/application/inbox_providers.dart`
  - `lib/modules/inbox/presentation/inbox_page.dart`
  - `lib/modules/inbox/presentation/widgets/conversation_row.dart`
  - `lib/modules/inbox/presentation/widgets/inbox_filter_bar.dart`
- Test:
  - `test/modules/inbox/inbox_list_controller_test.dart` (query `pinned=0`; vá loại dòng đã ghim)
  - `test/modules/inbox/inbox_filter_panel_test.dart` (chip "Đã chặn" theo quyền)
  - `test/modules/inbox/conversation_row_test.dart` (chuông gạch)

**Interfaces:**
- Consumes (Task 1): `InboxApi.list(pinned:)`, `Conversation.isPinned/isMuted/isBlocked`, `InboxQuickFilter.blocked`, `InboxAccess.canBlock`.
- Produces:
  - Danh sách chính: `InboxListController` gọi `list(query:…, pinned: false)` ở **mọi** chỗ:
    - `build`;
    - `refresh`;
    - `loadMore`;
    - `_mergeFirstPage` (cả vòng tải tiếp).

    Quên một chỗ là dòng ghim hiện hai lần sau lượt gộp. Facet **không** gửi `pinned`.
  - Hàm vị từ riêng `bool? _belongs(Conversation c)` = `c.isPinned ? false : filter.matches(c, …)`. Dùng ở `_applyUpdates` **và** `reconcile`.
  - `reconcile` chèn được: khớp mà chưa có trên màn thì gọi `_insert(c)` (vốn đã tự bỏ qua khi cũ hơn phần đã tải mà còn trang). Trước đây nó chỉ `patch`, nên dòng vừa bỏ ghim biến mất khỏi cả hai mục.
  - Mục ghim:
    ```dart
    final pinnedConversationsProvider = AutoDisposeAsyncNotifierProvider<
        PinnedConversationsController, List<Conversation>>(…);
    class PinnedConversationsController extends AutoDisposeAsyncNotifier<List<Conversation>> {
      static const pageSize = 50; // = trần ghim của server (PIN_LIMIT)
      Future<List<Conversation>> build(); // tab "Đã chặn" → [] không gọi API
      Future<void> refresh();             // giữ dữ liệu cũ khi lỗi
      void upsert(Conversation c);        // !isPinned / không khớp lọc → bỏ; còn lại chèn theo last_message_at
      void remove(String id);
    }
    ```
    - `build` nghe `inboxListSignalProvider` và `inboxConversationUpdatesProvider`, rồi `refresh()` (gộp nhịp sẵn có, mỗi lượt một request ≤50 dòng).
    - `query` = `_inboxQueryProvider` + `pinned: true`, `perPage: pageSize`.
    - Lỗi khi tải mục ghim **không** làm hỏng màn: mục ẩn đi, danh sách chính vẫn hiện.
  - `InboxListController.refresh()` và `mergeLatest()` cũng gọi `pinnedConversationsProvider.notifier.refresh()`. Bọc `try`, vì provider có thể chưa dựng.
  - `InboxPinnedSection({required List<Conversation> items, required Widget Function(Conversation) rowBuilder})`:
    - tiêu đề "Đã ghim" (`OmniType.overline`, màu phụ, cao 32);
    - tối đa 5 dòng, rồi dòng "Xem thêm N" ↔ "Thu gọn" (cao 44);
    - không có dòng nào thì không vẽ gì.

    Sau mục ghim là tiêu đề "Hội thoại" **chỉ khi** mục ghim có dòng.
- Trang `InboxPage`:
  - `ListView` dựng từ một danh sách phẳng `[_Header('Đã ghim'), …pinned, _More?, _Header('Hội thoại'), …main, _Loader?]`, chỉ một `ScrollController` (`loadMore` vẫn theo `extentAfter`);
  - rỗng khi **cả hai** rỗng;
  - `InboxBulkBar.allIds` = id của mục ghim + danh sách chính;
  - kéo làm mới thì làm mới cả hai.
- `ConversationRow`: `isMuted` thì vẽ `Icons.notifications_off_outlined` cỡ 14 màu phụ, đặt trước giờ, kèm Semantics "Đã tắt thông báo".
- `InboxFilterPanel`: chip "Đã chặn" chỉ khi `access.canBlock`, không có số.

- [ ] **Step 1: Test hỏng** (`inbox_pinned_section_test.dart`). Dựng `InboxPage` với `inboxApiProvider` giả, trả hai trang khác nhau theo `query['pinned']`:
  - có ghim → thấy "Đã ghim" + dòng ghim ở trên, rồi "Hội thoại" + dòng thường; request danh sách chính có `pinned=0`, request mục ghim có `pinned=1` và `per_page=50`;
  - 7 dòng ghim → thấy 5 + "Xem thêm 2"; bấm thì thấy đủ 7 và "Thu gọn";
  - không có ghim → không có hai tiêu đề;
  - mục ghim lỗi (API ném) → danh sách chính vẫn hiện, không có thông báo lỗi toàn màn;
  - chính và ghim đều rỗng → `OmniEmptyState` "Hộp thư trống"; chỉ chính rỗng → không có empty state;
  - tab "Đã chặn" → không gọi `pinned=1`;
  - gỡ trang bằng `pumpWidget(SizedBox())` trước khi bài kết thúc (trang có poll).
- [ ] **Step 2: Test hỏng** (`inbox_list_controller_test.dart`):
  - `build`, `loadMore`, gộp trang 1 đều gửi `pinned=0`;
  - `conversation.updated` cho một hội thoại mà `GET {id}` trả `is_pinned:true` → **không** chèn vào danh sách chính, và bỏ dòng nếu đang có;
  - `reconcile(c.copyWith(isPinned:false))` cho dòng chưa có trên màn → chèn đúng chỗ theo `lastMessageAt`;
  - hội thoại trả về `blocked_at` → bỏ dòng.
- [ ] **Step 3: Test hỏng:**
  - `inbox_filter_panel_test.dart`: quyền `{inbox.read, inbox.write}` có chip "Đã chặn"; `{inbox.read.own, inbox.write}` và `{inbox.read}` không có;
  - `conversation_row_test.dart`: `isMuted:true` có Semantics "Đã tắt thông báo", `false` thì không.
- [ ] **Step 4: Làm cho xanh.** Kiểm ở 360 và 800 rộng: không tràn, tiêu đề không cắt chữ, dòng "Xem thêm" chạm được 44.
- [ ] **Step 5: Format, analyze, cả bộ test, rồi commit.** Message: `feat(hop-thu): mục Đã ghim ở đầu danh sách, chip Đã chặn, dấu tắt thông báo`.

---

### Task 3: Menu bấm giữ và trang Thông tin: chưa đọc · tắt TB · ghim · chặn

**Files:**
- Modify:
  - `lib/modules/inbox/presentation/widgets/conversation_actions.dart`
  - `lib/modules/inbox/presentation/inbox_page.dart` (`_openPeek` ánh xạ hành động mới)
  - `lib/modules/inbox/presentation/thread_info_page.dart`
  - `lib/modules/inbox/presentation/widgets/conversation_peek.dart` (chỉ khi menu dài cần cuộn)
- Test:
  - `test/modules/inbox/conversation_peek_test.dart`
  - `test/modules/inbox/thread_info_page_test.dart`

**Interfaces:**
- Consumes: Task 1 (`InboxApi.markUnread/setPinned/setMuted/setBlocked`, `InboxAccess.canBlock`), Task 2 (`pinnedConversationsProvider.upsert/remove`, `reconcile` chèn).
- Produces:
  - `enum PeekAction { markRead, markUnread, assign, label, pin, unpin, mute, unmute, archive, reopen, block, unblock }`
  - `peekMenuFor(c, access)`, theo thứ tự của README:
    1. "Đánh dấu đã đọc" (`isUnread && canUpdate`) hoặc "Đánh dấu chưa đọc" (`!isUnread && canUpdate`);
    2. Gán cho…;
    3. Thêm nhãn;
    4. "Ghim" hoặc "Bỏ ghim" (luôn hiện, quyền đọc là đủ);
    5. "Tắt thông báo" hoặc "Bật thông báo" (luôn hiện);
    6. Lưu trữ hoặc Mở lại;
    7. "Chặn" (`canBlock && !isBlocked`, `destructive`) hoặc "Bỏ chặn" (`canBlock && isBlocked`).

    Biểu tượng:
    - chưa đọc `Icons.mark_email_unread_outlined`;
    - ghim `Icons.push_pin_outlined`;
    - tắt TB `Icons.notifications_off_outlined`, bật TB `Icons.notifications_active_outlined`;
    - chặn `Icons.block_rounded`.
  - `ConversationActions`, mỗi hàm theo đúng mẫu `_run`: gọi API → vá → làm mới → báo.
    - `markUnread(c)` → `c.copyWith(unread: max(1, n))`. Báo "Đã đánh dấu chưa đọc."
    - `setPinned(c, on)` → `c.copyWith(isPinned: on)`, rồi `reconcile` danh sách chính (ghim thì rời, bỏ ghim thì chèn) **và** `pinned.upsert`.
      - Báo "Đã ghim hội thoại." hoặc "Đã bỏ ghim."
      - 422 `pin_limit_reached` → báo đúng `error.message` của server.
    - `setMuted(c, on)` → `c.copyWith(isMuted: on)`, vá cả hai danh sách. Báo "Đã tắt thông báo." hoặc "Đã bật thông báo."
    - `setBlocked(c, on)`:
      - `on` thì hỏi `showOmniConfirm` trước (xem Phán quyết);
      - kết quả là hội thoại server trả về → `reconcile` (bị bỏ khỏi danh sách chính vì `isBlocked`) + `pinned.remove/upsert`;
      - báo "Đã chặn khách." hoặc "Đã bỏ chặn."
    - `_run` đổi thành nhận `Future<Conversation> Function()`, giữ nguyên chữ ký. Phần vá bọc `try` như hiện nay (container có thể đã huỷ). Thêm `_container.read(pinnedConversationsProvider.notifier).upsert(updated)` trong cùng khối `try`.
  - **Xoá** đoạn chú thích ở doc của `peekMenuFor` (~dòng 176–177, "Chỉ có mục mà máy chủ làm được: chưa có API đánh dấu chưa đọc / tắt thông báo / ghim / chặn"), thay bằng mô tả quyền của từng mục. Brief gọi đây là dòng :154; số dòng thật là ~176.
- `ThreadInfoPage`:
  - hàng nút tròn của `_Hero`: Gọi · Hồ sơ/Chuyển KH · **Tắt TB/Đã tắt** (`Icons.notifications_off_outlined`, nút ở trạng thái bật thì nền `accent`) · Tìm tin;
  - mục cuối (giờ hiện với **mọi** người đọc; từng dòng tự xét quyền):
    - "Ghim hội thoại": dòng có `Switch` (`ThreadInfo.dc.html` `.sw`, bật màu chính `#0A7D76`/token, tắt `#C9D2DE`/token, cả dòng chạm được ≥44). Công tắc đổi theo kết quả server, không đổi trước;
    - "Đánh dấu chưa đọc" (`canUpdate && !isUnread`): xong thì `context.goNamed(InboxRoutes.list)`. Lấy `GoRouter.of(context)` trước `await`;
    - "Lưu trữ hội thoại" / "Mở lại hội thoại" (`canUpdate`, như cũ);
    - "Chặn khách này" (chữ `danger`, `canBlock && !isBlocked`): xong thì cũng về Hộp thư. "Bỏ chặn khách này" (`canBlock && isBlocked`) thì ở lại trang.
  - Trạng thái đọc từ `conversationProvider(id)`. Vì `_run` đã `invalidate`, trang tự dựng lại theo server.

- [ ] **Step 1: Sửa test cũ thành test mới, cho hỏng.**
  - `conversation_peek_test.dart:113-114`: bỏ hai khẳng định `findsNothing … 'API chưa có'`.
  - Thêm vào `conversation_peek_test.dart`:
    - đủ quyền (`inbox.read, inbox.write`), hội thoại đã đọc → menu có "Đánh dấu chưa đọc", "Ghim", "Tắt thông báo", "Chặn";
    - `{inbox.read}` → có "Ghim", "Tắt thông báo", **không** có "Đánh dấu chưa đọc" hay "Chặn";
    - `{inbox.read.own, inbox.write}` → có "Đánh dấu chưa đọc", **không** có "Chặn";
    - "Ghim" → `POST …/pin`; dòng rời danh sách chính và hiện trong "Đã ghim"; snackbar "Đã ghim hội thoại.";
    - "Ghim" bị 422 `pin_limit_reached` → snackbar đúng câu server, dòng giữ nguyên;
    - "Chặn" → hộp xác nhận; "Huỷ" thì không có request; "Chặn" thì `POST …/block` và dòng rời danh sách;
    - "Đánh dấu chưa đọc" → `POST …/unread`; dòng có huy hiệu chưa đọc;
    - "Tắt thông báo" → `POST …/mute`; dòng có chuông gạch; menu lần sau ghi "Bật thông báo";
    - thao tác xong **sau** khi trang đã gỡ → không ném (mẫu bài 304 đang có);
    - menu 9 mục vẫn chạm được ở cửa sổ 800×600 và 390×844: cuộn được, mục cuối hiện được.
  - `thread_info_page_test.dart:162`: bài "không có mục API chưa hỗ trợ" đổi thành "đủ mục mới". Thêm:
    - có "Tắt TB", "Ghim hội thoại", "Chặn khách này" (khi `canBlock`);
    - `.own` không có "Chặn khách này";
    - công tắc Ghim gọi `POST` hoặc `DELETE …/pin` và đổi theo phản hồi;
    - "Đánh dấu chưa đọc" → điều hướng về `/inbox`;
    - hội thoại `blocked_at` có giá trị → "Bỏ chặn khách này" → `DELETE …/block`;
    - giao diện tối: chữ "Chặn khách này" dùng màu nguy hiểm của theme tối.
- [ ] **Step 2: Chạy, thấy đỏ.** `…\flutter test test/modules/inbox/conversation_peek_test.dart test/modules/inbox/thread_info_page_test.dart`
- [ ] **Step 3: Làm cho xanh.** Hành động mới **không** được phát snackbar thành công khi API ném lỗi (kiểm bằng adapter trả 500).
- [ ] **Step 4: Format, analyze, cả bộ test, rồi commit.** Message: `feat(hop-thu): chưa đọc, tắt thông báo, ghim, chặn trong menu xem trước và trang Thông tin`.

---

### Task 4: Cảm xúc nội bộ: thanh cảm xúc, bấm đúp thả tim, viên cảm xúc đội, realtime

**Files:**
- Create:
  - `lib/modules/inbox/presentation/widgets/team_reactions.dart`
  - `lib/modules/inbox/presentation/widgets/heart_burst.dart`
  - `test/modules/inbox/team_reactions_test.dart`
  - `test/modules/inbox/thread_team_reaction_realtime_test.dart`
- Modify:
  - `lib/modules/inbox/application/thread_controller.dart`
  - `lib/modules/inbox/application/inbox_realtime.dart`
  - `lib/modules/inbox/presentation/widgets/message_actions_overlay.dart`
  - `lib/modules/inbox/presentation/widgets/message_bubble.dart`
  - `lib/modules/inbox/presentation/thread_page.dart`
  - `lib/design/tokens/omni_typography.dart`
- Test:
  - `test/modules/inbox/message_actions_test.dart`
  - `test/modules/inbox/thread_page_test.dart`

**Interfaces:**
- Consumes: Task 1 (`TeamReaction`, `Message.teamReactions`, `InboxApi.toggleTeamReaction`, `InboxAccess.canReact`).
- Produces:
  - `ThreadController.toggleTeamReaction(String messageId, String emoji, {required String myUserId, String? myName}) → Future<void>`:
    1. tin không có trên màn hoặc `isPending` → bỏ qua;
    2. tính danh sách lạc quan: bỏ mục của tôi; nếu emoji cũ của tôi **khác** emoji này thì thêm mục mới;
    3. đặt `state`, gọi API;
    4. thành công thì **thay** bằng danh sách server;
    5. lỗi thì trả danh sách cũ rồi `rethrow`.

    Có `_disposed` guard như `togglePin`.
  - `ThreadController.applyTeamReactions(String messageId, List<TeamReaction> list) → bool`: thay tại chỗ; tin chưa tải thì trả `false`.
  - `ThreadRealtimeSignal`:
    - nhánh mới: `event.event == 'message.team_reaction'` → parse `team_reactions` → `applyTeamReactions` khi `ref.exists(threadProvider(arg))`, rồi `return`;
    - **không** thêm vào `_refetchEvents`, **không** tải lại kể cả khi tin chưa có (lượt tải lịch sử sau đã mang sẵn);
    - `message.reaction` (của khách) giữ nguyên trong `_refetchEvents`.
  - `showMessageActions(… , {List<String>? reactions, String? myReaction, ValueChanged<String>? onReact})`:
    - có `onReact` thì vẽ thanh cảm xúc **trên** bong bóng nổi (`Thread.dc.html` dòng 123–126):
      - khung bo 24, padding 4, nền trắng .92 / `surfaceContainerHigh` .92 khi tối;
      - bóng `0 10 30 rgba(11,26,51,.25)`;
      - nút 44×44 bo 22;
      - emoji dùng token mới `OmniChatType.reaction` (cỡ 20, đặt trong `lib/design`);
      - emoji đang chọn có nền `accent` (`#E6F3F2` sáng, token tối tương ứng);
    - chọn → đóng hộp → `onReact(emoji)`;
    - hiệu ứng `pop .35s` lệch 30ms mỗi nút, tắt khi `!OmniMotion.enabled`.

    `const kTeamReactionChoices = ['👍','❤️','😂','😮','🙏','✅'];`
  - **Xoá** chú thích `message_actions_overlay.dart:36-37` ("KHÔNG có thanh cảm xúc và không bắt bấm đúp: API cảm xúc chưa có…"), thay bằng mô tả thanh cảm xúc nội bộ (không gửi cho khách).
  - `MessageBubble` thêm:
    - `onReact` (`ValueChanged<String>?`, null = không thanh, không bấm đúp);
    - `myUserId`;
    - `onShowReactors`.

    Trong `_ReplySwipe` thêm `DoubleTapGestureRecognizer` vào `RawGestureDetector` khi `onReact != null`. Bấm đúp gửi `'❤️'`. Nếu ❤️ của tôi **chưa có** thì phát `HeartBurst` + `HapticFeedback.lightImpact()`.
  - `HeartBurst`:
    - `StatefulWidget` 800ms;
    - tim `Icons.favorite` cỡ 44 màu `#E5484D` (token mới `OmniColors.heart` nếu chưa có màu tương đương);
    - nằm giữa theo chiều dọc bong bóng, cách mép trong 24 (`right` khi tin đi, `left` khi tin đến);
    - `IgnorePointer`; motion tắt thì không dựng gì.
  - `TeamReactionChips(reactions, myUserId, onTap)`:
    - gom theo emoji theo thứ tự xuất hiện;
    - "❤️" khi chỉ một người, "❤️ 2" khi nhiều;
    - `Transform.translate(0,-6)`, bo 9, viền `outlineVariant` (của tôi thì màu chính);
    - chữ `OmniChatType.reactionChip` (12);
    - vùng chạm cả hàng ≥44 cao (bọc padding trong suốt);
    - Semantics "Cảm xúc nội bộ: ❤️ Lan, Minh".

    Chạm thì mở `showOmniSheet` danh sách "emoji · tên" (tên null thì ghi "Thành viên").
  - `ThreadPage` nối:
    - `onReact` khi `access.canReact && !message.isPending && !message.isNote`;
    - `myUserId` lấy từ `sessionProvider`;
    - lỗi → snackbar "Không thả được cảm xúc. Vui lòng thử lại." (lấy messenger trước `await`).

- [ ] **Step 1: Sửa test cũ thành test mới, cho hỏng** (`message_actions_test.dart`):
  - bài 115 "giữ tin → menu đủ mục, không có thanh cảm xúc" → "giữ tin → thanh 6 cảm xúc + menu". Có `find.text('❤️')` trong overlay, mỗi nút ≥44×44;
  - bài 306 "bấm đúp tin không làm gì (chưa có API cảm xúc)" → "bấm đúp → POST team-reactions {emoji:'❤️'}, ❤️ hiện dưới tin, tim bay". Bấm đúp lần nữa → POST lần hai, ❤️ biến mất, không có tim bay;
  - bài 239 "bấm ảnh vẫn mở trình xem ảnh": thêm `await tester.pump(const Duration(milliseconds: 350))` sau chạm (trễ do nhận dạng bấm đúp) và vẫn phải xanh;
  - mới: `{inbox.read}` → không có thanh cảm xúc, bấm đúp không gửi request;
  - mới: chọn 👍 trên thanh → POST `{emoji:'👍'}`, viên "👍" có viền màu chính;
  - mới: API lỗi 500 → viên trở lại như cũ, snackbar báo lỗi;
  - mới: giảm chuyển động → bấm đúp không dựng `HeartBurst` (`find.byType(HeartBurst)` findsNothing sau một `pump()`);
  - mới: tin nháp (`isPending`) → bấm đúp không gửi.
- [ ] **Step 2: Test hỏng** (`team_reactions_test.dart`):
  - tin có `reaction:'😮'` (khách) và `team_reactions` [❤️ Lan, ❤️ Minh, 👍 tôi] → vòng góc "😮" **và** viên "❤️ 2", "👍";
  - Semantics chứa "Cảm xúc nội bộ";
  - chạm viên → sheet có "Lan", "Minh";
  - giao diện tối: nền viên không phải trắng cứng.
- [ ] **Step 3: Test hỏng** (`thread_team_reaction_realtime_test.dart`), dùng `realtimeClientProvider` giả như `inbox_realtime_signal_test.dart`:
  - `message.team_reaction` cho tin đang có → danh sách đổi, **không** có request `GET …/messages` nào;
  - cho tin chưa tải → không request, không ném;
  - `message.reaction` → vẫn tải lại như cũ (có `GET …/messages`).
- [ ] **Step 4: Làm cho xanh.** Chạy thêm `thread_page_test.dart`, `message_bubble_links_test.dart` (link vẫn mở), `thread_layout_test.dart`.
- [ ] **Step 5: Format, analyze, cả bộ test, rồi commit.** Message: `feat(hop-thu): cảm xúc nội bộ — thanh cảm xúc, bấm đúp thả tim, realtime`.

---

### Task 5: Composer gửi tệp, trần 10 tệp, khả năng gửi theo kênh, tin lỗi `channel_send_unsupported`

**Files:**
- Modify:
  - `pubspec.yaml` (`file_picker`)
  - `lib/modules/inbox/presentation/widgets/message_composer.dart`
  - `lib/modules/inbox/presentation/thread_page.dart`
  - `lib/modules/inbox/presentation/widgets/message_bubble.dart` (`_MetaLine`)
  - `lib/modules/inbox/application/inbox_realtime.dart` (`_absorbSent` cho `failed`)
  - `lib/modules/inbox/application/thread_controller.dart` (`applyFailure`)
- Create: `test/modules/inbox/composer_files_test.dart`, `test/modules/inbox/message_failed_unsupported_test.dart`
- Test:
  - `test/modules/inbox/message_composer_messenger_test.dart`
  - `test/modules/inbox/composer_keeps_tray_test.dart`
  - `test/modules/inbox/thread_page_test.dart`

**Gói `file_picker`:**
- [ ] **Step 0: Thêm và kiểm nền tảng.**
  - Chạy `D:\_tools\flutter\bin\flutter pub add file_picker`, rồi ghi phiên bản đã giải (kỳ vọng ≥10.x) vào báo cáo.
  - Kiểm trang pub.dev của đúng phiên bản: phải có **Android** và **iOS**.
  - Android dùng Storage Access Framework, **không** cần quyền đọc bộ nhớ. iOS với `FileType.custom` dùng `UIDocumentPickerViewController`, **không** cần khoá Info.plist.
  - Chạy `flutter pub get` cho sạch. iOS không dựng được trên Windows, nên ghi "chưa kiểm trên iOS thật" vào báo cáo; `Podfile` đã ở `15.0`, đủ cho gói.
  - Nếu `flutter analyze` hay bản dựng Android (`flutter build apk --debug`, nếu có SDK; memory `viomni-build-toolchain` nói máy thiếu Android SDK) báo lỗi do gói thì dừng, báo BLOCKED.

**Interfaces:**
- Consumes: Task 1 (`OutboundCapabilities`, `Message.isChannelUnsupported`, `InboxApi.maxAttachmentsPerMessage`, `maxUploadBytes`).
- Produces:
  - `class PendingAttachment { final String path; final String name; final int? size; final PendingKind kind /* image | file | voice */; }`. Đây là tệp đang chờ trong composer, thay `List<XFile>`.
    - `onSend` đổi chữ ký thành `Future<void> Function(String text, List<PendingAttachment> attachments, Message? replyTo)`.
    - `_ImageTray` vẽ ảnh như cũ; tệp thì vẽ ô 56 có đuôi (`PDF`) + tên một dòng + nút ✕ 44.
  - `MessageComposer` nhận thêm:
    - `OutboundCapabilities? capabilities`;
    - `Future<List<PendingAttachment>> Function()? onPickFiles` (null = ẩn mục Tệp);
    - `bool Function()? confirmBeforeSend` (không cần; cảnh báo xử lý trong composer, dùng `showOmniConfirm`).
  - Luật composer:
    - `capabilities?.canSendImages == false` → ẩn máy ảnh và ảnh;
    - mục "Tệp" (`Icons.attach_file_rounded`, `OmniHue` trung tính, nhãn "Tệp") trong khay chỉ khi `onPickFiles != null && capabilities?.canSendFiles == true`. `null` capabilities = API cũ thì ẩn;
    - đã đủ `maxAttachmentsPerMessage` thì nút ảnh, máy ảnh, Tệp bị vô hiệu (vẫn hiện, `onTap: null`, Semantics "Đã đủ 10 tệp");
    - thêm vào quá trần thì cắt và báo "Mỗi tin tối đa 10 tệp — đã bỏ N tệp.";
    - tệp `size > maxUploadBytes` thì bỏ và báo "Tệp vượt 25MB, không gửi được.";
    - `file == docsOnly` và (đuôi ∉ `{pdf,doc,docx,csv}` hoặc `size > 5MB`), hoặc `file == link` → `showOmniConfirm` theo Phán quyết; "Huỷ" thì không thêm.
  - `ThreadPage`:
    - `onPickFiles`: `FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: kInboxFileExtensions, withData: false)` → `PendingAttachment(kind: file, size: f.size, path: f.path!)` (bỏ tệp `path == null`);
    - `const kInboxFileExtensions = ['pdf','doc','docx','xls','xlsx','ppt','pptx','txt','csv'];` kèm chú thích "khớp `omni-flow-api/config/media.php` kind `file`";
    - chọn ảnh dùng `pickMultiImage(imageQuality: 85, limit: còn lại)`. `limit` cần image_picker ≥1.1: kiểm trong `pubspec.lock`; thiếu thì chỉ cắt phía app;
    - `capabilities` lấy từ `conversationProvider(id).valueOrNull?.outboundCapabilities`;
    - `capabilities?.canSendText == false` → thay composer bằng dòng thông báo (Phán quyết). Giữ `_ReadOnlyBar` cho người thiếu quyền, thêm `_ChannelCannotSendBar`;
    - upload dùng `uploadMedia(path, filename: name)` → `MessageAttachment.fromUpload`, để **giữ đúng `type` server trả** (Facebook dùng nó làm loại attachment).
  - Tin lỗi:
    - `_MetaLine`: `message.isChannelUnsupported` → ẩn nút "Gửi lại"; chữ lỗi = `message.error ?? kChannelUnsupportedText`;
    - `ThreadPage` không truyền `onRetry` cho tin đó.
    - `ThreadController.applyFailure(String messageId, String? error, String? errorCode) → bool`.
    - `_absorbSent`: `status == 'failed'` có `error` hoặc `error_code` → vá tại chỗ bằng `applyFailure`, không tải lại. Trước đây phải tải lại vì sự kiện không mang lý do; nay API gửi kèm (`DeliverOutboundMessage::broadcastStatus`).

- [ ] **Step 1: Sửa test cũ thành test mới, cho hỏng.**
  - `message_composer_messenger_test.dart:61-71`: "không Báo giá/Tệp/Ghi âm" đổi thành:
    - `capabilities` toàn `native` + `onPickFiles` → khay có "Tệp", vẫn **không** có "Báo giá";
    - `capabilities: null` → không có "Tệp";
    - `file: none` → không có "Tệp".
    - Phần "Ghi âm" để Task 6 sửa; tạm giữ khẳng định `findsNothing` cho tới Task 6.
  - Sửa mọi chỗ gọi `onSend` trong test cũ theo chữ ký mới (`composer_keeps_tray_test.dart`, `message_composer_rebuild_test.dart`, `composer_tray_tones_test.dart`).
- [ ] **Step 2: Test hỏng** (`composer_files_test.dart`):
  - chọn 2 tệp (pdf 1MB, xlsx 2MB) → khay hiện "PDF", "XLSX" + tên; gửi → `onSend` nhận 2 `PendingAttachment(kind: file)`;
  - đã có 9 ảnh, chọn 3 tệp → giữ 1, snackbar "đã bỏ 2 tệp"; đủ 10 → nút ảnh bị vô hiệu;
  - tệp 26MB → bị bỏ + "Tệp vượt 25MB";
  - Zalo OA (`file: docs_only`): `.xlsx` → hỏi "…gửi dưới dạng đường link"; "Huỷ" thì khay rỗng; `.pdf` 1MB thì không hỏi; `.pdf` 6MB thì hỏi;
  - `can_send:false` (TikTok) → `ThreadPage` không có `MessageComposer`, có dòng "Kênh này chưa gửi tin được từ Hộp thư";
  - 360px: không tràn, ô tệp có nút ✕ ≥44.
- [ ] **Step 3: Test hỏng** (`message_failed_unsupported_test.dart`):
  - tin `failed` + `error_code: channel_send_unsupported` → hiện câu `error` của server, **không** có "Gửi lại";
  - tin `failed` không có `error_code` → vẫn có "Gửi lại" (giữ năng lực cũ);
  - realtime `message.sent {status:'failed', error, error_code}` cho tin trên màn → vá tại chỗ, không có `GET …/messages`;
  - giao diện tối: chữ lỗi dùng `scheme.error`.
- [ ] **Step 4: Test hợp đồng gửi** (bổ sung `test/inbox/inbox_api_hop_thu_contract_test.dart`): gửi 1 ảnh + 1 tệp, `type` lấy từ phản hồi upload (`image`, `file`), không phải từ đuôi tệp.
- [ ] **Step 5: Làm cho xanh; format, analyze, cả bộ test, rồi commit.** Message: `feat(hop-thu): gửi tệp, trần 10 tệp, theo khả năng gửi của kênh; báo rõ kênh không hỗ trợ gửi`.

---

### Task 6: Ghi âm gửi dạng tệp audio, quyền micro Android/iOS, cảnh báo Zalo OA; dọn và kiểm live

**Files:**
- Create:
  - `lib/modules/inbox/application/voice_recorder.dart`
  - `lib/modules/inbox/presentation/widgets/voice_record_bar.dart`
  - `test/modules/inbox/composer_voice_test.dart`
- Modify:
  - `pubspec.yaml` (`record`, `path_provider`)
  - `android/app/src/main/AndroidManifest.xml`
  - `android/app/build.gradle.kts` (chỉ khi `minSdk` < yêu cầu của `record`)
  - `ios/Runner/Info.plist`
  - `lib/modules/inbox/presentation/widgets/message_composer.dart`
  - `lib/modules/inbox/presentation/thread_page.dart`
- Test:
  - `test/modules/inbox/message_composer_messenger_test.dart`
  - `test/architecture/*` (chạy lại)

**Gói và quyền:**
- [ ] **Step 0: Thêm `record` và `path_provider`, cấu hình quyền.**
  - Chạy `…\flutter pub add record path_provider`, ghi phiên bản (kỳ vọng `record` ≥6.x).
  - Kiểm pub.dev: có **Android** và **iOS**. Đọc `minSdk` mà `record_android` đòi (≥23 ở bản 6.x). Nếu `flutter.minSdkVersion` của SDK hiện tại thấp hơn thì đặt `minSdk = maxOf(flutter.minSdkVersion, 23)` trong `android/app/build.gradle.kts` và ghi vào báo cáo.
  - Android: thêm `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` cạnh `INTERNET` trong `AndroidManifest.xml`.
  - iOS: thêm vào `Info.plist`:
    ```xml
    <key>NSMicrophoneUsageDescription</key>
    <string>Viomni cần micro để ghi âm tin nhắn thoại gửi cho khách.</string>
    ```
    Đặt cạnh `NSCameraUsageDescription`. Thiếu khoá này thì iOS **giết app** ngay lần đầu xin micro.
  - Dùng `AudioRecorder.hasPermission()` của `record` để xin quyền lúc chạy (cả hai nền tảng), không thêm `permission_handler`.

**Interfaces:**
- Produces:
  ```dart
  abstract interface class VoiceRecorder {
    Future<bool> ensurePermission();             // false = bị từ chối
    Future<void> start(String path);             // WAV PCM16 16kHz mono
    Future<String?> stop();                      // đường dẫn tệp, null nếu lỗi
    Future<void> cancel();                       // dừng + xoá tệp
    Stream<Duration> get elapsed;                // nhịp 200ms
    Future<void> dispose();
  }
  final voiceRecorderProvider = Provider.autoDispose<VoiceRecorder>(…RecordVoiceRecorder…);
  ```
  - `RecordVoiceRecorder` dùng `AudioRecorder().start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1), path: path)`.
  - Tệp tạm: `getTemporaryDirectory()/ghi-am-<yyyyMMdd-HHmmss>.wav`.
- `MessageComposer`:
  - thêm `Future<void> Function(PendingAttachment voice)? onSendVoice` (null = ẩn mic) và `bool warnVoiceAsLink`;
  - nút mic `Icons.mic_none_rounded`, tooltip "Ghi âm", vùng chạm 44, đứng sau nút ảnh trong cụm công cụ. Gõ chữ thì thu thành › như các nút khác;
  - chỉ hiện khi `capabilities?.canSendVoice == true && onSendVoice != null`.
- Luồng ghi âm:
  1. `warnVoiceAsLink` và chưa hỏi trong phiên này → `showOmniConfirm` (Phán quyết); "Huỷ" thì dừng.
  2. `ensurePermission()` false → snackbar "Chưa có quyền micro — bật trong Cài đặt để ghi âm." và dừng.
  3. `start` → `VoiceRecordBar` thay hàng nhập:
     - chấm đỏ (nhấp nháy 1s, tắt khi `!OmniMotion.enabled`);
     - `mm:ss`;
     - nút "Huỷ" (thùng rác, 44) → `cancel`;
     - nút Gửi (44) → `stop`.
  4. Tới **5:00** thì tự `stop` và **giữ** thanh để người dùng bấm Gửi hoặc Huỷ (không tự gửi).
  5. `< 1s` → bỏ tệp + "Ghi âm quá ngắn."
  6. Gửi → `onSendVoice(PendingAttachment(kind: voice, path, name, size))`.
  7. `ThreadPage`: `uploadMedia` → `sendAfterUpload('', attachments: …)`. Server trả `type: audio`, giữ nguyên `type` đó.
  8. Rời trang khi đang ghi → `cancel()` trong `dispose`.

  Đang ghi thì khoá các nút khác của composer.
- `ThreadPage`: `warnVoiceAsLink = capabilities?.audio == OutboundMode.link`.

- [ ] **Step 1: Sửa test cũ thành test mới, cho hỏng.**
  - `message_composer_messenger_test.dart`: `find.byTooltip('Ghi âm')`:
    - có khi `audio: native` + `onSendVoice`;
    - không có khi `audio: none` hoặc `capabilities: null`.
  - Bài "360px không tràn" phải xanh **với** nút mic: 5 công cụ khi trống, thu thành › khi gõ.
- [ ] **Step 2: Test hỏng** (`composer_voice_test.dart`), dùng `FakeVoiceRecorder` override `voiceRecorderProvider` (nhịp `elapsed` do test điều khiển):
  - bấm mic → `start` được gọi với đường dẫn `.wav`; thấy "00:00", rồi "00:03" sau khi phát nhịp; Gửi → `onSendVoice` nhận tệp `kind: voice`;
  - Huỷ → `cancel`, không có `onSendVoice`;
  - quyền bị từ chối → snackbar "Chưa có quyền micro", không `start`;
  - 0,5s → "Ghi âm quá ngắn.", không gửi;
  - 5:00 → tự `stop`, thanh vẫn hiện, chưa gửi;
  - Zalo OA (`audio: link`): bấm mic → hộp "…gửi dưới dạng đường link…"; "Huỷ" thì không `start`; "Vẫn ghi âm" thì `start`; bấm mic lần hai trong cùng phiên thì không hỏi lại;
  - giảm chuyển động: chấm đỏ không có hoạt ảnh lặp (`tester.hasRunningAnimations == false` sau `pump()`);
  - gỡ trang khi đang ghi → `cancel` được gọi.
- [ ] **Step 3: Test hợp đồng** (bổ sung `inbox_api_hop_thu_contract_test.dart`): gửi ghi âm → body `attachments: [{url, type:'audio', name:'ghi-am-….wav'}]`, không có `text`.
- [ ] **Step 4: Làm cho xanh; format, analyze, cả bộ test.**
- [ ] **Step 5: Dọn chú thích và guard "chưa có API".**
  - Chạy `rg -n -i "chưa có API|API cảm xúc|API chưa có|không có API" lib test`. Chỉ được còn chỗ **thật sự** chưa có API (ví dụ Báo giá); mọi chỗ về chưa đọc, tắt TB, ghim, chặn, cảm xúc, tệp, ghi âm phải hết.
  - Kiểm `message_actions_overlay.dart` (doc `showMessageActions`) và `conversation_actions.dart` (doc `peekMenuFor`) đã sửa ở Task 3 và Task 4.
- [ ] **Step 6: Kiểm live.** Đây là kiểu lỗi chỉ bài kiểm live bắt được.
  - API local chạy code `feat/hop-thu-mobile`: container `omnicrm-pro-api`, `php artisan migrate` cho index mới.
  - Nếu Docker Desktop đang tắt thì ghi "chưa kiểm live" vào báo cáo; **không** báo xong.
  - Gọi bằng curl, hoặc chạy app (Windows/thiết bị) trỏ vào API local, lần lượt:
    1. `POST /unread` → dòng đậm lại;
    2. `POST /pin` → mục "Đã ghim"; `GET ?pinned=0` không có dòng đó;
    3. `POST /mute` → chuông gạch;
    4. `POST /team-reactions {"emoji":"❤️"}` → realtime `message.team_reaction` tới máy thứ hai đang mở cùng hội thoại;
    5. `POST /block` bằng admin → dòng biến mất; chip "Đã chặn" thấy lại; `DELETE /block`;
    6. upload một `.wav` ghi bằng `record` thật (hoặc tệp WAV 16kHz mẫu) lên `POST /inbox/media` → `type: audio`, không 422. **Nếu bị 422 vì MIME** thì dừng, báo BLOCKED kèm MIME dò được (`php -r "echo (new finfo(FILEINFO_MIME_TYPE))->file('<tệp>');"` trong container);
    7. gửi tin trên hội thoại kênh `internal`/TikTok giả lập (nếu có) → bong bóng lỗi có câu "Kênh này chưa hỗ trợ…", không có "Gửi lại".
  - Ghi lệnh và kết quả vào báo cáo.
- [ ] **Step 7: Commit.** Message: `feat(hop-thu): ghi âm gửi tệp audio theo kênh, quyền micro Android/iOS; dọn chú thích chưa có API`.

---

## Ngoài phạm vi (ghi vào báo cáo cuối)

- Phát lại ghi âm trong bong bóng (trình phát âm thanh); quay hoặc chọn video từ composer.
- Màn "Đã chặn" riêng. Đợt này dùng chip lọc.
- Server: thêm `audio/x-m4a` vào `config/media.php` để đổi ghi âm sang AAC (nhẹ hơn WAV khoảng 8 lần).
- Server: cho sale tự chặn hội thoại của mình (đổi middleware sang `$write`), đúng như plan API đã ghi.
- Thông báo trên app khi `notification.created` có `muted:true`: hiện app không bật toast, nên không có việc. Nếu sau này thêm toast thì phải tôn trọng cờ này.
