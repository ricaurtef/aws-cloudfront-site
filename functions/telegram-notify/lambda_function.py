"""Forward CloudWatch Alarm notifications to Telegram.

This Lambda function is triggered by SNS when a CloudWatch Alarm changes
state. It parses the alarm payload and sends a formatted message to a
Telegram chat via the Bot API.

Credentials (bot token and chat ID) are stored as SSM SecureString
parameters and resolved once per execution environment using the
Powertools Parameters utility with built-in caching and decryption.

Message format (HTML, rendered by Telegram):

    🟥 <b>[ALARM]</b>  cloudfront-5xx-error-rate

    <b>State</b>       OK → ALARM
    <b>Metric</b>      AWS/CloudFront / 5xxErrorRate
    <b>Threshold</b>   ≥ 5 (Average, 5 min)
    <b>When</b>        2026-04-16 20:45 UTC
    <b>Account</b>     839765241276 · us-east-1

    <b>Reason</b>
    <i>Threshold Crossed: 1 of last 2 datapoints...</i>

    <a href="...">Open in CloudWatch →</a>

Recovery (OK) messages use 🟩 and are sent with ``disable_notification``
so they land silently in the chat.

Environment variables:
    SSM_BOT_TOKEN_PATH: SSM parameter path for the Telegram bot token.
    SSM_CHAT_ID_PATH:   SSM parameter path for the Telegram chat ID.
"""

import json
import os
from datetime import datetime, timezone
from typing import Any
from urllib.error import URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities import parameters

logger = Logger(service="telegram-notify")

_TELEGRAM_API_URL = "https://api.telegram.org/bot{token}/sendMessage"

_STATE_VISUALS: dict[str, tuple[str, str]] = {
    "ALARM": ("\U0001F7E5", "ALARM"),
    "OK": ("\U0001F7E9", "OK"),
    "INSUFFICIENT_DATA": ("\U0001F7E8", "INSUFFICIENT_DATA"),
}

_COMPARISON_SYMBOLS: dict[str, str] = {
    "GreaterThanOrEqualToThreshold": "≥",
    "GreaterThanThreshold": ">",
    "LessThanOrEqualToThreshold": "≤",
    "LessThanThreshold": "<",
    "LessThanLowerOrGreaterThanUpperThreshold": "outside",
    "LessThanLowerThreshold": "<",
    "GreaterThanUpperThreshold": ">",
}

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
    if not _chat_id:
        logger.debug("Fetching chat ID from SSM")
        _chat_id = parameters.get_parameter(
            os.environ["SSM_CHAT_ID_PATH"], decrypt=True
        )


def _parse_region_from_arn(alarm_arn: str) -> str:
    """Extract the AWS region code from an alarm ARN.

    Args:
        alarm_arn: Full alarm ARN, e.g. ``arn:aws:cloudwatch:us-east-1:...``.

    Returns:
        The region code (e.g. ``us-east-1``), or an empty string if the
        ARN is malformed.
    """
    parts = alarm_arn.split(":")
    return parts[3] if len(parts) >= 4 else ""


def _format_period(seconds: int | None) -> str:
    """Render a metric period in a human-friendly unit.

    Args:
        seconds: The metric period in seconds.

    Returns:
        A short string like ``5 min`` or ``1 hr``; ``"?"`` for unknown.
    """
    if not seconds:
        return "?"
    if seconds % 3600 == 0:
        hours = seconds // 3600
        return f"{hours} hr" if hours == 1 else f"{hours} hrs"
    if seconds % 60 == 0:
        return f"{seconds // 60} min"
    return f"{seconds}s"


def _format_timestamp(raw: str) -> str:
    """Render a CloudWatch ``StateChangeTime`` as ``YYYY-MM-DD HH:MM UTC``.

    Args:
        raw: ISO 8601 timestamp from the alarm payload.

    Returns:
        A formatted UTC timestamp, or the original string if parsing fails.
    """
    try:
        normalized = raw.replace("Z", "+00:00")
        parsed = datetime.fromisoformat(normalized).astimezone(timezone.utc)
        return parsed.strftime("%Y-%m-%d %H:%M UTC")
    except (ValueError, TypeError):
        return raw


def _format_metric(trigger: dict[str, Any]) -> str:
    """Render the metric identifier for display.

    Handles both simple-metric alarms (``Trigger.MetricName``) and
    metric-math alarms (``Trigger.Metrics`` array), picking the
    ``ReturnData=true`` entry for the latter.

    Args:
        trigger: The ``Trigger`` subtree of the alarm payload.

    Returns:
        A human-friendly metric identifier.
    """
    metric_name = trigger.get("MetricName")
    if metric_name:
        namespace = trigger.get("Namespace", "")
        return f"{namespace} / {metric_name}" if namespace else metric_name

    metrics = trigger.get("Metrics", [])
    for entry in metrics:
        if entry.get("ReturnData"):
            return entry.get("Label") or entry.get("Id") or "metric math"
    return "metric math"


