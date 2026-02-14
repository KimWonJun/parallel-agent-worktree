# Worktree 기반 멀티 에이전트 자동화 로드맵 (macOS + GitHub 전용)

## 1) 참고 레포(`rootsong0220/multi-agent-worktree`) 기능 분석

### 핵심 기능
- Git Worktree 기반 저장소 운영: bare 저장소(`.bare`)를 기준으로 worktree를 생성/재사용.
- 대화형 저장소 선택: GitLab API로 프로젝트 목록을 받아 `fzf`로 선택.
- 초기화/조회 명령:
  - `mawt init <group/project>`: 저장소 초기화(클론/준비).
  - `mawt list`: 관리 중 저장소/브랜치 출력.
  - `mawt status`: worktree 상태 출력.
  - 기본 실행: 저장소 선택 → worktree 선택/생성 → 에이전트 실행.
- 에이전트 런처:
  - `gemini`, `claude`, `codex`, `shell` 중 선택.
  - 모델 선택 메뉴 제공.
  - API 키 확인 및 설정 파일(`~/.mawt/config`) 저장.
- 설치/운영:
  - `install.sh`(Linux/macOS), `install.ps1`(Windows).
  - 의존성 점검(`git`, `curl`, `jq`, `fzf`, `npm` 등)과 PATH 설정 자동화.

### 구조적 특징
- 저장소를 일반 클론 대신 bare 클론 후 worktree 추가.
- 기존 일반 Git 저장소를 worktree 구조로 변환하는 로직 포함.
- 설정은 `~/.mawt/config` 단일 파일에 저장.

## 2) macOS + GitHub 기준 불필요/축소 가능 항목

### 제거 가능
- GitLab 전용 기능 전반:
  - `GITLAB_BASE_URL`, `GITLAB_TOKEN`, GitLab API(`/api/v4/projects`) 조회.
  - HTTPS URL에 GitLab 토큰 주입 로직.
- Windows/WSL 전용 요소:
  - `install.ps1`, `bin/mawt.ps1`, `wslview`/`/proc/version` 기반 분기.
- 과도한 범용 설치 분기:
  - Linux 배포판별 패키지 매니저 분기(apt/dnf/yum/pacman).

### 선택적 유지
- `gemini`/`claude` 런처: 실제 사용하지 않으면 제거하고 `codex` 중심으로 단순화.
- 자동 npm 글로벌 설치: 팀/개인 환경 정책에 따라 수동 설치 방식으로 전환 가능.

## 3) 개인화 목표 정의 (이번 구현의 기준)

- 플랫폼: macOS only.
- Git 호스팅: GitHub only (organization + personal repo).
- 주요 에이전트: Codex 우선, 필요 시 Gemini/Claude 옵션화.
- 운영 방식:
  - 원본 repo 보존.
  - `<repo>-worktree` 루트에만 worktree 생성.
  - 기능/이슈 단위 branch + worktree를 1:1 매핑.

## 4) 구현 로드맵

## Phase 0. 설계 고정
- CLI 명세 확정:
  - `wt init`, `wt repo`, `wt branch`, `wt agent`, `wt list`, `wt status`, `wt prune`.
- 디렉토리 규칙 확정:
  - `~/workspace/<repo>/.bare`
  - `~/workspace/<repo>-worktree/<branch>`
- 설정 파일 스키마 확정(`~/.wtx/config` 등):
  - `WORKSPACE_DIR`, `GITHUB_HOST`, `GIT_PROTOCOL`, `DEFAULT_AGENT`, `DEFAULT_BASE_BRANCH`.
- 완료 기준:
  - 명령/설정/경로 규칙이 문서로 고정되어 이후 구현 중 변경 없음.

## Phase 1. macOS 부트스트랩
- 상태: ✅ 구현 완료 (2026-02-14)
- `install.sh` 작성:
  - macOS 전용 의존성 확인(`git`, `gh`, `jq`, `fzf`).
  - PATH 설정(`~/.zshrc`) 자동화.
- `gh auth status` 검사 및 미인증 시 로그인 가이드.
- 완료 기준:
  - 신규 맥에서 1회 설치 후 `wt --help` 실행 가능.

## Phase 2. GitHub 저장소 선택/초기화
- 상태: ✅ 1차 구현 완료 (2026-02-14)
- GitHub API는 `gh` CLI로 통일:
  - `gh repo list <owner> --json nameWithOwner,sshUrl,url,isPrivate`.
- `fzf` 기반 저장소 선택 UI.
- `wt init owner/repo` 구현:
  - bare 클론 생성 또는 기존 bare 재사용.
- 완료 기준:
  - 최소 1개 public + 1개 private repo 초기화 성공.

## Phase 3. Worktree 수명주기 자동화
- 상태: ✅ 1차 구현 완료 (2026-02-14)
- worktree 생성/재사용:
  - base branch 선택(`main`/`develop`/직접입력).
  - branch명 기본값 규칙(`feat/<slug>`, `fix/<slug>`).
- 상태/정리:
  - `wt list`, `wt status`, `wt prune` 구현.
- 안전장치:
  - dirty 상태 경고, 중복 branch/경로 충돌 처리.
- 완료 기준:
  - 동시에 3개 이상의 worktree를 안정적으로 생성/전환 가능.

## Phase 4. 에이전트 런처 개인화
- `wt agent` 구현:
  - 기본 `codex` 실행.
  - 선택적으로 `gemini`, `claude` 플러그형 지원.
- 개인화 프로필:
  - 프로젝트별 기본 모델/명령 템플릿(`~/.wtx/profiles/<repo>.toml`).
  - 예: "backend repo는 codex model A", "frontend repo는 model B".
- 완료 기준:
  - repo별 기본 에이전트/모델이 자동 적용.

## Phase 5. GitHub 협업 자동화
- branch push + PR 생성 흐름:
  - `gh pr create` 래핑.
- 표준 브랜치 보호 전제 하에 충돌 최소 정책:
  - main 직접 커밋 금지 경고.
- 완료 기준:
  - worktree에서 작업 후 PR 생성까지 단일 흐름으로 동작.

## Phase 6. 검증/문서화
- 테스트 시나리오:
  - 신규 설치, 기존 repo 전환, private repo, 실패 복구.
- 운영 문서:
  - 빠른 시작, 트러블슈팅, 팀 규칙.
- 완료 기준:
  - 재설치/재현 가능한 문서 기반 온보딩 완료.

## 5) 우선순위 (MVP)

1. Phase 1~3 먼저 구현 (설치 + GitHub repo 선택 + worktree 자동화).
2. 그다음 Phase 4 (에이전트 개인화).
3. 마지막으로 Phase 5~6 (PR 자동화 + 문서/검증).

## 6) 리스크와 대응

- `gh` 인증/권한 이슈:
  - 대응: 시작 단계에서 `gh auth status` 강제 체크.
- 브랜치/경로 네이밍 충돌:
  - 대응: 충돌 시 suffix 자동 부여 + 사용자 확인.
- 기존 일반 repo 전환 중 데이터 손상 위험:
  - 대응: 변환 전 백업 디렉토리 생성 + 롤백 스크립트 제공.

## 7) 다음 실행 항목

1. `wt branch`에 브랜치 네이밍 템플릿(`feat/`, `fix/`) 자동 제안 기능 추가.
2. `wt status` 출력을 머신 파싱 가능한 옵션(`--json`)으로 확장.
3. `wt prune`에 dry-run 옵션 추가.
4. public/private GitHub repo 각각으로 E2E 검증 및 실패 복구 시나리오 점검.
