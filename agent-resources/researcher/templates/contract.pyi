# docs/contracts/<name>-vN.pyi. In-language API contract for a Python library. Checked with mypy --strict.
from typing import Literal, Protocol

ErrorCategory = Literal["provider", "invalid_output", "limit"]

class OutputValidationError(RuntimeError): ...

class HarnessResult:
    status: Literal["ok", "error"]
    output: object | None
    def to_portable_dict(self) -> dict[str, object]: ...

class Session(Protocol):
    def run(self, prompt: str, *, output_schema: dict[str, object] | None = None, max_repairs: int = 0) -> HarnessResult: ...
