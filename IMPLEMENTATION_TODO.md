# AI Attendance System - Execution TODO

Stack:
- Frontend: Flutter
- Backend: FastAPI (Python)
- Database: PostgreSQL

## Current Project Status (already present)
- [x] PostgreSQL connection configured (`backend/app/database.py`)
- [x] Student model exists as `users` with stored face encoding (`backend/app/models.py`)
- [x] Attendance table/model exists (`backend/app/models.py`)
- [x] Student registration endpoint with embedding JSON serialization (`/register/` in `backend/app/main.py`)
- [x] Face match + attendance mark endpoint exists (`/attendance/mark` in `backend/app/main.py`)
- [x] Today's attendance endpoint exists (`/attendance/today` in `backend/app/main.py`)

## Phase 1: DB hardening
- [ ] Add `email` to `users` (unique)
- [ ] Add unique constraint on attendance (`user_id`, `date`) to guarantee no duplicate marking
- [ ] Add migration setup (Alembic) instead of relying only on `create_all`

## Phase 2: Face recognition reliability
- [ ] Handle multi-face images explicitly (reject or pick best)
- [ ] Add clear error messages for no-face / low-confidence / unknown face
- [ ] Store numeric encoding in a robust column type strategy (keep JSON text or move to JSONB with migration)

## Phase 3: Recognition API for admin stream
- [ ] Add `/recognize` endpoint (identify only, no attendance write)
- [ ] Return confidence score and recognized student payload
- [ ] Keep `/attendance/mark` for final attendance write flow

## Phase 4: Attendance write safety
- [ ] Move duplicate protection to DB-level + API-level
- [ ] Return deterministic API statuses (`marked`, `already_marked`, `unknown_face`, `no_face`)

## Phase 5: Flutter Admin module
- [ ] Admin login screen / role gate
- [ ] Admin camera preview page
- [ ] Capture every 2-3 sec and call `/recognize`
- [ ] Show detected student cards + confidence
- [ ] Trigger `/attendance/mark` once per recognized student

## Phase 6: Flutter Student module
- [ ] Add `/attendance/{student_id}` backend endpoint
- [ ] Build student attendance history UI
- [ ] Add summary widgets (present days, streak, latest mark)

## Phase 7: Networking and deployment
- [ ] Set `API_BASE_URL` via env for device/emulator
- [ ] Verify backend is reachable from physical device on LAN
- [ ] Add timeout/retry and user-friendly error banners in Flutter

## Phase 8: Performance + edge cases
- [ ] Compress/resize image before upload from Flutter
- [ ] Process at interval (not continuous frame flood)
- [ ] Handle unknown face, multiple faces, low lighting, and backend down cases

## Priority order (next 5 tasks)
1. Add DB unique constraint for daily attendance duplicate prevention
2. Build `/recognize` endpoint (recognize only)
3. Add `/attendance/{student_id}` endpoint
4. Build Flutter admin camera polling integration
5. Build Flutter student attendance history screen
