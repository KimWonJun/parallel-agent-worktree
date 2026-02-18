# Worktree 기반 멀티 에이전트 자동화 로드맵 (macOS + GitHub 전용)

샘플 ROADMAP 스타일처럼 모든 실행 항목을 체크박스로 관리한다.

## 1) 참고 레포(`rootsong0220/multi-agent-worktree`) 기능 분석

### 핵심 기능
- [x] Git Worktree 기반 저장소 운영: bare 저장소(`.bare`)를 기준으로 worktree 생성/재사용.
- [x] 대화형 저장소 선택: GitLab API 목록 + `fzf` 선택.
- [x] 초기화/조회 명령(`mawt init`, `mawt list`, `mawt status`) 제공.
- [x] 에이전트 런처(`gemini`, `claude`, `codex`, `shell`) 및 모델 선택 메뉴 제공.
- [x] API 키 확인 및 설정 파일(`~/.mawt/config`) 저장.
- [x] 설치 스크립트와 의존성 점검/경로 설정 자동화.

### 구조적 특징
- [x] 일반 클론 대신 bare 클론 + worktree 추가 구조.
- [x] 기존 일반 Git 저장소를 worktree 구조로 변환하는 로직.
- [x] 설정을 단일 파일(`~/.mawt/config`)에 저장.

## 2) macOS + GitHub 기준 불필요/축소 항목

### 제거 가능
- [x] GitLab 전용 기능(`GITLAB_*`, GitLab API 조회, HTTPS 토큰 주입 로직) 제거 대상 정의.
- [x] Windows/WSL 전용 요소(`install.ps1`, `bin/mawt.ps1`, `/proc/version` 분기) 제거 대상 정의.
- [x] Linux 배포판별 패키지 매니저 분기 단순화 대상 정의.

### 선택적 유지
- [x] `gemini`/`claude` 런처는 옵션화, 기본은 `codex` 중심으로 단순화.
- [x] 자동 npm 글로벌 설치는 정책에 따라 수동 설치 전환 가능하도록 유지.

## 3) 개인화 목표 (현재 기준)

- [x] 플랫폼: macOS only.
- [x] Git 호스팅: GitHub only (organization + personal repo).
- [x] 주요 에이전트: Codex 우선, Gemini/Claude 옵션화.
- [x] 운영 원칙: `<repo>-worktree` 루트에 branch/worktree 1:1 매핑.

## 4) 기존 구현 로드맵

### Phase 0. 설계 고정
- [x] CLI 명세 확정: `wt init`, `wt repo`, `wt branch`, `wt agent`, `wt list`, `wt status`, `wt prune`.
- [x] 디렉토리 규칙 확정: `~/workspace/<repo>/.bare`, `~/workspace/<repo>-worktree/<branch>`.
- [x] 설정 스키마 확정: `WORKSPACE_DIR`, `GITHUB_HOST`, `GIT_PROTOCOL`, `DEFAULT_AGENT`, `DEFAULT_BASE_BRANCH`.
- [x] 완료 기준 정의: 명령/설정/경로 규칙 문서 고정.

### Phase 1. macOS 부트스트랩 (완료: 2026-02-14)
- [x] `install.sh` 작성 및 macOS 의존성 확인(`git`, `gh`, `jq`, `fzf`).
- [x] PATH 설정(`~/.zshrc`) 자동화.
- [x] `gh auth status` 검사 및 미인증 시 로그인 가이드.

### Phase 2. GitHub 저장소 선택/초기화 (1차 완료: 2026-02-14)
- [x] `gh repo list` 기반 저장소 조회 통일.
- [x] `fzf` 기반 저장소 선택 UI.
- [x] `wt init owner/repo` bare 클론 생성/재사용.

### Phase 3. Worktree 수명주기 자동화 (1차 완료: 2026-02-14)
- [x] base branch 선택 + branch명 기본값 규칙(`feat/<slug>`, `fix/<slug>`).
- [x] `wt list`, `wt status`, `wt prune` 구현.
- [x] dirty 경고/중복 branch/경로 충돌 안전장치 추가.

