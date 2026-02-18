# wt (Worktree Automation CLI)

`wt`는 macOS + GitHub 환경에서 Git Worktree 기반 병렬 작업을 빠르게 만들고, 에이전트(Codex/Gemini/Claude/Shell) 실행까지 이어주는 CLI입니다.

## 주요 기능
- GitHub 저장소 선택 및 초기화 (`wt init`, `wt repo`)
- Bare 저장소 기반 worktree 운영 (`<workspace>/<repo>/.bare`)
- 브랜치 생성 + worktree 생성 (`wt branch`)
- worktree 상태 조회/정리 (`wt status`, `wt prune`)
- 에이전트 실행 (`wt agent`), 기본 우선순위 `codex`
- `wt init` 실행 시: `repo 선택 -> branch 생성 -> 해당 worktree에서 agent 실행` 자동 연계
- worktree 시작 컨텍스트 자동 주입:
  - `repo.toml`
  - `mcp-usage-guidelines.md`

## 디렉토리 구조
기본 `WORKSPACE_DIR=~/workspace` 기준:

- Bare 저장소: `~/workspace/<repo>/.bare`
- Worktree: `~/workspace/<repo>/<branch-dir>`

`branch-dir`는 브랜치명에서 안전하지 않은 문자를 `-`로 치환해 생성합니다.

예:
- `feat/new-api` -> `feat-new-api`
- `fix: login issue` -> `fix-login-issue`

## 설치 (macOS)
아래 명령으로 설치/업데이트할 수 있습니다.

```bash
curl -fsSL https://raw.githubusercontent.com/KimWonJun/parallel-agent-worktree/main/install.sh | bash
```

설치 스크립트가 수행하는 작업:
- 의존성 확인/설치: `curl`, `git`, `gh`, `jq`, `fzf`
- 바이너리 설치: `~/.wt/bin/wt`
- 템플릿 설치: `~/.wt/templates/{repo.toml,mcp-usage-guidelines.md}`
- 설정 파일 생성/보강: `~/.wt/config`
- `~/.zshrc`에 PATH 추가
- GitHub 인증 방식 선택 (로그인/토큰/스킵)

설치 후:

```bash
source ~/.zshrc
wt --help
```

## 초기 설정 항목
`~/.wt/config`에 관리됩니다.

- `WORKSPACE_DIR` (기본: `~/workspace`)
- `GITHUB_HOST` (기본: `github.com`)
- `GIT_PROTOCOL` (`ssh`/`https`)
- `DEFAULT_AGENT` (기본: `codex`)
- `DEFAULT_GITHUB_OWNER` (자동 감지)
- `REPOSITORY_LIST` (선택)

`REPOSITORY_LIST` 예시:
```bash
REPOSITORY_LIST="KimWonJun/repo-a,KimWonJun/repo-b,org/repo-c"
```

설정하면 `wt init` 시 해당 목록에서 우선 선택합니다.

## 명령어

### 1) 저장소 초기화 + 브랜치 + 에이전트 실행
```bash
wt init
```
또는
```bash
wt init owner/repo
wt init owner
```

### 2) 저장소 선택만 / 선택 후 초기화
```bash
wt repo
wt repo owner
wt repo --init
wt repo owner --init
```

### 3) 브랜치(worktree) 생성
```bash
wt branch
wt branch <repo>
wt branch <repo> <new-branch>
wt branch <repo> <new-branch> <base-branch>
```

base branch 선택 시 `origin` 항목은 제외됩니다.

### 4) 상태/정리
```bash
wt status
wt status <repo>
wt prune
wt prune <repo>
```

### 5) 에이전트 실행
```bash
wt agent
wt agent codex
wt agent codex /absolute/path/to/worktree
```

## 에이전트 기동 시 초기 컨텍스트
worktree에서 agent를 시작할 때 아래 내용을 초기 프롬프트로 전달합니다.

1. `./repo.toml` 확인
2. `./mcp-usage-guidelines.md` 준수
3. 현재 worktree 경로에서 작업 진행

`repo.toml`의 `[project].name`은 worktree 생성 시 실제 repo 이름으로 자동 반영됩니다.

## 문제 해결

### `gh` 인증 오류
```bash
gh auth login -h github.com
wt auth-check
```

### 기존 설치 업데이트
동일 설치 명령을 다시 실행하면 업데이트됩니다.

```bash
curl -fsSL https://raw.githubusercontent.com/KimWonJun/parallel-agent-worktree/main/install.sh | bash
```

기존 `~/.wt/config` 값은 유지되며, 없는 항목만 보강됩니다.
