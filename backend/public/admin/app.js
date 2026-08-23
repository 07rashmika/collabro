(() => {
  "use strict";

  const TOKEN_KEY = "collabro_admin_token";
  const PAGE_LIMIT = 20;

  const state = {
    tab: "dashboard",
    users: { page: 1, search: "", status: "" },
    sessions: { page: 1, search: "", category: "ONGOING" },
    reports: { page: 1, status: "PENDING", targetType: "" },
  };

  // ---------- helpers ----------

  function esc(value) {
    const div = document.createElement("div");
    div.textContent = value ?? "";
    return div.innerHTML;
  }

  function formatDate(value) {
    if (!value) return "—";
    const d = new Date(value);
    return d.toLocaleString(undefined, {
      dateStyle: "medium",
      timeStyle: "short",
    });
  }

  function toast(message, isError = false) {
    const el = document.getElementById("toast");
    el.textContent = message;
    el.className = "toast" + (isError ? " error" : "");
    el.hidden = false;
    clearTimeout(toast._t);
    toast._t = setTimeout(() => {
      el.hidden = true;
    }, 3200);
  }

  function debounce(fn, ms) {
    let t;
    return (...args) => {
      clearTimeout(t);
      t = setTimeout(() => fn(...args), ms);
    };
  }

  function getToken() {
    return localStorage.getItem(TOKEN_KEY);
  }

  function setToken(token) {
    localStorage.setItem(TOKEN_KEY, token);
  }

  function clearToken() {
    localStorage.removeItem(TOKEN_KEY);
  }

  async function api(path, options = {}) {
    const token = getToken();
    const res = await fetch(path, {
      ...options,
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(options.headers || {}),
      },
    });

    if (res.status === 401) {
      clearToken();
      showLogin();
      throw new Error("Session expired. Please sign in again.");
    }

    let body = null;
    try {
      body = await res.json();
    } catch {
      // no body
    }

    if (!res.ok) {
      throw new Error(body?.message || `Request failed (${res.status})`);
    }

    return body;
  }

  function qs(params) {
    const usp = new URLSearchParams();
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== null && value !== "") {
        usp.set(key, value);
      }
    }
    const s = usp.toString();
    return s ? `?${s}` : "";
  }

  function renderPagination(containerId, { page, limit, total }, onChange) {
    const container = document.getElementById(containerId);
    const totalPages = Math.max(1, Math.ceil(total / limit));
    container.innerHTML = "";

    const prev = document.createElement("button");
    prev.textContent = "Prev";
    prev.disabled = page <= 1;
    prev.onclick = () => onChange(page - 1);

    const next = document.createElement("button");
    next.textContent = "Next";
    next.disabled = page >= totalPages;
    next.onclick = () => onChange(page + 1);

    const label = document.createElement("span");
    label.textContent = `Page ${page} of ${totalPages} · ${total} total`;

    container.append(prev, label, next);
  }

  // ---------- auth ----------

  function showLogin() {
    document.getElementById("login-screen").hidden = false;
    document.getElementById("app-shell").hidden = true;
  }

  function showApp() {
    document.getElementById("login-screen").hidden = true;
    document.getElementById("app-shell").hidden = false;
    loadTab(state.tab);
  }

  document
    .getElementById("login-form")
    .addEventListener("submit", async (e) => {
      e.preventDefault();
      const email = document.getElementById("login-email").value.trim();
      const password = document.getElementById("login-password").value;
      const errorEl = document.getElementById("login-error");
      const submitBtn = document.getElementById("login-submit");

      errorEl.hidden = true;
      submitBtn.disabled = true;
      submitBtn.textContent = "Signing in…";

      try {
        const result = await api("/api/admin/login", {
          method: "POST",
          body: JSON.stringify({ email, password }),
        });
        setToken(result.token);
        showApp();
      } catch (err) {
        errorEl.textContent = err.message;
        errorEl.hidden = false;
      } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = "Sign In";
      }
    });

  document.getElementById("logout-btn").addEventListener("click", () => {
    clearToken();
    showLogin();
  });

  // ---------- tab navigation ----------

  document.querySelectorAll(".nav-item").forEach((btn) => {
    btn.addEventListener("click", () => {
      document
        .querySelectorAll(".nav-item")
        .forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");
      document.querySelectorAll(".tab-panel").forEach((p) => (p.hidden = true));
      const tab = btn.dataset.tab;
      document.getElementById(`tab-${tab}`).hidden = false;
      state.tab = tab;
      loadTab(tab);
    });
  });

  function loadTab(tab) {
    if (tab === "dashboard") return loadDashboard();
    if (tab === "users") return loadUsers();
    if (tab === "sessions") return loadSessions();
    if (tab === "reports") return loadReports();
  }

  // ---------- dashboard ----------

  async function loadDashboard() {
    try {
      const stats = await api("/api/admin/dashboard");
      const grid = document.getElementById("stat-grid");
      grid.innerHTML = "";
      const cards = [
        { label: "Total users", value: stats.users.total },
        {
          label: "Suspended users",
          value: stats.users.suspended,
          tone: "danger",
        },
        {
          label: "Ongoing sessions",
          value: stats.sessions.ongoing,
          tone: "accent",
        },
        { label: "Upcoming sessions", value: stats.sessions.upcoming },
        { label: "Ended sessions", value: stats.sessions.ended },
        {
          label: "Pending reports",
          value: stats.reports.pendingTotal,
          tone: "warn",
        },
        { label: "Pending - sessions", value: stats.reports.pendingSession },
        { label: "Pending - users", value: stats.reports.pendingUser },
        { label: "Reviewed reports", value: stats.reports.reviewed },
        { label: "Dismissed reports", value: stats.reports.dismissed },
      ];
      for (const c of cards) {
        const card = document.createElement("div");
        card.className = "stat-card" + (c.tone ? ` ${c.tone}` : "");
        card.innerHTML = `<div class="value">${c.value}</div><div class="label">${esc(c.label)}</div>`;
        grid.append(card);
      }
    } catch (err) {
      toast(err.message, true);
    }
  }

  // ---------- users ----------

  const usersSearchInput = document.getElementById("users-search");
  const usersStatusFilter = document.getElementById("users-status-filter");

  usersSearchInput.addEventListener(
    "input",
    debounce(() => {
      state.users.search = usersSearchInput.value.trim();
      state.users.page = 1;
      loadUsers();
    }, 300),
  );

  usersStatusFilter.addEventListener("change", () => {
    state.users.status = usersStatusFilter.value;
    state.users.page = 1;
    loadUsers();
  });

  async function loadUsers() {
    const tbody = document.getElementById("users-tbody");
    try {
      const { search, status, page } = state.users;
      const result = await api(
        `/api/admin/users${qs({ search, status, page, limit: PAGE_LIMIT })}`,
      );
      tbody.innerHTML = "";

      if (result.users.length === 0) {
        tbody.innerHTML = `<tr class="empty-row"><td colspan="8">No users found.</td></tr>`;
      }

      for (const u of result.users) {
        const tr = document.createElement("tr");
        tr.innerHTML = `
          <td>${esc(u.name)}</td>
          <td>${esc(u.email)}</td>
          <td>
            ${
              u.isSuspended
                ? `<span class="badge suspended" title="${esc(u.suspendedReason || "")}">Suspended</span>`
                : `<span class="badge active">Active</span>`
            }
          </td>
          <td>${u._count.createdSessions}</td>
          <td>${u._count.submittedReports}</td>
          <td>${u._count.reportsReceived}</td>
          <td>${formatDate(u.createdAt)}</td>
          <td></td>
        `;
        const actionCell = tr.lastElementChild;
        const btn = document.createElement("button");
        if (u.isSuspended) {
          btn.className = "btn small";
          btn.textContent = "Unsuspend";
          btn.onclick = () => unsuspendUser(u.id);
        } else {
          btn.className = "btn small danger";
          btn.textContent = "Suspend";
          btn.onclick = () => suspendUser(u.id);
        }
        actionCell.append(btn);
        tbody.append(tr);
      }

      renderPagination("users-pagination", result, (page) => {
        state.users.page = page;
        loadUsers();
      });
    } catch (err) {
      toast(err.message, true);
    }
  }

  async function suspendUser(userId, reportId) {
    const reason =
      window.prompt("Reason for suspension (optional):", "") ?? undefined;
    try {
      await api(`/api/admin/users/${userId}/suspend`, {
        method: "PATCH",
        body: JSON.stringify({ reason: reason || undefined, reportId }),
      });
      toast("User suspended.");
      loadTab(state.tab);
    } catch (err) {
      toast(err.message, true);
    }
  }

  async function unsuspendUser(userId) {
    try {
      await api(`/api/admin/users/${userId}/unsuspend`, { method: "PATCH" });
      toast("User unsuspended.");
      loadTab(state.tab);
    } catch (err) {
      toast(err.message, true);
    }
  }

  // ---------- sessions ----------

  const sessionsSearchInput = document.getElementById("sessions-search");
  sessionsSearchInput.addEventListener(
    "input",
    debounce(() => {
      state.sessions.search = sessionsSearchInput.value.trim();
      state.sessions.page = 1;
      loadSessions();
    }, 300),
  );

  document.querySelectorAll("#tab-sessions .subtab-item").forEach((btn) => {
    btn.addEventListener("click", () => {
      document
        .querySelectorAll("#tab-sessions .subtab-item")
        .forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");
      state.sessions.category = btn.dataset.category;
      state.sessions.page = 1;
      loadSessions();
    });
  });

  async function loadSessions() {
    const tbody = document.getElementById("sessions-tbody");
    try {
      const { search, category, page } = state.sessions;
      const result = await api(
        `/api/admin/sessions${qs({ category, search, page, limit: PAGE_LIMIT })}`,
      );
      tbody.innerHTML = "";

      if (result.sessions.length === 0) {
        tbody.innerHTML = `<tr class="empty-row"><td colspan="7">No sessions in this category.</td></tr>`;
      }

      for (const s of result.sessions) {
        const tr = document.createElement("tr");
        tr.innerHTML = `
          <td>${esc(s.title)}</td>
          <td>${s.type === "VIDEO" ? "Video" : "Text"}</td>
          <td>${esc(s.creator.name)} <span style="color:var(--text-tertiary)">(${esc(s.creator.email)})</span></td>
          <td>${s._count.participants}</td>
          <td>${s.isPublic ? "Public" : "Private"}</td>
          <td>${formatDate(s.scheduledAt || s.createdAt)}</td>
          <td>${s.status === "CLOSED" ? "—" : formatDate(s.expiresAt)}</td>
        `;
        tbody.append(tr);
      }

      renderPagination("sessions-pagination", result, (page) => {
        state.sessions.page = page;
        loadSessions();
      });
    } catch (err) {
      toast(err.message, true);
    }
  }

  // ---------- reports ----------

  document
    .getElementById("reports-status-filter")
    .addEventListener("change", (e) => {
      state.reports.status = e.target.value;
      state.reports.page = 1;
      loadReports();
    });

  document.querySelectorAll("#tab-reports .subtab-item").forEach((btn) => {
    btn.addEventListener("click", () => {
      document
        .querySelectorAll("#tab-reports .subtab-item")
        .forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");
      state.reports.targetType = btn.dataset.targetType;
      state.reports.page = 1;
      loadReports();
    });
  });

  const REASON_LABELS = {
    SPAM_OR_ADVERTISING: "Spam or advertising",
    HARASSMENT_OR_BULLYING: "Harassment or bullying",
    HATE_SPEECH_OR_DISCRIMINATION: "Hate speech or discrimination",
    INAPPROPRIATE_CONTENT: "Inappropriate content",
    ACADEMIC_DISHONESTY: "Academic dishonesty (cheating)",
    IMPERSONATION_OR_FAKE_PROFILE: "Impersonation or fake profile",
    SCAM_OR_PHISHING: "Scam or phishing",
    OTHER: "Other",
  };

  async function loadReports() {
    const list = document.getElementById("reports-list");
    try {
      const { status, targetType, page } = state.reports;
      const result = await api(
        `/api/admin/reports${qs({ status, targetType, page, limit: PAGE_LIMIT })}`,
      );
      list.innerHTML = "";

      if (result.reports.length === 0) {
        list.innerHTML = `<div class="empty-state">No reports match this filter.</div>`;
      }

      for (const r of result.reports) {
        const card = document.createElement("div");
        card.className = "report-card";

        const target =
          r.targetType === "SESSION"
            ? `Session: <strong>${esc(r.session?.title ?? "(deleted)")}</strong>`
            : `User: <strong>${esc(r.reportedUser?.name ?? "(deleted)")}</strong> (${esc(r.reportedUser?.email ?? "")})`;

        const statusClass =
          r.status === "PENDING"
            ? "pending"
            : r.status === "REVIEWED"
              ? "reviewed"
              : "dismissed";

        card.innerHTML = `
          <div class="report-top">
            <div>
              <span class="report-type-chip">${r.targetType}</span>
              <span class="badge ${statusClass}" style="margin-left:8px">${r.status}</span>
            </div>
            <div class="report-meta">${formatDate(r.createdAt)}</div>
          </div>
          <div class="report-meta">Reported by ${esc(r.reporter.name)} (${esc(r.reporter.email)})</div>
          <div class="report-meta">${target}${r.targetType === "USER" && r.reportedUser?.isSuspended ? ' · <span class="badge suspended">Already suspended</span>' : ""}</div>
          <div class="report-reason">${REASON_LABELS[r.reason] || r.reason}</div>
          ${r.details ? `<div class="report-details">"${esc(r.details)}"</div>` : ""}
          <div class="report-actions"></div>
        `;

        const actions = card.querySelector(".report-actions");

        if (r.status === "PENDING") {
          const reviewBtn = document.createElement("button");
          reviewBtn.className = "btn small";
          reviewBtn.textContent = "Mark Reviewed";
          reviewBtn.onclick = () => updateReportStatus(r.id, "REVIEWED");
          actions.append(reviewBtn);

          const dismissBtn = document.createElement("button");
          dismissBtn.className = "btn small";
          dismissBtn.textContent = "Dismiss";
          dismissBtn.onclick = () => updateReportStatus(r.id, "DISMISSED");
          actions.append(dismissBtn);

          if (
            r.targetType === "USER" &&
            r.reportedUser &&
            !r.reportedUser.isSuspended
          ) {
            const suspendBtn = document.createElement("button");
            suspendBtn.className = "btn small danger";
            suspendBtn.textContent = "Suspend User";
            suspendBtn.onclick = () => suspendUser(r.reportedUser.id, r.id);
            actions.append(suspendBtn);
          }
        }

        list.append(card);
      }

      renderPagination("reports-pagination", result, (page) => {
        state.reports.page = page;
        loadReports();
      });
    } catch (err) {
      toast(err.message, true);
    }
  }

  async function updateReportStatus(reportId, status) {
    try {
      await api(`/api/admin/reports/${reportId}`, {
        method: "PATCH",
        body: JSON.stringify({ status }),
      });
      toast(`Report marked ${status.toLowerCase()}.`);
      loadReports();
    } catch (err) {
      toast(err.message, true);
    }
  }

  // ---------- boot ----------

  document.getElementById("reports-status-filter").value = state.reports.status;

  if (getToken()) {
    showApp();
  } else {
    showLogin();
  }
})();
