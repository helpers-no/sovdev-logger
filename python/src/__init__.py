"""
Sovdev Logger - Python Package

Structured logging library with OpenTelemetry integration.
"""

from .logger import (
    SOVDEV_LOGLEVELS,
    sovdev_initialize,
    sovdev_log,
    sovdev_log_job_status,
    sovdev_log_job_progress,
    sovdev_start_span,
    sovdev_end_span,
    sovdev_flush,
    sovdev_shutdown,
    create_peer_services,
)

__version__ = "1.0.0"

__all__ = [
    "SOVDEV_LOGLEVELS",
    "sovdev_initialize",
    "sovdev_log",
    "sovdev_log_job_status",
    "sovdev_log_job_progress",
    "sovdev_start_span",
    "sovdev_end_span",
    "sovdev_flush",
    "sovdev_shutdown",
    "create_peer_services",
]