### Phase 4. 에이전트 런처 개인화 (1차 완료: 2026-02-14)
- [x] `wt agent` 기본 `codex` 실행 + `gemini`/`claude` 플러그형 지원.
- [x] repo별 프로필(`~/.wtx/profiles/<repo>.toml`) 구조 도입.
- [x] repo별 기본 에이전트/모델 자동 적용.

### Phase 5. GitHub 협업 자동화
- [ ] 정책 확정: PR base는 "worktree 생성 시점의 원본(base) 브랜치"로 고정.
- [ ] worktree 메타데이터 확장: `source_base_branch` 필드 저장(생성 시 1회 기록, 이후 변경 불가).
- [ ] `wt pr` 설계/구현:
  - [ ] `gh pr create --base <source_base_branch> --head <current_branch>` 강제 사용.
  - [ ] `--base` 사용자 입력값은 무시하거나 에러 처리(정책 위반 방지).
  - [ ] main 브랜치에서 `wt pr` 직접 실행 시 차단 메시지 출력.
- [ ] PR 전 필수 동기화 단계(Pre-PR gate) 구현:
  - [ ] `git fetch origin` 실행.
  - [ ] `git rebase origin/<source_base_branch>` 자동 수행.
  - [ ] rebase 충돌 시 PR 생성 중단 및 해결 안내:
    - [ ] 충돌 파일 목록 표시.
    - [ ] `git add <files>` 후 `git rebase --continue` 안내.
    - [ ] 필요 시 `git rebase --abort` 롤백 안내.
  - [ ] rebase 완료 후에만 `gh pr create` 수행.
- [ ] base 브랜치 선택 정책 강화(worktree 생성 시):
  - [ ] base 후보 목록에서 `main` 제외.
  - [ ] base 후보가 비어 있고 `main`만 존재하면 생성 플로우 전환:
    - [ ] "PR용 base 브랜치가 필요합니다. 새 base 브랜치를 생성하세요." 메시지 출력.
    - [ ] 새 브랜치명 입력/자동 제안(`develop`, `integration/<name>` 등) 제공.
    - [ ] 생성 완료 전까지 worktree 생성 차단.
- [ ] 검증 항목:
  - [ ] 케이스 A: `feature/x`가 `develop`에서 분기된 경우 PR base가 항상 `develop`으로 생성됨.
  - [ ] 케이스 B: base 업데이트 후 Pre-PR rebase가 성공하면 PR 생성됨.
  - [ ] 케이스 C: rebase 충돌 시 PR가 생성되지 않고 해결 후 재시도 가능.
  - [ ] 케이스 D: repo에 `main`만 있을 때 base 생성 안내가 노출되고 worktree 생성이 차단됨.
- [ ] 케이스 E: main에서 직접 PR 시도 시 정책 위반 메시지로 차단됨.
- [ ] 완료 기준: 모든 PR이 source base 브랜치로만 생성되고, rebase gate를 통과한 경우에만 PR 생성됨.

### Phase 5 구현 이슈 분해 (Execution Issues)

#### P5-01. Worktree 메타데이터에 `source_base_branch` 영구 저장
- [ ] 목적: PR 대상 base를 worktree 생성 시점 기준으로 고정한다.
- [ ] 작업 범위:
  - [ ] worktree 생성 로직에서 선택된 base 브랜치를 메타데이터에 저장.
  - [ ] `wt list`/`wt status --json`에 `source_base_branch` 노출.
  - [ ] 기존 worktree(필드 없음) 마이그레이션 처리(없으면 현재 추론 규칙 적용 후 저장).
- [ ] AC:
  - [ ] 신규 worktree는 항상 `source_base_branch`를 가진다.
  - [ ] 동일 worktree 재실행 시 값이 변경되지 않는다.
- [ ] 의존성: 없음.

#### P5-02. Base 브랜치 선택 정책(main 제외) + 예외 UX
- [ ] 목적: worktree 생성 시 base 후보에서 `main`을 제외한다.
- [ ] 작업 범위:
  - [ ] base 후보 조회 시 `main` 필터링.
  - [ ] 후보가 없고 `main`만 존재하면 생성 플로우로 전환.
  - [ ] 안내 메시지/입력 UX 추가: "PR용 base 브랜치를 생성해야 합니다."
  - [ ] 제안 브랜치명 템플릿 제공(`develop`, `integration/<name>`).
