"""Live integration tests — invoke the deployed Lambda and check delivery.

Each test fires a real Telegram message tagged
``[TEST EVENT — manual invoke, ignore]`` and verifies:

1. ``lambda:Invoke`` returns ``StatusCode=200`` with no ``FunctionError``.
2. The handler's ``Telegram API response`` info log (parsed from the
   inline ``LogResult``) reports HTTP ``200`` from the Telegram Bot API.

Skipped by default. Run with ``make test-lambda-live``.

Each run delivers one ALARM (audible) and one OK (silent) message to
the configured Telegram chat.
"""

import base64
import json
from collections.abc import Callable
from typing import Any

import pytest

pytestmark = pytest.mark.live


def _extract_telegram_status(log_result_b64: str) -> int | None:
    """Parse the base64-encoded ``LogResult`` for the Telegram status code.

    Args:
        log_result_b64: Base64-encoded last 4 KB of the Lambda's logs.

    Returns:
        The HTTP status code logged by ``_send_telegram_message``, or
        ``None`` if the log line wasn't present in the tail window.
    """
    log_text = base64.b64decode(log_result_b64).decode("utf-8", errors="replace")
    for line in log_text.splitlines():
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if payload.get("message") == "Telegram API response":
            try:
                return int(payload.get("status"))
            except (TypeError, ValueError):
                return None
    return None


@pytest.mark.parametrize(
    ("fixture", "alarm_name", "expected_state"),
    [
        ("alarm_metric_math", "cloudfront-4xx-error-rate", "ALARM"),
        ("ok_metric_math", "cloudfront-4xx-error-rate", "OK"),
    ],
    ids=["alarm_audible", "ok_silent"],
)
def test_lambda_publishes_to_telegram(
    lambda_client: Any,
    lambda_function_name: str,
    load_event: Callable[..., dict[str, Any]],
    fixture: str,
    alarm_name: str,
    expected_state: str,
) -> None:
    event = load_event(fixture)

    response = lambda_client.invoke(
        FunctionName=lambda_function_name,
        InvocationType="RequestResponse",
        LogType="Tail",
        Payload=json.dumps(event).encode(),
    )

    payload = response["Payload"].read().decode()
    assert response["StatusCode"] == 200, (
        f"Lambda invocation failed (StatusCode={response['StatusCode']}): {payload}"
    )
    assert "FunctionError" not in response, (
        f"Lambda raised {response.get('FunctionError')}: {payload}"
    )

    telegram_status = _extract_telegram_status(response.get("LogResult", ""))
    log_tail = base64.b64decode(response.get("LogResult", "")).decode(errors="replace")
    assert telegram_status == 200, (
        f"Expected Telegram API status 200 for {alarm_name} ({expected_state}); "
        f"got {telegram_status}. Inline logs:\n{log_tail}"
    )
