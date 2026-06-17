(function () {
  "use strict";

  const config = window.PETCLINIC_CONFIG || {};
  const backendBaseUrl = normalizeUrl(config.backendBaseUrl);
  const environment = config.environment || "production";
  const gitSha = config.gitSha || "";
  const deployedAt = config.deployedAt || "";

  const elements = {
    backendLink: document.getElementById("backend-link"),
    healthLink: document.getElementById("health-link"),
    openApp: document.getElementById("open-app"),
    findOwners: document.getElementById("find-owners"),
    refreshHealth: document.getElementById("refresh-health"),
    statusDot: document.getElementById("status-dot"),
    statusLabel: document.getElementById("status-label"),
    statusDetail: document.getElementById("status-detail"),
    backendHost: document.getElementById("backend-host"),
    environmentLabel: document.getElementById("environment-label"),
    buildLabel: document.getElementById("build-label"),
    frontendUrl: document.getElementById("frontend-url")
  };

  elements.environmentLabel.textContent = environment;
  elements.frontendUrl.textContent = window.location.origin + window.location.pathname;
  elements.buildLabel.textContent = buildText(gitSha, deployedAt);

  if (backendBaseUrl) {
    const healthUrl = backendBaseUrl + "/actuator/health";
    const ownersPageUrl = frontendRouteUrl("owners/index.html");

    setLink(elements.backendLink, ownersPageUrl);
    setLink(elements.healthLink, healthUrl);
    setLink(elements.openApp, ownersPageUrl);
    setLink(elements.findOwners, ownersPageUrl);
    elements.backendHost.textContent = new URL(backendBaseUrl).host;
    if (canFetchFromCurrentPage(healthUrl)) {
      checkHealth(healthUrl);
    }
    else {
      setStatus("", "Petclinic enlazado", "Abra Petclinic para acceder al entorno publicado.");
    }
  }
  else {
    setStatus("bad", "Backend no configurado", "Defina FRONTEND_BACKEND_BASE_URL para enlazar la API.");
  }

  elements.refreshHealth.addEventListener("click", function () {
    if (!backendBaseUrl) {
      setStatus("bad", "Backend no configurado", "No hay URL publica para consultar.");
      return;
    }
    const healthUrl = backendBaseUrl + "/actuator/health";
    if (!canFetchFromCurrentPage(healthUrl)) {
      setStatus("", "Health no consultable", "El navegador bloquea health HTTP desde una pagina HTTPS.");
      return;
    }
    checkHealth(healthUrl);
  });

  function normalizeUrl(value) {
    if (!value || typeof value !== "string") {
      return "";
    }
    if (value === "same-origin") {
      return window.location.origin;
    }
    try {
      const parsed = new URL(value);
      if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
        return "";
      }
      return parsed.href.replace(/\/+$/, "");
    }
    catch (error) {
      return "";
    }
  }

  function setLink(element, url) {
    element.href = url;
    element.removeAttribute("aria-disabled");
  }

  function frontendRouteUrl(path) {
    const basePath = normalizeBasePath(config.frontendBasePath);
    return window.location.origin + basePath + path.replace(/^\/+/, "");
  }

  function normalizeBasePath(value) {
    if (!value || typeof value !== "string") {
      return currentBasePath();
    }
    const trimmed = value.trim();
    if (!trimmed) {
      return currentBasePath();
    }
    const withLeadingSlash = trimmed.charAt(0) === "/" ? trimmed : "/" + trimmed;
    return withLeadingSlash.endsWith("/") ? withLeadingSlash : withLeadingSlash + "/";
  }

  function currentBasePath() {
    const path = window.location.pathname;
    if (path.endsWith("/")) {
      return path;
    }
    return path.slice(0, path.lastIndexOf("/") + 1) || "/";
  }

  function canFetchFromCurrentPage(url) {
    const target = new URL(url);
    return !(window.location.protocol === "https:" && target.protocol === "http:");
  }

  function buildText(sha, date) {
    const shortSha = sha ? sha.slice(0, 7) : "local";
    if (!date) {
      return "Build " + shortSha;
    }
    return "Build " + shortSha + " - " + date;
  }

  async function checkHealth(url) {
    setStatus("", "Verificando backend", "Consultando /actuator/health.");
    try {
      const response = await fetch(url, {
        cache: "no-store",
        headers: {
          "Accept": "application/json"
        }
      });
      if (!response.ok) {
        throw new Error("HTTP " + response.status);
      }
      const payload = await response.json();
      if (payload.status === "UP") {
        setStatus("ok", "Backend operativo", "Actuator health reporta UP.");
      }
      else {
        setStatus("bad", "Backend degradado", "Estado recibido: " + (payload.status || "desconocido"));
      }
    }
    catch (error) {
      setStatus("bad", "Backend no disponible", "No fue posible consultar el health endpoint.");
    }
  }

  function setStatus(kind, label, detail) {
    elements.statusDot.className = "status-dot";
    if (kind) {
      elements.statusDot.classList.add(kind);
    }
    elements.statusLabel.textContent = label;
    elements.statusDetail.textContent = detail;
  }
}());