- [ ] AC:
  - [ ] base 선택 UI에 `main`이 보이지 않는다.
  - [ ] `main` only repo에서 worktree 생성이 차단되고 base 생성 안내가 뜬다.
- [ ] 의존성: 없음.

#### P5-03. `wt pr` 명령 추가 및 PR base 강제
- [ ] 목적: 모든 PR이 `source_base_branch`를 대상으로 생성되도록 강제한다.
- [ ] 작업 범위:
  - [ ] `wt pr` 명령 추가.
  - [ ] 내부 호출을 `gh pr create --base <source_base_branch> --head <current_branch>`로 고정.
  - [ ] 사용자 `--base` 입력 시 에러 처리(정책 위반).
  - [ ] main 브랜치에서 실행 시 차단.
- [ ] AC:
  - [ ] 사용자가 다른 base를 넣어도 정책 위반으로 실패한다.
  - [ ] 생성된 PR의 base가 항상 `source_base_branch`와 일치한다.
- [ ] 의존성: P5-01.

#### P5-04. Pre-PR Rebase Gate (`fetch + rebase`) 구현
- [ ] 목적: PR 전 base 최신화를 강제한다.
- [ ] 작업 범위:
  - [ ] `wt pr` 실행 전 `git fetch origin` 수행.
  - [ ] `git rebase origin/<source_base_branch>` 자동 수행.
  - [ ] rebase 진행/성공/실패 상태 출력.
- [ ] AC:
  - [ ] rebase 성공한 경우에만 PR 생성 단계로 이동한다.
  - [ ] rebase 실패 시 PR 생성이 중단된다.
- [ ] 의존성: P5-01, P5-03.

#### P5-05. Rebase Conflict 처리 UX + 복구 가이드
- [ ] 목적: 충돌 시 사용자가 즉시 복구 가능한 안내를 제공한다.
- [ ] 작업 범위:
  - [ ] 충돌 파일 목록 출력(`git diff --name-only --diff-filter=U`).
  - [ ] 해결 절차 안내: `git add ...` → `git rebase --continue`.
  - [ ] 롤백 절차 안내: `git rebase --abort`.
  - [ ] 해결 후 `wt pr` 재시도 경로 안내.
- [ ] AC:
  - [ ] 충돌 발생 시 사용자에게 다음 액션이 명확히 출력된다.
  - [ ] 충돌 미해결 상태에서 PR 생성이 차단된다.
- [ ] 의존성: P5-04.

#### P5-06. 정책/명령 테스트(E2E + 회귀) 추가
- [ ] 목적: Phase 5 정책 회귀를 방지한다.
- [ ] 작업 범위:
  - [ ] E2E: base 고정 PR, rebase gate 성공, rebase conflict 차단.
  - [ ] E2E: `main` only repo에서 base 생성 유도.
  - [ ] 단위/통합: `source_base_branch` 저장/조회, `--base` 차단.
- [ ] AC:
  - [ ] 케이스 A~E가 자동 테스트 또는 재현 스크립트로 검증된다.
  - [ ] CI에서 Phase 5 핵심 정책 테스트가 통과한다.
- [ ] 의존성: P5-01, P5-02, P5-03, P5-04, P5-05.

### Phase 6. 검증/문서화
- [ ] 테스트 시나리오 정리: 신규 설치, 기존 repo 전환, private repo, 실패 복구.
- [ ] 운영 문서 정리: 빠른 시작, 트러블슈팅, 팀 규칙.
- [ ] 완료 기준: 재설치/재현 가능한 문서 기반 온보딩 완료.

## 5) 신규 로드맵: 병렬 처리 + 에이전트 실행상태 웹 관제

### Phase 7. 병렬 실행 오케스트레이터
- [ ] 실행 단위 정의: `1 Agent Run = 1 Branch = 1 Worktree`.
- [ ] 동시성 제어(`max_parallel_runs`)와 대기 큐(`QUEUED`) 구현.
- [ ] 취소/타임아웃/재시도 정책 구현.
- [ ] 실행 상태 머신 정의 및 적용:
  - [ ] `QUEUED`
  - [ ] `PREPARING_WORKTREE`
  - [ ] `STARTING`
  - [ ] `RUNNING`
  - [ ] `WAITING_APPROVAL` (provider 지원 시)
  - [ ] `SUCCEEDED` / `FAILED` / `CANCELED` / `TIMEOUT`

