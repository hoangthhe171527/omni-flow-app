# Plan board (Kanban): audit of 4 tester reports

Date: 2026-10-14. Read-only audit of `main` in three repos:
- web = `D:\_omnicrm\omni-flow`
- app = `D:\_omnicrm\omni-flow-app`
- api = `D:\_omnicrm\omni-flow-api`

Paths are relative to each repo.

---

## 1. Drag a group (column / section) to reorder it

### Web
- Columns cannot be dragged. `KanbanBoard` only makes cards draggable: `useDroppable` on columns (`src/components/app/KanbanBoard.tsx:80`), and `useDraggable`/`useSortable` on cards (`:131`, `:169`). There is no `SortableContext` around the columns, and `handleDragEnd` handles only cards (`:225-262`).
- The column `…` menu offers Rename, Group rules and Delete. It has no "move left/right" (`src/modules/tasks/ui/app/project-board-page.tsx:889-936`).
- Sections are saved by `saveSections` → `PUT /projects/{id}` with `{sections: [...]}` (`project-board-page.tsx:235-245`). `mapProjectSectionsToApi` sends `order: i`, so the array position becomes the order. It also sends both flags, `requires_checklist` and `counts_for_kpi` (`src/modules/tasks/domain/mappers.ts:269-279`). On read, sections are sorted by `order` (`mappers.ts:294-307`). The board columns follow that array (`use-kanban-grouping.ts:101-103`).
- So a column reorder only needs to reorder the array and call `saveSections`. Persistence and API work as they are today.
- Column reorder only makes sense when the board is grouped by section. Status columns come from `project.statuses`, and assignee columns are derived from the tasks (`use-kanban-grouping.ts:86-100`).

### App
- Columns cannot be dragged. The board is a horizontal `ListView.separated` with `BoardSnapPhysics` (`lib/modules/plans/presentation/plan_board_page.dart:292-296`).
- **Bug: a menu item that does nothing.** The column options sheet has "Sắp xếp nhóm việc" (`plan_board_page.dart:667-671`), which opens `_editSections()` (`:687-688`). `EditSectionsPage` has no reorder control: it is a plain `ListView` of `_SectionRow` with rename, gate, KPI and remove, plus "Thêm nhóm việc" (`edit_sections_page.dart:85-163`). It has no `ReorderableListView` and no up/down buttons.
- Saving goes through `PlansApi.updateSections` → `PUT /projects/{id}` with `order: i` and both flags (`lib/modules/plans/data/plans_api.dart:182-197`). This is the same contract as web.

### API
- `PUT /api/v1/projects/{id}`, middleware `permission:tasks.write` (`modules/Tasks/Interfaces/routes.php:84`).
- `UpdateProjectRequest` rules (`modules/Tasks/Interfaces/Http/Requests/UpdateProjectRequest.php:33-38`):
  - `sections`: array
  - `sections.*.id`: required, string, max 64
  - `sections.*.name`: required, string, max 128
  - `sections.*.order`: nullable integer
  - `sections.*.requires_checklist`: nullable boolean
  - `sections.*.counts_for_kpi`: nullable boolean
- The request replaces the whole array.
- Permission: `UpdateProject` → `assertCanManage` (`Application/UseCases/UpdateProject.php:25`). Only the owner/manager of the plan, or `tasks.projects.manage.all`, may do this. Legacy projects with `owner_id = null` are open to everyone (`Application/Services/ProjectAccessService.php:187-204`).
- There is no dedicated move-section endpoint. Each reorder is a full-array PUT, so the last writer wins. If two managers reorder at the same moment, one of them silently loses their change. This is acceptable, but note it.

### Gaps
- Web: add drag on columns (a dnd-kit horizontal `SortableContext` on the columns, with a drag handle on the header) for `groupBy === "section"` and `canManage`. Exclude the synthetic "Chưa xếp nhóm" column (`NO_SECTION`). On drop, call `saveSections(arrayMove(...))`. No API change is needed.
- App: either add drag reorder (long-press on the column header, or a `ReorderableListView` in `EditSectionsPage`), or rename or remove the "Sắp xếp nhóm việc" item. No API change is needed.
- No capability key is needed, because `PUT /projects` with `order` already exists on every API version.

---

## 2. Drag a task into another group

### Web: cross-column drag works
- `handleDragEnd` resolves the target column. When `item.stage !== targetColumn` it calls `onStageChange` (`KanbanBoard.tsx:236-245`).
- The board maps that call to `PUT /tasks/{id}` with:
  - `{section_id}` when grouped by section (`""` = no group)
  - `{status}` when grouped by status
  - `{assignee_ids}` when grouped by assignee
  (`project-board-page.tsx:354-368`)