def _format_threshold(trigger: dict[str, Any]) -> str:
    """Render the threshold condition as ``<op> <value> (<stat>, <period>)``.

    For metric-math alarms, the top-level ``Statistic`` and ``Period`` are
    absent and the parenthetical context is omitted. Integer-valued
    thresholds (e.g. ``5.0``) are shown without the trailing ``.0``.

    Args:
        trigger: The ``Trigger`` subtree of the alarm payload.

    Returns:
        A human-friendly threshold string.
    """
    op = _COMPARISON_SYMBOLS.get(
        trigger.get("ComparisonOperator", ""), trigger.get("ComparisonOperator", "")
    )
    raw_threshold = trigger.get("Threshold", "?")
    threshold: str
    if isinstance(raw_threshold, float) and raw_threshold.is_integer():
        threshold = str(int(raw_threshold))
    else:
        threshold = str(raw_threshold)

    stat = trigger.get("Statistic") or trigger.get("ExtendedStatistic", "")
    period_seconds = trigger.get("Period")
    period = _format_period(period_seconds) if period_seconds else ""

    context = ", ".join(filter(None, [stat, period]))
    return f"{op} {threshold} ({context})" if context else f"{op} {threshold}"


def _build_console_url(alarm_name: str, region: str) -> str:
    """Build a CloudWatch console URL for the alarm detail page.

    Args:
        alarm_name: Name of the alarm (not URL-encoded).
        region: AWS region code (e.g. ``us-east-1``).

    Returns:
        An ``https://`` URL opening the alarm in the CloudWatch console.
    """
    encoded = quote(alarm_name, safe="")
    return (
        f"https://{region}.console.aws.amazon.com/cloudwatch/home"
        f"?region={region}#alarmsV2:alarm/{encoded}"
    )


def _build_message(alarm: dict[str, Any]) -> str:
    """Format a CloudWatch Alarm payload into an HTML Telegram message.

    Args:
        alarm: Parsed CloudWatch Alarm notification payload.

    Returns:
        HTML-formatted string ready for the Telegram ``sendMessage`` API.
    """
    state = alarm.get("NewStateValue", "UNKNOWN")
    old_state = alarm.get("OldStateValue", "UNKNOWN")
    dot, label = _STATE_VISUALS.get(state, ("\u25fb\ufe0f", state))

    trigger: dict[str, Any] = alarm.get("Trigger", {})
    alarm_name = alarm.get("AlarmName", "Unknown Alarm")
    region = _parse_region_from_arn(alarm.get("AlarmArn", ""))
    account = alarm.get("AWSAccountId", "")
    account_line = " · ".join(filter(None, [account, region]))

    console_url = _build_console_url(alarm_name, region) if region else ""

    lines = [
        f"{dot} <b>[{label}]</b>  {alarm_name}",
        "",
        f"<b>State</b>       {old_state} → {state}",
        f"<b>Metric</b>      {_format_metric(trigger)}",
        f"<b>Threshold</b>   {_format_threshold(trigger)}",
        f"<b>When</b>        {_format_timestamp(alarm.get('StateChangeTime', ''))}",
    ]
    if account_line:
        lines.append(f"<b>Account</b>     {account_line}")

    reason = alarm.get("NewStateReason")
    if reason:
        lines.extend(["", "<b>Reason</b>", f"<i>{reason}</i>"])

    if console_url:
        lines.extend(["", f'<a href="{console_url}">Open in CloudWatch →</a>'])

    return "\n".join(lines)


def _send_telegram_message(text: str, *, silent: bool) -> int:
    """Send a message to Telegram via the Bot API.

    Args:
        text: HTML-formatted message body.
        silent: When ``True``, send with ``disable_notification`` so the
            message lands in the chat without a sound or vibration.

    Returns:
        HTTP status code from the Telegram API response.

    Raises:
        URLError: When the Telegram API request fails.
    """
    payload: bytes = json.dumps({
        "chat_id": _chat_id,
        "text": text,
        "parse_mode": "HTML",
        "disable_notification": silent,
        "disable_web_page_preview": True,
    }).encode()

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
    _get_credentials()

    for record in event.get("Records", []):
        alarm: dict[str, Any] = json.loads(record["Sns"]["Message"])
        alarm_name: str = alarm.get("AlarmName", "Unknown")
        state: str = alarm.get("NewStateValue", "UNKNOWN")

        logger.info(
            "Sending Telegram notification",
            extra={"alarm_name": alarm_name, "state": state},
        )

        try:
            status: int = _send_telegram_message(
                _build_message(alarm), silent=(state == "OK")
            )
            logger.info(
                "Telegram API response",
                extra={"alarm_name": alarm_name, "status": status},
            )
        except URLError:
            logger.exception("Failed to send Telegram notification")
            raise
