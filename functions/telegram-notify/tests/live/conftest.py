"""Pytest setup for live integration tests against the deployed Lambda.

These tests require AWS credentials (set ``AWS_PROFILE`` or use the
default credential chain) and a deployed ``telegram-notify`` Lambda.
They invoke the function with payloads derived from the shared fixtures
in ``tests/events/`` and assert on both the Lambda response and the
inline log tail returned by ``LogType=Tail``.

Tests are gated behind the ``live`` marker (registered in
``pyproject.toml``); run them with ``make test-lambda-live`` or
``pytest -m live`` from inside ``functions/telegram-notify``.
"""

import json
from collections.abc import Callable
from pathlib import Path
from typing import Any

import boto3
import pytest

_EVENTS_DIR = Path(__file__).resolve().parent.parent / "events"


@pytest.fixture(scope="session")
def lambda_client() -> Any:
    """boto3 Lambda client bound to the production region."""
    return boto3.client("lambda", region_name="us-east-1")


@pytest.fixture(scope="session")
def lambda_function_name() -> str:
    """Name of the deployed Lambda to invoke."""
    return "telegram-notify"


@pytest.fixture
def load_event() -> Callable[..., dict[str, Any]]:
    """Load an SNS event fixture and inject a TEST marker into the reason.

    The marker keeps the rendered message visually distinguishable in
    Telegram from a real alarm. The loader mutates the parsed CloudWatch
    payload then re-serializes the SNS ``Message`` field so the Lambda
    sees the original wire format.
    """

    def _loader(
        name: str,
        marker: str = "[TEST EVENT \u2014 manual invoke, ignore]",
    ) -> dict[str, Any]:
        event = json.loads((_EVENTS_DIR / f"{name}.json").read_text())
        cw_message = json.loads(event["Records"][0]["Sns"]["Message"])
        cw_message["NewStateReason"] = (
            f"{marker} {cw_message.get('NewStateReason', '')}"
        )
        event["Records"][0]["Sns"]["Message"] = json.dumps(cw_message)
        return event

    return _loader
