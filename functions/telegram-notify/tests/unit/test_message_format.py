"""Regression tests for the Telegram alert message format.

These tests load SNS-shaped fixtures and assert the output of
``_build_message`` matches a known-good snapshot. They run offline — no
AWS credentials, no Telegram API access, no Powertools installed (stubbed
in ``conftest.py``).

Run with ``make test-lambda``.
"""

import json
from pathlib import Path
from typing import Any

import pytest

import lambda_function  # noqa: E402  (path set in conftest.py)

_EVENTS_DIR = Path(__file__).resolve().parent.parent / "events"


def _load(name: str) -> dict[str, Any]:
    """Load an SNS event fixture and return the parsed CloudWatch payload.

    Args:
        name: Fixture basename (without the ``.json`` suffix).

    Returns:
        The inner CloudWatch alarm payload (already JSON-decoded).
    """
    event = json.loads((_EVENTS_DIR / f"{name}.json").read_text())
    return json.loads(event["Records"][0]["Sns"]["Message"])


ALARM_METRIC_MATH = """\
\U0001F7E5 <b>[ALARM]</b>  cloudfront-4xx-error-rate

<b>State</b>       OK \u2192 ALARM
<b>Metric</b>      4xx error rate (gated on minimum requests)
<b>Threshold</b>   \u2265 15
<b>When</b>        2026-04-16 20:45 UTC
<b>Account</b>     839765241276 \u00b7 us-east-1

<b>Reason</b>
<i>Threshold Crossed: 2 out of the last 2 datapoints were greater than or equal to the threshold (15.0).</i>

<a href="https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#alarmsV2:alarm/cloudfront-4xx-error-rate">Open in CloudWatch \u2192</a>"""


OK_METRIC_MATH = """\
\U0001F7E9 <b>[OK]</b>  cloudfront-4xx-error-rate

<b>State</b>       ALARM \u2192 OK
<b>Metric</b>      4xx error rate (gated on minimum requests)
<b>Threshold</b>   \u2265 15
<b>When</b>        2026-04-16 21:00 UTC
<b>Account</b>     839765241276 \u00b7 us-east-1

<b>Reason</b>
<i>Threshold Crossed: no datapoints were found in violation of the threshold.</i>

<a href="https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#alarmsV2:alarm/cloudfront-4xx-error-rate">Open in CloudWatch \u2192</a>"""


ALARM_SIMPLE_METRIC = """\
\U0001F7E5 <b>[ALARM]</b>  cloudfront-5xx-error-rate

<b>State</b>       OK \u2192 ALARM
<b>Metric</b>      AWS/CloudFront / 5xxErrorRate
<b>Threshold</b>   \u2265 5 (Average, 5 min)
<b>When</b>        2026-04-16 20:45 UTC
<b>Account</b>     839765241276 \u00b7 us-east-1

<b>Reason</b>
<i>Threshold Crossed: 1 out of the last 2 datapoints [12.5 (16/04/26 20:45:00)] was greater than or equal to the threshold (5.0).</i>

<a href="https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#alarmsV2:alarm/cloudfront-5xx-error-rate">Open in CloudWatch \u2192</a>"""


INSUFFICIENT_DATA = """\
\U0001F7E8 <b>[INSUFFICIENT_DATA]</b>  cloudfront-request-spike

<b>State</b>       OK \u2192 INSUFFICIENT_DATA
<b>Metric</b>      AWS/CloudFront / Requests
<b>Threshold</b>   \u2265 10000 (Sum, 5 min)
<b>When</b>        2026-04-16 20:45 UTC
<b>Account</b>     839765241276 \u00b7 us-east-1

<b>Reason</b>
<i>Insufficient Data: 1 datapoint was unknown.</i>

<a href="https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#alarmsV2:alarm/cloudfront-request-spike">Open in CloudWatch \u2192</a>"""


@pytest.mark.parametrize(
    ("fixture", "expected"),
    [
        ("alarm_metric_math", ALARM_METRIC_MATH),
        ("ok_metric_math", OK_METRIC_MATH),
        ("alarm_simple_metric", ALARM_SIMPLE_METRIC),
        ("insufficient_data", INSUFFICIENT_DATA),
    ],
)
def test_build_message_snapshot(fixture: str, expected: str) -> None:
    assert lambda_function._build_message(_load(fixture)) == expected


@pytest.mark.parametrize(
    ("state", "silent_expected"),
    [
        ("ALARM", False),
        ("OK", True),
        ("INSUFFICIENT_DATA", False),
    ],
)
def test_silent_flag_matches_state(state: str, silent_expected: bool) -> None:
    # Handler uses: silent=(state == "OK")
    assert (state == "OK") is silent_expected


def test_integer_threshold_drops_trailing_zero() -> None:
    alarm = _load("alarm_simple_metric")
    assert "\u2265 5 " in lambda_function._build_message(alarm)
    assert "5.0" not in lambda_function._format_threshold(alarm["Trigger"])


def test_cloudwatch_url_encodes_alarm_name() -> None:
    url = lambda_function._build_console_url("my alarm/with#special", "us-east-1")
    assert "my%20alarm%2Fwith%23special" in url
    assert url.startswith("https://us-east-1.console.aws.amazon.com/cloudwatch/home")


def test_region_parsed_from_arn() -> None:
    arn = "arn:aws:cloudwatch:eu-west-2:123456789012:alarm:foo"
    assert lambda_function._parse_region_from_arn(arn) == "eu-west-2"
    assert lambda_function._parse_region_from_arn("") == ""


def test_metric_math_picks_return_data_label() -> None:
    trigger = _load("alarm_metric_math")["Trigger"]
    assert lambda_function._format_metric(trigger) == (
        "4xx error rate (gated on minimum requests)"
    )


def test_comparison_symbol_mapping() -> None:
    assert lambda_function._COMPARISON_SYMBOLS["GreaterThanOrEqualToThreshold"] == "\u2265"
    assert lambda_function._COMPARISON_SYMBOLS["LessThanThreshold"] == "<"


def test_period_formatting() -> None:
    assert lambda_function._format_period(60) == "1 min"
    assert lambda_function._format_period(300) == "5 min"
    assert lambda_function._format_period(3600) == "1 hr"
    assert lambda_function._format_period(7200) == "2 hrs"
    assert lambda_function._format_period(45) == "45s"
    assert lambda_function._format_period(None) == "?"


def test_timestamp_parses_iso_with_offset() -> None:
    assert lambda_function._format_timestamp("2026-04-16T20:45:00.000+0000") == (
        "2026-04-16 20:45 UTC"
    )
    assert lambda_function._format_timestamp("2026-04-16T20:45:00Z") == (
        "2026-04-16 20:45 UTC"
    )


def test_timestamp_falls_back_on_unparseable() -> None:
    assert lambda_function._format_timestamp("not a timestamp") == "not a timestamp"