- Within a column, dragging writes a fractional `order` (`project-board-page.tsx:372-386`, `use-kanban-grouping.ts:34-52`).
- Gap: a cross-column drop ignores where the card was dropped. Only `section_id` is sent, and the old `order` is kept (`KanbanBoard.tsx:242-244`), so the card lands wherever its old order puts it, not where the user dropped it.
- Locked tasks: `isItemDisabled={(t) => t.locked}` (`project-board-page.tsx:775`). The card cannot be dragged, but other cards can still be dropped around it (`KanbanBoard.tsx:172`). The whole board is disabled when `!canEdit || updateTask.isPending` (`project-board-page.tsx:773`).
- Pinned tasks: `reorderTarget` ignores neighbours from the other pin group and refuses a drop that crosses the pin boundary (`use-kanban-grouping.ts:42-51`). Moving across columns keeps `pinned`, so the card shows up in the pinned zone of the new column.
- QC gate: there is no check on the client. The API rejects the move with 422 and the board shows a toast through `reportTaskWriteError` (`project-board-page.tsx:366`).

### App: no drag; moving happens only from the task detail menu
- Board cards are tap-only: `onTap: () => onOpenTask(task)` (`lib/modules/plans/presentation/widgets/board_column.dart:196`). The app has no `Draggable`, `LongPressDraggable` or `DragTarget` anywhere in `modules/plans` or `modules/tasks`.
- There are two places to move a task:
  - Breadcrumb "Chuyển nhóm việc" → `showOptionSheet` → `PUT /tasks/{id}` with `{section_id}` (`lib/modules/tasks/presentation/task_detail_page.dart:573-575`, `:1057-1081`; `tasks_api.dart:288-297`). This sheet only lists the sections of the current plan.
  - Menu "Chuyển" (`TaskMenuAction.move`) → `showMoveTaskSheet` → `{project_id, section_id}` (`task_detail_page.dart:362-385`; `tasks_api.dart:473-480`).
- Gating: both actions require `isAssigner && !locked && !viewer` (`task_detail_page.dart:502`; `widgets/task_detail/task_menu_sheet.dart:66`). In the app, `isAssigner` means the permission `tasks.projects.manage.all` (`lib/modules/tasks/domain/task_permissions.dart:88`). That is **stricter than the API**, which only needs a non-viewer role on the plan plus `tasks.write`. So in the app an ordinary plan member cannot move tasks between groups, while on web they can.

### API
- `PUT /tasks/{id}` (`permission:tasks.write`, `routes.php:36`). `UpdateTask` runs these checks in order:
  1. `assertCanEditTasks`: a plan viewer gets 403 (`UpdateTask.php:44`, `ProjectAccessService.php:152-160`).
  2. `TaskLock::assertUnlocked`: a locked task gets 423 (`UpdateTask.php:47`).
  3. QC gate when the section really changes: `QualityGate::blocks` → `TaskBlockedException` → 422 "Chưa qua được QC…" (`UpdateTask.php:150-163`; controller `TaskController.php:446-448`).
- The `order` field can be sent in the same PUT, so a drop position across columns is already supported.

### Gaps
- Web: on a cross-column drop, also compute `order` from the neighbours at the drop point and send `{section_id, order}` in one PUT. Optionally, keep a pinned card from being dropped into the unpinned zone of another column.
- App: add drag between columns, for example `LongPressDraggable` on the card and `DragTarget` on `BoardColumn`, plus auto-scroll of the horizontal track at its edges. Disable drag when the task is locked or the user is a viewer, and handle 422 (QC) and 423 (locked) with a snackbar. Decide whether to keep the `tasks.projects.manage.all` gate or align it with the API (non-viewer plus `tasks.write`).
- No new API work is needed and no capability key is needed.

---

## 3. Duplicate-task dialog (MyXTeam-style)

### Web, "Nhân bản" in the task detail footer
- It does **not** use `/tasks/{id}/copy`. It calls `createTask` → `POST /tasks` with: title "Bản sao…", description, priority, the same `project_id` and `section_id`, the same `assignee_ids`, the same `start_date`/`due_date`/`deadline`, the checklist reset to `done: false`, and `related` (`src/modules/tasks/ui/app/task-detail-sheet.tsx:183-207`).
- It shows no dialog. It is shown when `canWrite` (`:268-279`).
- It loses data: labels, custom fields, CRM links (`customer_id`, `sales_opportunity_id`, `lead_id`), checklist assignee/dates/description, `copied_from`, and `order`.
- Web does not declare a `tasks.copy` capability (`src/lib/api-capabilities.ts:4-23`).

### App, "Sao chép công việc" in the task detail menu
- It opens a title-only text sheet (`showTextEditSheet`), then calls `POST /tasks/{id}/copy` with only `{title}` (`lib/modules/tasks/presentation/task_detail_page.dart:301-318`; `tasks_api.dart:606-613`).
- It is gated by `api(ApiCapability.taskCopy) && access.canUpdate`. It is not hidden when the task is locked (`task_detail_page.dart:148`; `task_menu_sheet.dart:65`). That is correct, because the API allows copying a locked task (`tests/Feature/Tasks/LockCoversEveryWriteRouteTest.php:46`).

