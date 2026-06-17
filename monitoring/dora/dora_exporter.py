#!/usr/bin/env python3
"""Small DORA exporter/dashboard for the Spring Petclinic project."""

from __future__ import annotations

import html
import json
import os
import re
import statistics
import threading
import time
import urllib.parse
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import requests


OWNER = os.getenv("DORA_GITHUB_OWNER", "Guytho1996")
REPO = os.getenv("DORA_GITHUB_REPO", "spring-petclinic-devops")
ENVIRONMENT = os.getenv("DORA_ENVIRONMENT", "production")
BRANCH = os.getenv("DORA_BRANCH", "master,main")
ALLOWED_BRANCHES = [b.strip() for b in BRANCH.split(",")]
PORT = int(os.getenv("DORA_EXPORTER_PORT", "9108"))
CACHE_SECONDS = int(os.getenv("DORA_CACHE_SECONDS", "45"))
INCIDENTS_FILE = Path(os.getenv("DORA_INCIDENTS_FILE", Path(__file__).with_name("incidents.json")))
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN") or os.getenv("GH_TOKEN")
GITHUB_API_HOST = "api.github.com"
USER_AGENT = "petclinic-dora-exporter/1.0"
SAFE_REPO_PART = re.compile(r"^[A-Za-z0-9_.-]+$")

_cache_lock = threading.Lock()
_cache: dict[str, object] = {"expires_at": 0.0, "payload": None, "error": None}
_status_cache: dict[int, list[dict[str, object]]] = {}
_commit_cache: dict[str, datetime] = {}


class GitHubApiError(RuntimeError):
    """Raised when the fixed GitHub API endpoint returns an error."""


def parse_ts(value: str | None) -> datetime | None:
    if not value:
        return None
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)


def iso(value: datetime | None) -> str | None:
    if value is None:
        return None
    return value.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def github_resource(path: str, params: dict[str, str] | None = None) -> str:
    if not SAFE_REPO_PART.fullmatch(OWNER) or not SAFE_REPO_PART.fullmatch(REPO):
        raise ValueError("GitHub owner and repo must contain only letters, digits, dots, underscores, or dashes")
    if not path.startswith("/") or "://" in path or "?" in path or "#" in path:
        raise ValueError("GitHub API path must be a relative path")

    resource = f"/repos/{OWNER}/{REPO}{path}"
    if params:
        resource = f"{resource}?{urllib.parse.urlencode(params)}"
    return resource


def github_get(path: str, params: dict[str, str] | None = None) -> object:
    url = f"https://{GITHUB_API_HOST}{github_resource(path, params)}"
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": USER_AGENT,
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if GITHUB_TOKEN:
        headers["Authorization"] = f"Bearer {GITHUB_TOKEN}"

    try:
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        return response.json()
    except requests.RequestException as exc:
        raise GitHubApiError(f"GitHub API request failed: {exc}") from exc