### Phase 8. Provider Adapter (Claude/Codex/Gemini)
- [ ] 공통 이벤트 인터페이스 정의: `RunStarted`, `TurnStarted`, `ToolStarted`, `ToolCompleted`, `TurnCompleted`, `Error`.
- [ ] Claude Adapter: Hooks 이벤트 수집 및 표준 이벤트로 변환.
- [ ] Codex Adapter(1차): `codex exec --json` 스트림 파싱.
- [ ] Codex Adapter(고급): `codex app-server` notifications 연동.
- [ ] Gemini Adapter: Hooks + `--output-format stream-json` 이벤트 연동.
- [ ] Provider별 기능 편차 대응:
  - [ ] 훅 미지원/제한 기능은 `degraded mode`로 표시.
  - [ ] 수집 불가 상태는 `UNKNOWN` 대신 근거 기반 추정 상태로만 표시.

### Phase 9. 이벤트 저장소/실시간 전송
- [ ] 이벤트 스키마 정의: `event_id`, `run_id`, `agent_id`, `provider`, `event_type`, `ts`, `payload`.
- [ ] Run/Agent/Worktree/Artifact 테이블 설계.
- [ ] 로그 redaction(토큰/비밀값 마스킹) 파이프라인 추가.
- [ ] WebSocket 또는 SSE 기반 실시간 스트림 API 제공.

### Phase 10. 웹 대시보드 (실행상태 관제)
- [ ] 에이전트 목록 화면: provider, branch, worktree, 현재 상태, 경과시간.
- [ ] 실행 상세 화면: 타임라인 이벤트, stdout/stderr, 실패 원인.
- [ ] 제어 액션: `Cancel`, `Retry`, `Open Worktree`.
- [ ] 필터/검색: 상태, provider, repo, branch 기준.
- [ ] UX 규칙:
  - [ ] 최신 이벤트 자동 스크롤 옵션.
  - [ ] 실패/타임아웃 강조 색상.
  - [ ] 장시간 무응답(run heartbeat 없음) 경고.

### Phase 11. 병합/품질 게이트
- [ ] run 성공 후 병합 전 pre-merge 체크(`test`, `lint`, `typecheck`) 훅.
- [ ] 충돌 감지 시 자동 중단 + UI에 충돌 파일 표시.
- [ ] 통합 정책: FF merge 우선, 필요 시 squash 전략 옵션화.

### Phase 12. E2E/운영 준비
- [ ] 시나리오 테스트: 3개 이상 에이전트 동시 실행, 1개 실패, 1개 취소.
- [ ] 장애 복구 테스트: provider 프로세스 종료/네트워크 오류 재시도.
- [ ] 운영 지표: 성공률, 평균 실행시간, 재시도율, timeout 비율.
- [ ] 문서화: 관리자 가이드, 장애 대응 Runbook, 보안 정책.

## 6) MVP 우선순위

- [ ] P0: Phase 7 + Phase 8(Claude/Codex/Gemini 기본 어댑터) + Phase 9 일부.
- [ ] P1: Phase 10(웹 대시보드 기본 관제) + 취소/재시도.
- [ ] P2: Phase 11(병합 게이트) + Phase 12(E2E/운영 지표).

## 7) 리스크와 대응

- [ ] `gh` 인증/권한 이슈: 시작 시 `gh auth status` 강제 체크.
- [ ] 브랜치/경로 네이밍 충돌: suffix 자동 부여 + 사용자 확인.
- [ ] provider별 상태 이벤트 편차: 표준 이벤트 스키마 + `degraded mode` 명시.
- [ ] 기존 repo 전환 시 데이터 손상 위험: 백업 디렉토리 + 롤백 스크립트 유지.

## 8) 다음 실행 항목 (즉시 착수)

- [ ] `wt status --json` 스키마를 병렬 실행 상태 모델에 맞춰 확장.
- [ ] `RunState`/`AgentRun` DB 초안 생성(SQLite 또는 Postgres 중 택1).
- [ ] Codex/Gemini/Claude 최소 이벤트 수집 PoC 스크립트 작성.
- [ ] 대시보드 v0 와이어프레임(목록/상세/실패 케이스) 확정.