### API: `POST /api/v1/tasks/{id}/copy`
- Middleware `permission:tasks.write` (`routes.php:60`). Capability `tasks.copy` (`app/Support/ApiCapabilities.php:28`).
- `CopyTaskRequest` accepts **only** these keys (`Interfaces/Http/Requests/CopyTaskRequest.php:19-25`):
  - `title`: nullable, string, max 255
  - `project_id`: nullable, string, max 64
  - `section_id`: nullable, string, max 64
  - `keep_assignees`: nullable boolean (default true)
  - `keep_checklist`: nullable boolean (default true)
- Controller: `TaskController.php:622-647`. Errors: 403 (no access to target plan), 422 (QC gate), 404.
- What `CopyTask` does (`Application/UseCases/CopyTask.php`):
  - Target plan defaults to the source plan. A different plan must exist (`:50-55`). Write access to the target is checked through `CreateTask` → `assertCanEditTasks` (`CreateTask.php:30`).
  - Assignees: the source assignees plus checklist holders, filtered to active members, or `[]` when `keep_assignees=false` (`:57-63`, `:85-88`). There is **no way to pass other assignees**.
  - Section:
    - When the client gives one, it wins. A QC gate on it gives 422 (`CreateTask.php:48-58`).
    - In the same plan without a client section, the source section is used, falling back to the first ungated section if the gate would block (`:93-102`).
    - In another plan without a client section, no section is set.
  - **No check that `section_id` exists in the target plan.** `QualityGate::pendingSummary` treats an unknown id as ungated (`Domain/Support/QualityGate.php:80-82`), so the copy is saved with a dangling `section_id` and shows up as "Chưa xếp nhóm".
  - Dates: `start_date`, `due_date` and `deadline` are always copied from the source. They **cannot be overridden** (`:111`, `:120-121`).
  - Custom fields: copied **only when the target is the same plan**, and always copied in that case. There is no option to turn this off (`:124-126`).
  - Labels, description, priority and CRM links are always copied. `order` is the source order, so the copy sits next to the original (`:107-129`).

### Comparison with what the tester asked for

| Requirement | `/copy` today | Needed |
|---|---|---|
| Rename | `title` ✔ | — |
| Choose team | — (team comes from the plan) | client picker only; no API key |
| Choose plan | `project_id` ✔ | — |
| Choose group | `section_id` ✔ (not validated) | validate against the target plan's sections (422) |
| Start date / end date | ✘ always copied | **add `start_date`, `due_date`** (nullable date; `due_date` also sets `deadline` as `POST /tasks` does; `due_date >= start_date`) |
| Keep original assignees or pick others | `keep_assignees` ✔ / other people ✘ | **add `assignee_ids`** (array of strings, filtered by `activeOnly`; when present it overrides `keep_assignees`; checklist `assignee_id` kept only if still in the set) |
| Copy custom fields or not | ✘ always copied in the same plan | **add `keep_custom_fields`** (boolean, default true). For another plan, either copy fields whose ids exist in the target plan's `custom_fields` definitions, or keep today's "drop" behaviour and document it |
| Copy checklist or not | `keep_checklist` ✔ | — |

**Keys to add to `CopyTaskRequest`, `TaskController::copy` and `CopyTask`:** `start_date`, `due_date`, `assignee_ids`, `keep_custom_fields`. Also add server-side validation of `section_id` against the target plan.

- Name: the request asked about `custom_fields`, but a boolean `keep_custom_fields` matches the existing `keep_*` convention. Copying a value map from the client is not needed.
- Optional extra keys: `keep_labels`, `keep_description`. MyXTeam has these, but the tester did not ask for them.
- **Capability: a new key is required**, for example `tasks.copy_options`, in `ApiCapabilities::ALL`. `BaseFormRequest::validated()` silently drops unknown keys. Without a new key, a new client talking to an older API would send dates and assignees, get 201, and lose those choices without any error. This is the project's known silent-write-drop failure mode.
- Web must switch "Nhân bản" from `POST /tasks` to `POST /tasks/{id}/copy`, gated by `tasks.copy`. Add `taskCopy` and the new key to `src/lib/api-capabilities.ts`.