def load_incidents() -> list[dict[str, object]]:
    try:
        raw = json.loads(INCIDENTS_FILE.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return []
    if not isinstance(raw, list):
        raise ValueError(f"{INCIDENTS_FILE} must contain a JSON array")
    return raw


def deployment_status(deployment: dict[str, object]) -> dict[str, object]:
    deployment_id = int(deployment["id"])
    statuses = _status_cache.get(deployment_id)

    def fetch_statuses() -> list[dict[str, object]]:
        statuses = github_get(f"/deployments/{deployment_id}/statuses", {"per_page": "100"})
        if not isinstance(statuses, list):
            statuses = []
        _status_cache[deployment_id] = statuses
        return statuses

    if statuses is None:
        statuses = fetch_statuses()

    ordered = sorted(statuses, key=lambda item: item.get("created_at", ""))
    success_at = None
    failure_at = None
    latest_state = "unknown"
    for status in ordered:
        state = str(status.get("state", "unknown"))
        latest_state = state
        created_at = parse_ts(status.get("created_at"))
        if state == "success" and success_at is None:
            success_at = created_at
        if state in {"failure", "error"} and failure_at is None:
            failure_at = created_at

    if success_at:
        final_state = "success"
        completed_at = success_at
    elif failure_at:
        final_state = "failure"
        completed_at = failure_at
    else:
        final_state = latest_state
        completed_at = None

    if final_state not in {"success", "failure"}:
        statuses = fetch_statuses()
        ordered = sorted(statuses, key=lambda item: item.get("created_at", ""))
        success_at = None
        failure_at = None
        latest_state = "unknown"
        for status in ordered:
            state = str(status.get("state", "unknown"))
            latest_state = state
            created_at = parse_ts(status.get("created_at"))
            if state == "success" and success_at is None:
                success_at = created_at
            if state in {"failure", "error"} and failure_at is None:
                failure_at = created_at
        if success_at:
            final_state = "success"
            completed_at = success_at
        elif failure_at:
            final_state = "failure"
            completed_at = failure_at

    return {
        "state": final_state,
        "completed_at": completed_at,
        "latest_state": latest_state,
        "status_count": len(statuses),
    }


def commit_time(sha: str) -> datetime | None:
    if sha in _commit_cache:
        return _commit_cache[sha]
    commit = github_get(f"/commits/{sha}")
    if isinstance(commit, dict):
        commit_data = commit.get("commit", {})
        if isinstance(commit_data, dict):
            author = commit_data.get("author", {})
            committer = commit_data.get("committer", {})
            if isinstance(author, dict):
                committed_at = parse_ts(author.get("date"))
            else:
                committed_at = None
            if committed_at is None and isinstance(committer, dict):
                committed_at = parse_ts(committer.get("date"))
            if committed_at:
                _commit_cache[sha] = committed_at
                return committed_at
    return None


def seconds_between(start: datetime | None, end: datetime | None) -> float | None:
    if not start or not end:
        return None
    return max((end - start).total_seconds(), 0.0)


def classify_df(per_day: float, last_24h: int) -> tuple[str, int, str]:
    if last_24h >= 2 or per_day >= 1:
        return "Elite", 4, "Mantener lotes pequenos y aprobaciones livianas."
    if per_day >= 1 / 7:
        return "High", 3, "Aumentar automatizacion para acercarse a despliegues diarios."
    if per_day >= 1 / 30:
        return "Medium", 2, "Reducir batch size y automatizar validaciones previas."
    return "Low", 1, "Eliminar pasos manuales que bloquean despliegues frecuentes."


def classify_lt(seconds: float | None) -> tuple[str, int, str]:
    if seconds is None:
        return "No data", 0, "Registrar deployments exitosos para calcular lead time."
    if seconds < 3600:
        return "Elite", 4, "Mantener pipeline rapido con pruebas confiables."
    if seconds < 86400:
        return "High", 3, "Reducir esperas entre build, aprobacion y despliegue."
    if seconds < 604800:
        return "Medium", 2, "Partir cambios grandes y revisar cuellos de botella del pipeline."
    return "Low", 1, "Mapear value stream y eliminar esperas manuales prolongadas."


def classify_cfr(ratio: float | None) -> tuple[str, int, str]:
    if ratio is None:
        return "No data", 0, "Registrar incidentes y rollbacks por deployment."
    if ratio <= 0.15:
        return "Elite", 4, "Mantener smoke tests y postmortems sin culpa."
    if ratio <= 0.30:
        return "High", 3, "Fortalecer pruebas e introducir despliegues graduales."
    return "Low", 1, "Revisar calidad de release gates y automatizar rollback/fix-forward."


def classify_mttr(seconds: float | None) -> tuple[str, int, str]:
    if seconds is None:
        return "No data", 0, "Registrar hora de deteccion y restauracion de incidentes."
    if seconds < 3600:
        return "Elite", 4, "Mantener runbooks y alertas accionables."
    if seconds < 86400:
        return "High", 3, "Automatizar diagnostico y restauracion."
    if seconds < 604800:
        return "Medium", 2, "Practicar game days y mejorar observabilidad."
    return "Low", 1, "Definir runbooks, alertas SLO y rollback probado."


def build_payload() -> dict[str, object]:
    now = datetime.now(timezone.utc)
    deployments_raw = []
    page = 1
    while True:
        page_items = github_get("/deployments", {"per_page": "100", "page": str(page)})
        if not isinstance(page_items, list) or not page_items:
            break
        deployments_raw.extend(page_items)
        if len(page_items) < 100:
            break
        page += 1

    deployments: list[dict[str, object]] = []
    for item in deployments_raw:
        if str(item.get("environment", "")).lower() != ENVIRONMENT.lower():
            continue
        if item.get("ref") not in ALLOWED_BRANCHES:
            continue
        sha = str(item.get("sha", ""))
        created_at = parse_ts(item.get("created_at"))
        status = deployment_status(item)
        committed_at = commit_time(sha) if sha else None
        completed_at = status["completed_at"]
        lead_time = seconds_between(committed_at, completed_at if isinstance(completed_at, datetime) else None)
        deployments.append(
            {
                "id": item.get("id"),
                "sha": sha,
                "short_sha": sha[:7],
                "environment": item.get("environment"),
                "ref": item.get("ref"),
                "created_at": iso(created_at),
                "completed_at": iso(completed_at if isinstance(completed_at, datetime) else None),
                "committed_at": iso(committed_at),
                "state": status["state"],
                "lead_time_seconds": lead_time,
                "creator": (item.get("creator") or {}).get("login") if isinstance(item.get("creator"), dict) else None,
                "url": item.get("url"),
            }
        )

    successes = [d for d in deployments if d["state"] == "success" and d["completed_at"]]
    failures = [d for d in deployments if d["state"] == "failure"]
    successes.sort(key=lambda d: str(d["completed_at"]))
    deployments.sort(key=lambda d: str(d["created_at"]))
    last_success = successes[-1] if successes else None

    period_start = parse_ts(successes[0]["completed_at"]) if successes else None
    if not period_start:
        period_start = parse_ts(deployments[0]["created_at"]) if deployments else now
    period_days = max((now - period_start).total_seconds() / 86400, 1 / 24)
    last_24h_cutoff = now.timestamp() - 86400
    last_7d_cutoff = now.timestamp() - 7 * 86400
    last_24h = [
        d for d in successes if parse_ts(d["completed_at"]) and parse_ts(d["completed_at"]).timestamp() >= last_24h_cutoff
    ]
    last_7d = [
        d for d in successes if parse_ts(d["completed_at"]) and parse_ts(d["completed_at"]).timestamp() >= last_7d_cutoff
    ]
    df_per_day = len(successes) / period_days if period_days else 0.0

    lead_times = [float(d["lead_time_seconds"]) for d in successes if d["lead_time_seconds"] is not None]
    last_lead_time = float(last_success["lead_time_seconds"]) if last_success and last_success["lead_time_seconds"] is not None else None
    avg_lead_time = statistics.mean(lead_times) if lead_times else None

    incidents = [
        incident for incident in load_incidents()
        if str(incident.get("environment", "")).lower() == ENVIRONMENT.lower()
    ]
    mttr_values: list[float] = []
    normalized_incidents: list[dict[str, object]] = []
    failed_change_keys: set[str] = set()
    for incident in incidents:
        detected_at = parse_ts(incident.get("detected_at"))
        restored_at = parse_ts(incident.get("restored_at"))
        mttr = seconds_between(detected_at, restored_at)
        if mttr is not None:
            mttr_values.append(mttr)
        key = str(incident.get("caused_by_deployment_sha") or incident.get("id"))
        if key:
            failed_change_keys.add(key)
        normalized_incidents.append(
            {
                "id": incident.get("id"),
                "title": incident.get("title"),
                "severity": incident.get("severity"),
                "detected_at": iso(detected_at),
                "restored_at": iso(restored_at),
                "mttr_seconds": mttr,
                "caused_by_deployment_sha": incident.get("caused_by_deployment_sha"),
                "recovery_deployment_sha": incident.get("recovery_deployment_sha"),
                "rollback_required": bool(incident.get("rollback_required", False)),
                "summary": ((incident.get("postmortem") or {}).get("summary") if isinstance(incident.get("postmortem"), dict) else None),
            }
        )

    failed_deployment_shas = {str(d["sha"]) for d in failures if d.get("sha")}
    failed_change_count = len(failed_change_keys | failed_deployment_shas)
    deployment_denominator = len(successes) + len(failures)
    change_failure_rate = (failed_change_count / deployment_denominator) if deployment_denominator else None
    latest_mttr = mttr_values[-1] if mttr_values else None
    avg_mttr = statistics.mean(mttr_values) if mttr_values else None

    df_level, df_score, df_recommendation = classify_df(df_per_day, len(last_24h))
    lt_level, lt_score, lt_recommendation = classify_lt(last_lead_time)
    cfr_level, cfr_score, cfr_recommendation = classify_cfr(change_failure_rate)
    mttr_level, mttr_score, mttr_recommendation = classify_mttr(latest_mttr)

    return {
        "generated_at": iso(now),
        "source": {
            "repo": f"{OWNER}/{REPO}",
            "branch": BRANCH,
            "environment": ENVIRONMENT,
            "incidents_file": str(INCIDENTS_FILE),
        },
        "metrics": {
            "deployment_frequency": {
                "value_per_day": df_per_day,
                "successful_deployments_total": len(successes),
                "successful_deployments_24h": len(last_24h),
                "successful_deployments_7d": len(last_7d),
                "period_days": period_days,
                "benchmark": df_level,
                "score": df_score,
                "recommendation": df_recommendation,
            },
            "lead_time_for_changes": {
                "last_seconds": last_lead_time,
                "average_seconds": avg_lead_time,
                "benchmark": lt_level,
                "score": lt_score,
                "recommendation": lt_recommendation,
            },
            "change_failure_rate": {
                "ratio": change_failure_rate,
                "percent": change_failure_rate * 100 if change_failure_rate is not None else None,
                "failed_changes_total": failed_change_count,
                "deployment_attempts_total": deployment_denominator,
                "benchmark": cfr_level,
                "score": cfr_score,
                "recommendation": cfr_recommendation,
            },
            "mttr": {
                "latest_seconds": latest_mttr,
                "average_seconds": avg_mttr,
                "incidents_total": len(incidents),
                "benchmark": mttr_level,
                "score": mttr_score,
                "recommendation": mttr_recommendation,
            },
        },
        "last_deployment": last_success,
        "deployments": list(reversed(deployments))[:25],
        "incidents": normalized_incidents,
        "benchmarks": {
            "deployment_frequency": "Elite: on demand/multiple per day; High: daily to weekly; Medium: weekly to monthly; Low: less than monthly.",
            "lead_time_for_changes": "Elite: < 1 hour; High: < 1 day; Medium: < 1 week; Low: >= 1 week.",
            "change_failure_rate": "Elite: 0-15%; High: 16-30%; Low: > 30%.",
            "mttr": "Elite: < 1 hour; High: < 1 day; Medium: < 1 week; Low: >= 1 week.",
        },
    }


def get_payload(force: bool = False) -> dict[str, object]:
    now = time.monotonic()
    with _cache_lock:
        cached_payload = _cache.get("payload")
        if not force and cached_payload is not None and now < float(_cache.get("expires_at", 0)):
            return cached_payload  # type: ignore[return-value]
        try:
            payload = build_payload()
            _cache["payload"] = payload
            _cache["expires_at"] = now + CACHE_SECONDS
            _cache["error"] = None
            return payload
        except Exception as exc:
            _cache["error"] = str(exc)
            if cached_payload is not None:
                cached_payload["stale"] = True  # type: ignore[index]
                cached_payload["error"] = str(exc)  # type: ignore[index]
                return cached_payload  # type: ignore[return-value]
            raise


def fmt_number(value: float | int | None) -> str:
    if value is None:
        return "n/a"
    if isinstance(value, float):
        return f"{value:.6g}"
    return str(value)


def prom_labels(labels: dict[str, str]) -> str:
    escaped = []
    for key, value in labels.items():
        safe = value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        escaped.append(f'{key}="{safe}"')
    return "{" + ",".join(escaped) + "}"


def metric_line(name: str, value: float | int | None, labels: dict[str, str] | None = None) -> str:
    if value is None:
        value = 0
    label_text = prom_labels(labels or {})
    return f"{name}{label_text} {fmt_number(value)}"


def render_metrics(payload: dict[str, object]) -> str:
    metrics = payload["metrics"]  # type: ignore[index]
    source = payload["source"]  # type: ignore[index]
    environment = str(source["environment"])  # type: ignore[index]
    repo = str(source["repo"])  # type: ignore[index]
    last_deployment = payload.get("last_deployment") or {}
    last_sha = str((last_deployment or {}).get("short_sha", "none")) if isinstance(last_deployment, dict) else "none"
    lines = [
        "# HELP dora_deployment_frequency_per_day Successful production deployments per day over the observed project period.",
        "# TYPE dora_deployment_frequency_per_day gauge",
        metric_line("dora_deployment_frequency_per_day", metrics["deployment_frequency"]["value_per_day"], {"environment": environment}),  # type: ignore[index]
        "# HELP dora_deployments_total Production deployments by state.",
        "# TYPE dora_deployments_total gauge",
        metric_line("dora_deployments_total", metrics["deployment_frequency"]["successful_deployments_total"], {"environment": environment, "state": "success"}),  # type: ignore[index]
        metric_line("dora_deployments_total", metrics["change_failure_rate"]["deployment_attempts_total"], {"environment": environment, "state": "attempted"}),  # type: ignore[index]
        metric_line("dora_deployments_last_24h", metrics["deployment_frequency"]["successful_deployments_24h"], {"environment": environment, "state": "success"}),  # type: ignore[index]
        metric_line("dora_deployments_last_7d", metrics["deployment_frequency"]["successful_deployments_7d"], {"environment": environment, "state": "success"}),  # type: ignore[index]
        "# HELP dora_lead_time_seconds Time from commit timestamp to successful production deployment.",
        "# TYPE dora_lead_time_seconds gauge",
        metric_line("dora_lead_time_seconds", metrics["lead_time_for_changes"]["last_seconds"], {"environment": environment, "stat": "last"}),  # type: ignore[index]
        metric_line("dora_lead_time_seconds", metrics["lead_time_for_changes"]["average_seconds"], {"environment": environment, "stat": "average"}),  # type: ignore[index]
        "# HELP dora_change_failure_rate_ratio Ratio of production deployments associated with incidents, rollback, hotfix, or failed deployment status.",
        "# TYPE dora_change_failure_rate_ratio gauge",
        metric_line("dora_change_failure_rate_ratio", metrics["change_failure_rate"]["ratio"], {"environment": environment}),  # type: ignore[index]
        "# HELP dora_change_failures_total Production changes associated with incidents, rollback, hotfix, or failed deployment status.",
        "# TYPE dora_change_failures_total gauge",
        metric_line("dora_change_failures_total", metrics["change_failure_rate"]["failed_changes_total"], {"environment": environment}),  # type: ignore[index]
        "# HELP dora_mttr_seconds Mean/latest time to restore production incidents.",
        "# TYPE dora_mttr_seconds gauge",
        metric_line("dora_mttr_seconds", metrics["mttr"]["latest_seconds"], {"environment": environment, "stat": "latest"}),  # type: ignore[index]
        metric_line("dora_mttr_seconds", metrics["mttr"]["average_seconds"], {"environment": environment, "stat": "average"}),  # type: ignore[index]
        "# HELP dora_incidents_total Production incident records used for CFR and MTTR.",
        "# TYPE dora_incidents_total gauge",
        metric_line("dora_incidents_total", metrics["mttr"]["incidents_total"], {"environment": environment}),  # type: ignore[index]
        "# HELP dora_benchmark_score Numeric benchmark score: 4 elite, 3 high, 2 medium, 1 low, 0 no data.",
        "# TYPE dora_benchmark_score gauge",
    ]
    for metric_name, metric_payload in metrics.items():  # type: ignore[union-attr]
        lines.append(metric_line("dora_benchmark_score", metric_payload["score"], {"metric": metric_name, "benchmark": metric_payload["benchmark"]}))  # type: ignore[index]
    lines.extend(
        [
            "# HELP dora_info Static metadata for the current DORA export.",
            "# TYPE dora_info gauge",
            metric_line("dora_info", 1, {"repo": repo, "environment": environment, "last_deployment_sha": last_sha}),
            "",
        ]
    )
    return "\n".join(lines)


HTML_PAGE = """<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Petclinic DORA</title>
  <style>
    :root { color-scheme: light; font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    body { margin: 0; background: #f7f8fb; color: #1d2733; }
    header { padding: 24px clamp(16px, 4vw, 42px) 14px; background: #ffffff; border-bottom: 1px solid #dde3ea; }
    h1 { margin: 0; font-size: 28px; letter-spacing: 0; }
    .meta { margin-top: 8px; color: #667085; font-size: 14px; display: flex; flex-wrap: wrap; gap: 12px; }
    main { padding: 20px clamp(16px, 4vw, 42px) 36px; }
    .grid { display: grid; grid-template-columns: repeat(4, minmax(180px, 1fr)); gap: 14px; }
    .card { background: #ffffff; border: 1px solid #dde3ea; border-radius: 8px; padding: 16px; min-height: 150px; box-sizing: border-box; }
    .label { font-size: 13px; color: #667085; text-transform: uppercase; letter-spacing: 0; }
    .value { margin-top: 10px; font-size: 30px; font-weight: 760; line-height: 1.1; overflow-wrap: anywhere; }
    .tier { display: inline-flex; align-items: center; margin-top: 10px; border-radius: 999px; padding: 4px 9px; font-size: 13px; font-weight: 650; background: #eef4ff; color: #1849a9; }
    .rec { margin-top: 10px; color: #475467; font-size: 13px; line-height: 1.35; }
    .section { margin-top: 20px; }
    .section h2 { font-size: 18px; margin: 0 0 10px; }
    table { width: 100%; border-collapse: collapse; background: #ffffff; border: 1px solid #dde3ea; border-radius: 8px; overflow: hidden; display: table; }
    th, td { padding: 10px 12px; border-bottom: 1px solid #edf1f5; text-align: left; font-size: 14px; vertical-align: top; }
    th { background: #f0f4f8; color: #475467; font-size: 12px; text-transform: uppercase; letter-spacing: 0; }
    tr:last-child td { border-bottom: 0; }
    .ok { color: #027a48; }
    .warn { color: #b54708; }
    .bad { color: #b42318; }
    @media (max-width: 950px) { .grid { grid-template-columns: repeat(2, minmax(180px, 1fr)); } }
    @media (max-width: 560px) { .grid { grid-template-columns: 1fr; } h1 { font-size: 24px; } .value { font-size: 26px; } table { display: block; overflow-x: auto; } }
  </style>
</head>
<body>
  <header>
    <h1>Petclinic DORA Dashboard</h1>
    <div class="meta">
      <span id="repo">Repo</span>
      <span id="env">Environment</span>
      <span id="updated">Actualizando...</span>
    </div>
  </header>
  <main>
    <section class="grid" id="cards"></section>
    <section class="section">
      <h2>Ultimos deployments</h2>
      <table>
        <thead><tr><th>SHA</th><th>Estado</th><th>Commit</th><th>Produccion</th><th>Lead time</th></tr></thead>
        <tbody id="deployments"></tbody>
      </table>
    </section>
    <section class="section">
      <h2>Incidente y post-mortem</h2>
      <table>
        <thead><tr><th>ID</th><th>Severidad</th><th>Detectado</th><th>Restaurado</th><th>MTTR</th><th>Resumen</th></tr></thead>
        <tbody id="incidents"></tbody>
      </table>
    </section>
  </main>
  <script>
    const cards = document.getElementById("cards");
    const deployments = document.getElementById("deployments");
    const incidents = document.getElementById("incidents");
    const fmtSeconds = (value) => {
      if (value === null || value === undefined) return "n/a";
      if (value < 60) return `${Math.round(value)}s`;
      if (value < 3600) return `${Math.round(value / 60)}m`;
      if (value < 86400) return `${(value / 3600).toFixed(1)}h`;
      return `${(value / 86400).toFixed(1)}d`;
    };
    const tierClass = (tier) => tier === "Elite" ? "ok" : tier === "High" ? "ok" : tier === "Medium" ? "warn" : "bad";
    const card = (title, value, tier, recommendation) => `
      <article class="card">
        <div class="label">${title}</div>
        <div class="value">${value}</div>
        <div class="tier ${tierClass(tier)}">${tier}</div>
        <div class="rec">${recommendation}</div>
      </article>`;
    async function refresh() {
      const response = await fetch("/api/dora", { cache: "no-store" });
      const data = await response.json();
      document.getElementById("repo").textContent = data.source.repo;
      document.getElementById("env").textContent = data.source.environment;
      document.getElementById("updated").textContent = `Actualizado ${data.generated_at}`;
      const m = data.metrics;
      cards.innerHTML = [
        card("Deployment Frequency", `${m.deployment_frequency.successful_deployments_24h} en 24h`, m.deployment_frequency.benchmark, m.deployment_frequency.recommendation),
        card("Lead Time", fmtSeconds(m.lead_time_for_changes.last_seconds), m.lead_time_for_changes.benchmark, m.lead_time_for_changes.recommendation),
        card("Change Failure Rate", `${(m.change_failure_rate.percent ?? 0).toFixed(1)}%`, m.change_failure_rate.benchmark, m.change_failure_rate.recommendation),
        card("MTTR", fmtSeconds(m.mttr.latest_seconds), m.mttr.benchmark, m.mttr.recommendation)
      ].join("");
      deployments.innerHTML = data.deployments.slice(0, 10).map((d) => `
        <tr>
          <td>${d.short_sha || ""}</td>
          <td>${d.state}</td>
          <td>${d.committed_at || "n/a"}</td>
          <td>${d.completed_at || "n/a"}</td>
          <td>${fmtSeconds(d.lead_time_seconds)}</td>
        </tr>`).join("");
      incidents.innerHTML = data.incidents.map((i) => `
        <tr>
          <td>${i.id}</td>
          <td>${i.severity}</td>
          <td>${i.detected_at}</td>
          <td>${i.restored_at}</td>
          <td>${fmtSeconds(i.mttr_seconds)}</td>
          <td>${i.summary || ""}</td>
        </tr>`).join("") || `<tr><td colspan="6">Sin incidentes registrados.</td></tr>`;
    }
    refresh().catch((error) => {
      document.getElementById("updated").textContent = `Error: ${error.message}`;
    });
    setInterval(() => refresh().catch(console.error), 10000);
  </script>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    server_version = "PetclinicDORA/1.0"

    def send_body(self, status: int, body: str, content_type: str) -> None:
        encoded = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", f"{content_type}; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        try:
            if parsed.path in {"/", "/dashboard"}:
                self.send_body(200, HTML_PAGE, "text/html")
                return
            if parsed.path == "/healthz":
                payload = get_payload()
                stale = "true" if payload.get("stale") else "false"
                self.send_body(200, json.dumps({"ok": True, "stale": stale}), "application/json")
                return
            if parsed.path == "/api/dora":
                force = urllib.parse.parse_qs(parsed.query).get("force", ["0"])[0] == "1"
                self.send_body(200, json.dumps(get_payload(force=force), indent=2), "application/json")
                return
            if parsed.path == "/metrics":
                self.send_body(200, render_metrics(get_payload()), "text/plain")
                return
            self.send_body(404, json.dumps({"error": "not found", "path": html.escape(parsed.path)}), "application/json")
        except (GitHubApiError, OSError, TimeoutError, ValueError, json.JSONDecodeError) as exc:
            self.send_body(502, json.dumps({"ok": False, "error": str(exc)}), "application/json")

    def log_message(self, fmt: str, *args: object) -> None:
        print(f"{datetime.now(timezone.utc).isoformat()} {self.address_string()} {fmt % args}", flush=True)


def main() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Listening on 0.0.0.0:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
