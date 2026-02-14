## AI Model Selection & Reasoning Specs

이 프로젝트의 각 모듈 작업 시 에이전트는 아래 설정값을 참조하여 동작 모드를 결정한다.

| Module | Target Model | Reasoning Effort |
| :--- | :--- | :--- |
| **신규 기능 개발, 리팩토링** | `GPT-5.3-Codex` | `Medium` (Default) |
| **Data Pipeline (Flink/Spark)** | `GPT-5.3-Codex` | `High` |
| **Frontend / UI** | `GPT-5.3-Codex` | `Low` (Speed prioritized) |
| **Complex Debugging** | `GPT-5.3-Codex` | `High` (Deep thinking) |
| **코드 관련, 구현 기능 관련 검토 및 문서 작성** | `Gemini-5.3-Codex-Spark` | `Medium` |
