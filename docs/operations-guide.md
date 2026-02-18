# 운영 가이드 (빠른 시작 / 트러블슈팅 / 팀 규칙)

## 1) 빠른 시작

### 설치

```bash
curl -fsSL https://raw.githubusercontent.com/KimWonJun/parallel-agent-worktree/main/install.sh | bash
source ~/.zshrc
wt --help
```

### 최초 인증

```bash
gh auth login -h github.com
wt auth-check
```

### 기본 작업 흐름

1. 저장소 초기화: `wt init <owner/repo>`
2. 작업 브랜치 생성: `wt branch <repo> <new-branch> <base-branch>`
3. 작업 후 커밋
4. PR 생성: `wt pr <worktree-path>`

## 2) 트러블슈팅

### 문제: `gh auth` 오류

증상:
- `GitHub auth is not configured ...`

해결:
```bash
gh auth login -h github.com
wt auth-check
```

### 문제: `main` base 선택/입력

증상:
- `base branch 'main' is not allowed ...`

해결:
- non-main base 사용 (`develop`, `integration/*`)
- `main` only repo인 경우 안내에 따라 새 base 생성

### 문제: `wt pr`가 실패함

체크 순서:
1. 현재 worktree clean 상태 확인:
   - `git status --short`
2. 올바른 경로로 실행했는지 확인:
   - 현재 폴더면 `wt pr`
   - 명시할 땐 절대경로 `wt pr "$(pwd)"`
3. 메타데이터 확인:
   - `cat .wt/metadata`
4. 원격 base 확인:
   - `git fetch origin --prune`
   - `git branch -r`

### 문제: rebase 충돌

해결:
```bash
git add <resolved-files>
git rebase --continue
# 또는 롤백
git rebase --abort
```

완료 후:
```bash
wt pr "$(pwd)"
```

### 문제: 설치 후 구버전 실행됨

체크:
```bash
which wt
wt --help
```

해결:
- `~/.wt/bin`이 PATH 앞쪽에 있는지 확인
- 설치 스크립트 재실행 후 새 터미널 오픈

## 3) 팀 규칙

### 브랜치/PR 정책

- feature/fix 작업은 non-main base에서 분기
- `main` 직접 작업 및 PR 금지
- `wt pr`로만 PR 생성 (base/head 강제 + pre-rebase gate)

### 커밋 정책

- 한 브랜치는 하나의 목적/변경 묶음으로 유지
- 커밋 메시지는 변경 의도를 명확히 표현
- 자동 생성 파일/불필요 로그 커밋 금지

### 충돌 대응 규칙

- 충돌 해결은 작업자 책임으로 즉시 처리
- 충돌 해결 시 문맥을 보존하고 임의 삭제 금지
- 필요 시 `rebase --abort` 후 재정렬

### 운영 규칙

- 설치/업데이트는 공식 스크립트 경로만 사용
- 문제 발생 시 먼저 `wt status --json`으로 상태 수집
- 재현 가능한 명령/로그를 이슈에 남긴 뒤 대응
