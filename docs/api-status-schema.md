# `wt status --json` / `wt list --json` 스키마

이 문서는 `wt` CLI의 상태 조회 JSON 출력 형식을 고정합니다.

- 대상 명령:
  - `wt status --json`
  - `wt status <repo> --json`
  - `wt list --json` (`wt status --json`과 동일 출력)

## 스키마 (v1)

```json
{
  "workspace": "string",
  "repositories": [
    {
      "repo": "string",
      "worktrees": [
        {
          "path": "string",
          "branch": "string",
          "source_base_branch": "string|null",
          "locked": "string|null",
          "prunable": "string|null"
        }
      ]
    }
  ]
}
```

## 필드 정의

- `workspace`:
  - 작업 루트 디렉터리 절대 경로
  - 예: `/Users/<user>/workspace`

- `repositories[]`:
  - 초기화된 저장소 목록

- `repositories[].repo`:
  - 저장소 이름 (`owner/repo`가 아닌 로컬 디렉터리명)

- `repositories[].worktrees[]`:
  - 각 저장소의 연결된 worktree 목록
  - bare worktree(`.bare`)는 출력에서 제외

- `worktrees[].path`:
  - worktree 경로 (절대 경로)

- `worktrees[].branch`:
  - 현재 worktree 브랜치명
  - detached 상태면 `(detached)`

- `worktrees[].source_base_branch`:
  - Phase 5 정책에서 저장되는 원본 base 브랜치
  - 값이 없으면 `null`

- `worktrees[].locked`:
  - `git worktree list --porcelain`의 locked 정보
  - 없으면 `null`

- `worktrees[].prunable`:
  - `git worktree list --porcelain`의 prunable 정보
  - 없으면 `null`

## 예시

```json
{
  "workspace": "/Users/kimwonjun/workspace",
  "repositories": [
    {
      "repo": "parallel-agent-worktree",
      "worktrees": [
        {
          "path": "/Users/kimwonjun/workspace/parallel-agent-worktree/test-pr-test-branch",
          "branch": "test/pr-test-branch",
          "source_base_branch": "develop",
          "locked": null,
          "prunable": null
        }
      ]
    }
  ]
}
```

## 호환성 규칙

- 신규 필드 추가는 가능하지만 기존 필드 이름/타입은 유지합니다.
- 하위 호환이 깨지는 변경이 필요하면 `v2` 문서를 별도로 추가합니다.