### Team → plan picker data source
- `GET /api/v1/teams` (`permission:tasks.read`, `routes.php:115-121`) is a facade over `organization_units` with `type=team`. It is readable by workers, because the route deliberately does not require `organization.org_units.read` (`routes.php:95-111`).
- `GET /api/v1/projects?team_id=…` filters plans by team (`ProjectController.php:94`; `MongoProjectRepository.php:84-85`). Each project also carries `team_id`/`team_name`, and each response carries `sections`.
- Web today:
  - The project form reads teams from `useOrgUnits()` (`src/modules/tasks/ui/app/project-form-dialog.tsx:21`, `:64`). That needs `organization.org_units.read`, which workers lack. The copy dialog should use `/teams` or group `GET /projects` by `teamId`, as the projects page does (`src/modules/tasks/domain/project-teams.ts:50`).
  - `project-teams-api.ts` already calls `/teams`.
- App today:
  - `PlansApi` lists `/teams` (`lib/modules/plans/data/plans_api.dart:48`).
  - `TasksApi.projectsForMove()` pages through `GET /projects` but keeps only id, name and sections, without team (`lib/modules/tasks/data/tasks_api.dart:739-764`).
  - To pick a team first, add `team_id`/`team_name` to `MovablePlan` and group by it. The move sheet (`widgets/task_detail/move_task_sheet.dart:45`) can be reused for the copy dialog.
- Assignee picker: plan members come from `GET /projects/{id}` (`member_ids` plus names, capability `projects.member_names`). Use the members of the **target** plan.

### Permissions for copy
- Route: `tasks.write`. Target plan: must not be a viewer (`assertCanEditTasks`).
- Source: must be readable, because the repository scope applies.
- Locked source: allowed.

---

## 4. Mouse wheel scrolls the board horizontally

### Web
- The board container is plain CSS `overflow-x-auto` (`project-board-page.tsx:764-767`). Each column body is `overflow-y-auto` (`KanbanBoard.tsx:113`). The web codebase has no `onWheel`, `wheel` listener or `deltaY` handling anywhere (grep over `src/`: 0 hits).
- How the board behaves today:
  - A plain vertical wheel over a column scrolls that column only if it overflows. Over the gaps or headers it does nothing horizontally. **The tester's request is therefore not implemented.**
  - Shift+wheel scrolls horizontally, natively in Chromium, Edge and Firefox on Windows.
  - Trackpad horizontal swipe (deltaX) works natively.
- Gap: add a non-passive `wheel` listener on the board scroller:
  - If `|deltaY| > |deltaX|` and no modifier key is pressed, check whether the event target is inside a column body that can still scroll vertically in that direction. If so, leave the event alone, so a long column still scrolls. Otherwise call `scrollLeft += deltaY` and `preventDefault()`.
  - Leave `deltaX` from trackpads and shift+wheel to the browser.
  - Use `deltaMode` to normalise line-based and pixel-based deltas.
  - Do not touch ctrl+wheel (zoom).
  - Disable the handler during a dnd-kit drag.

### App (Flutter)
- Platforms exist: `web/`, `windows/`, `android/` and `ios/` are all present. There is no custom `ScrollBehavior` (grep for `scrollBehavior|PointerDeviceKind` in `lib/`: 0 hits), so Flutter defaults apply.
- How the board behaves today:
  - A mouse **cannot drag** the horizontal track, because mouse is not in the default `dragDevices`.
  - Shift+wheel scrolls horizontally through `ScrollBehavior.pointerAxisModifiers`.
  - A trackpad pan works.
  - A plain vertical wheel goes to the inner vertical `ListView` of a column (`board_column.dart:182`), not to the track.
  - `BoardSnapPhysics` snaps per column (`plan_board_page.dart:296`). Wheel offsets bypass ballistic snapping, so a wheel scroll can stop between columns. This needs verification on a device.
- Relevance: the app's main target is mobile, where touch swipe already works, so this is low priority. If Flutter web or Windows is shipped, add a `Listener(onPointerSignal:)` on the track that maps vertical `PointerScrollEvent` → `_track` horizontal when over a header or gap, or when the column cannot scroll further. Also consider adding `PointerDeviceKind.mouse` to `dragDevices` for the track.
- No API or capability work is needed.

---

## Permissions and capabilities summary

| Action | API gate | Web gate today | App gate today | Capability |
|---|---|---|---|---|
| Reorder sections | `tasks.write` + `assertCanManage` (owner/manager/`tasks.projects.manage.all`) | `canManage` (`project-board-page.tsx:208`) | `canEditSections` = `roleOf(me).canManagePlan` (`plan_board_page.dart:105-109`) | none |
| Move task to group | `tasks.write` + not viewer + not locked (423) + QC (422) | `canEdit` and `!locked` | `tasks.projects.manage.all` and `!locked` and not viewer (stricter than API) | none |
| Copy task | `tasks.write` + not viewer on target; locked allowed | `canWrite` (uses `POST /tasks`) | `tasks.copy` and `canUpdate` | `tasks.copy` exists; **new key needed** for the extended options |
| Team list | `tasks.read` (`/teams`) | uses org-units (needs `organization.org_units.read`) | `/teams` | none |
| Wheel scroll | — | — | — | none |
