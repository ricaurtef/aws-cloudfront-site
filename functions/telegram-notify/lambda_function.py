"""Forward CloudWatch Alarm notifications to Telegram.

This Lambda function is triggered by SNS when a CloudWatch Alarm changes
state. It parses the alarm payload and sends a formatted message to a
Telegram chat via the Bot API.

Credentials (bot token and chat ID) are stored as SSM SecureString
parameters and resolved once per execution environment using the
Powertools Parameters utility with built-in caching and decryption.

Environment variables:
    SSM_BOT_TOKEN_PATH: SSM parameter path for the Telegram bot token.
    SSM_CHAT_ID_PATH:   SSM parameter path for the Telegram chat ID.

Example SNS → Lambda event:
{
  "Records": [
    {
      "Sns": {
        "Message": "{\"AlarmName\": \"cloudfront-5xx-error-rate\", ...}"
      }
    }
  ]
}
"""

import json
import os
from typing import Any
from urllib.error import URLError
from urllib.request import Request, urlopen

from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities import parameters

logger = Logger(service="telegram-notify")

_TELEGRAM_API_URL = "https://api.telegram.org/bot{token}/sendMessage"

_bot_token: str = ""
_chat_id: str = ""


def _get_credentials() -> None:
    """Resolve Telegram credentials from SSM on first invocation.

    Values are cached in module-level variables for the lifetime of the
    execution environment, avoiding repeated SSM calls on warm starts.
    """
    global _bot_token, _chat_id

    if not _bot_token:
        logger.debug("Fetching bot token from SSM")
        _bot_token = parameters.get_parameter(
            os.environ["SSM_BOT_TOKEN_PATH"], decrypt=True
        )
        logger.debug("Bot token resolved successfully")
    if not _chat_id:
        logger.debug("Fetching chat ID from SSM")
        _chat_id = parameters.get_parameter(
            os.environ["SSM_CHAT_ID_PATH"], decrypt=True
        )
        logger.debug("Chat ID resolved successfully")


def _build_message(alarm: dict[str, Any]) -> str:
    """Format a CloudWatch Alarm payload into an HTML Telegram message.

    Args:
        alarm: Parsed CloudWatch Alarm notification payload.

    Returns:
        HTML-formatted string ready for the Telegram ``sendMessage`` API.
    """
    state: str = alarm.get("NewStateValue", "UNKNOWN")
    icon = "\u26a0\ufe0f" if state == "ALARM" else "\u2705"

    trigger: dict[str, Any] = alarm.get("Trigger", {})
    metric: str = trigger.get("MetricName", "N/A")
    threshold: str = str(trigger.get("Threshold", "N/A"))
    namespace: str = trigger.get("Namespace", "N/A")

    logger.debug("Building message", extra={
        "state": state,
        "metric": metric,
        "namespace": namespace,
        "threshold": threshold,
    })

    return (
        f"{icon} <b>{alarm.get('AlarmName', 'Unknown Alarm')}</b>\n\n"
        f"<b>Status:</b> {state}\n"
        f"<b>Metric:</b> {namespace} / {metric}\n"
        f"<b>Threshold:</b> {threshold}\n"
        f"<b>Reason:</b> {alarm.get('NewStateReason', 'N/A')}\n"
        f"<b>Time:</b> {alarm.get('StateChangeTime', 'N/A')}"
    )


def _send_telegram_message(text: str) -> int:
    """Send a message to Telegram via the Bot API.

    Args:
        text: HTML-formatted message body.

    Returns:
        HTTP status code from the Telegram API response.

    Raises:
        URLError: When the Telegram API request fails.
    """
    payload: bytes = json.dumps({
        "chat_id": _chat_id,
        "text": text,
        "parse_mode": "HTML",
    }).encode()

    logger.debug("Sending request to Telegram API", extra={
        "payload_size": len(payload),
    })

    request = Request(
        _TELEGRAM_API_URL.format(token=_bot_token),
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    with urlopen(request, timeout=5) as response:
        return response.status


@logger.inject_lambda_context
def handler(event: dict[str, Any], context: Any) -> None:
    """Lambda entry point — processes SNS records from CloudWatch Alarms.

    Args:
        event: SNS event containing one or more CloudWatch Alarm messages.
        context: Lambda runtime context (injected by Powertools Logger).
    """
    logger.debug("Received event", extra={"record_count": len(event.get("Records", []))})

    _get_credentials()

    for record in event.get("Records", []):
        alarm: dict[str, Any] = json.loads(record["Sns"]["Message"])
        alarm_name: str = alarm.get("AlarmName", "Unknown")

        logger.info("Sending Telegram notification", extra={"alarm_name": alarm_name})

        try:
            status: int = _send_telegram_message(_build_message(alarm))
            logger.info(
                "Telegram API response",
                extra={"alarm_name": alarm_name, "status": status},
            )
        except URLError:
            logger.exception("Failed to send Telegram notification")
            raise
