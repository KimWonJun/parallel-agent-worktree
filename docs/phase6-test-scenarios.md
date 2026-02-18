# Phase 6 테스트 시나리오 (검증/문서화)

이 문서는 Phase 6 완료 기준인 아래 항목을 검증하기 위한 수동 테스트 절차를 제공합니다.

- 신규 설치
- 기존 repo 전환
- private repo
- 실패 복구
- 재설치/재현 가능한 온보딩

## 공통 사전 조건

- macOS
- `git`, `gh`, `jq`, `fzf`, `curl`
- GitHub 인증 완료: `gh auth status -h github.com`
- `WT_WORKSPACE` 예시: `~/workspace`

## 시나리오 A: 신규 설치 온보딩

1. 기존 설치 제거(선택):
   - `rm -rf ~/.wt`
2. 설치:
   - `curl -fsSL https://raw.githubusercontent.com/KimWonJun/parallel-agent-worktree/main/install.sh | bash`
3. 셸 반영:
   - `source ~/.zshrc`
4. 확인:
   - `which wt`
   - `wt --help`
   - `wt auth-check`

예상 결과:
- `wt`가 `~/.wt/bin/wt`로 설치됨
- `wt --help` 정상 출력
- `wt auth-check` 통과

## 시나리오 B: 기존 repo에서 worktree 전환

1. repo 선택 또는 초기화:
   - `wt repo <owner> --init` 또는 `wt init <owner/repo>`
2. branch/worktree 생성:
   - `wt branch <repo> test/phase6-migrate <non-main-base>`
3. 상태 확인:
   - `wt status <repo>`
   - `wt status <repo> --json | jq`

예상 결과:
- `<workspace>/<repo>/.bare` 존재
- `<workspace>/<repo>/<branch-dir>` worktree 생성
- `source_base_branch` 메타데이터 표시

## 시나리오 C: private repo 초기화/작업

1. private repo 대상 실행:
   - `wt init <owner/private-repo>`
2. branch 생성:
   - `wt branch <private-repo> test/private-flow <non-main-base>`
3. 상태 확인:
   - `wt status <private-repo>`

예상 결과:
- private repo도 동일하게 초기화/branch/worktree 생성 가능
- 권한 문제 없으면 일반 repo와 동일 UX

실패 시 확인:
- `gh auth status -h github.com`
- `gh repo view <owner/private-repo>`

## 시나리오 D: 실패 복구 (대표 케이스)

### D-1. 인증 실패

1. `gh auth logout` 또는 토큰 만료 상태 재현
2. `wt init <owner/repo>` 실행

예상 결과:
- 인증 에러 및 `gh auth login -h github.com` 안내

복구:
- `gh auth login -h github.com`
- 동일 명령 재시도

### D-2. base 정책 위반 (`main`)

1. `wt branch <repo> test/main-block main` 실행

예상 결과:
- `main` base 차단 메시지 출력

복구:
- non-main base로 재시도

### D-3. PR 전 rebase 충돌

1. 동일 파일 충돌 상황 생성
2. `wt pr <worktree-path>` 실행

예상 결과:
- PR 생성 중단
- 충돌 파일 목록 + `rebase --continue`/`--abort` 안내

복구:
- 충돌 해결 후 `git rebase --continue`
- 다시 `wt pr`

## 시나리오 E: 재설치/재현성

1. 같은 설치 명령 재실행:
   - `curl -fsSL https://raw.githubusercontent.com/KimWonJun/parallel-agent-worktree/main/install.sh | bash`
2. 기존 설정 유지 확인:
   - `cat ~/.wt/config`
3. 기능 확인:
   - `wt status --json`
   - `wt list --json | jq`

예상 결과:
- 기존 `~/.wt/config` 값 유지
- 누락 항목만 보강
- 명령 동작 동일

## 빠른 자동 검증

```bash
bash scripts/phase5_e2e.sh
```

예상 결과:
- `Phase 5 E2E checks passed.`
