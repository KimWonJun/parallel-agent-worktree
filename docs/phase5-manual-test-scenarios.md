# Phase 5 수동 테스트 시나리오

아래 시나리오는 `wt`의 Phase 5 정책(고정 base PR, pre-PR rebase, main 제외)을 직접 확인하기 위한 절차입니다.

## 사전 조건

- `git`, `gh`, `jq`, `fzf` 설치
- GitHub 로그인 완료: `gh auth status`
- 테스트용 저장소 1개 이상 준비
- 기본 작업 경로 확인: `echo $WORKSPACE_DIR` (없으면 `~/workspace`)

## 시나리오 1: worktree base에서 `main` 제외 확인

1. `wt branch <repo>`
2. base 선택 목록에서 `main`이 노출되지 않는지 확인

예상 결과:
- `main`이 base 선택 후보에 나타나지 않음

## 시나리오 2: `main` only 저장소에서 base 생성 유도 확인

1. `main` 브랜치만 있는 저장소를 준비
2. `wt branch <repo>` 실행
3. 안내 메시지에서 새 base 브랜치명(예: `develop`) 입력

예상 결과:
- "PR용 base 브랜치를 생성..." 안내 메시지 노출
- 입력한 base 브랜치가 생성되고 해당 base로 worktree 생성 진행

## 시나리오 3: `source_base_branch` 저장/조회 확인

1. `wt branch <repo> feat/p5-check develop` 실행
2. 생성된 worktree 경로에서 `.wt/metadata` 확인
   - `cat <worktree>/.wt/metadata`
3. `wt status <repo>` 실행
4. `wt status <repo> --json` 실행

예상 결과:
- `.wt/metadata`에 `source_base_branch=develop` 존재
- `wt status` 출력에 `source_base_branch: develop` 표시
- `wt status --json`에서 `worktrees[].source_base_branch == "develop"`

## 시나리오 4: `wt pr`의 base/head 강제 확인

1. feature worktree에서 변경 커밋 1개 생성
2. `wt pr --base develop <worktree-path>` 실행
3. `wt pr <worktree-path>` 실행
4. 생성된 PR의 base/head 확인

예상 결과:
- 2단계에서 `--base` 차단 에러 출력
- 3단계에서 PR 생성 시 base는 `source_base_branch`, head는 현재 branch로 고정

## 시나리오 5: main 브랜치에서 PR 차단 확인

1. `main` worktree(또는 main checkout 상태)에서 `wt pr` 실행

예상 결과:
- `main branch is excluded from 'wt pr'` 에러로 중단

## 시나리오 6: pre-PR rebase 성공 경로 확인

1. `develop` 기반 feature branch 생성 후 커밋
2. 원격 `develop`에 충돌 없는 추가 커밋 반영
3. feature worktree에서 `wt pr` 실행

예상 결과:
- `fetch + rebase` 단계 통과 후 PR 생성

## 시나리오 7: rebase conflict 차단/가이드 확인

1. base 브랜치와 feature 브랜치에서 동일 파일 동일 라인 충돌 커밋 준비
2. feature worktree에서 `wt pr` 실행

예상 결과:
- PR 생성 중단
- 충돌 파일 목록 출력
- `git add ...`, `git rebase --continue`, `git rebase --abort` 안내 출력

## 시나리오 8: list JSON/텍스트 가시성 확인

1. `wt list` 실행
2. `wt list --json` 실행

예상 결과:
- 텍스트 출력에서 각 worktree의 `source_base`가 보임
- JSON 출력에서 `repositories[].worktrees[].source_base_branch` 확인 가능

## 빠른 자동 검증 (로컬)

아래 스크립트는 로컬 임시 저장소를 만들어 Phase 5 핵심 정책을 자동 검증합니다.

```bash
bash scripts/phase5_e2e.sh
```

예상 결과:
- 마지막 줄에 `Phase 5 E2E checks passed.` 출력
