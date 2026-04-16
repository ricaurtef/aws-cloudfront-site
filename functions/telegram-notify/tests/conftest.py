"""Pytest setup for the telegram-notify Lambda.

Stubs out ``aws_lambda_powertools`` so the tests can import
``lambda_function`` without the real package installed. The formatter
under test does not exercise Powertools runtime behavior — only its
Logger and Parameters utilities, both of which we replace with no-ops.

Also adds the Lambda directory to ``sys.path`` so ``import
lambda_function`` resolves from the tests/ directory.
"""

import sys
import types
from pathlib import Path

_LAMBDA_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LAMBDA_DIR))


class _NoopLogger:
    def debug(self, *args: object, **kwargs: object) -> None:
        pass

    def info(self, *args: object, **kwargs: object) -> None:
        pass

    def exception(self, *args: object, **kwargs: object) -> None:
        pass

    @staticmethod
    def inject_lambda_context(func):
        return func


_powertools = types.ModuleType("aws_lambda_powertools")
_powertools.Logger = lambda **_kwargs: _NoopLogger()

_utilities = types.ModuleType("aws_lambda_powertools.utilities")
_utilities.parameters = types.SimpleNamespace(
    get_parameter=lambda *_a, **_kw: "",
)

sys.modules.setdefault("aws_lambda_powertools", _powertools)
sys.modules.setdefault("aws_lambda_powertools.utilities", _utilities)
