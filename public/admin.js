(function () {
  const TOKEN_KEY = "ca_news_admin_token";

  const I18N = {
    fr: {
      loginTitle: "Console d'administration",
      loginSub: "Club Africain News — Rédaction & Modération",
      passwordLabel: "Mot de passe administrateur",
      loginBtn: "Se connecter",
      backToPublic: "← Retour au site public",
      adminConsole: "Console Rédaction",
      navDashboard: "Tableau de bord",
      navArticles: "Articles & Modération",
      navBanners: "Match & Flash Info",
      navSources: "Sources & Flux RSS",
      navSettings: "Paramètres",
      viewPublicSite: "Voir le site public ↗",
      logoutBtn: "Déconnexion",
      newArticleBtn: "+ Nouvel article",
      collectNowBtn: "↻ Lancer la collecte RSS",
      kpiTotal: "Total articles",
      kpiPublished: "Publiés (Public)",
      kpiHidden: "Masqués / Brouillons",
      kpiFeatured: "À la Une (Épinglés)",
      kpiManual: "Articles rédaction",
      feedsStatusTitle: "État des flux gratuits (RSS / YouTube Atom)",
      admSearchPh: "Rechercher un article, une source...",
      statusAll: "Tous les statuts",
      statusPublished: "Publiés uniquement",
      statusHidden: "Masqués uniquement",
      statusFeatured: "À la Une",
      statusManual: "Rédaction manuelle",
      statusRumor: "Rumeurs",
      topicAll: "Toutes rubriques",
      bulkHideRumors: "Masquer les rumeurs",
      bulkPublishVerified: "Publier officiels & vérifiés",
      bulkPublishAll: "Tout publier",
      publishedBadge: "Publié",
      hiddenBadge: "Masqué",
      featuredBadge: "À la Une",
      manualBadge: "Rédaction",
      btnPublish: "Publier",
      btnHide: "Masquer",
      btnFeature: "★ Une",
      btnUnfeature: "Retirer Une",
      btnEdit: "Modifier",
      btnDelete: "Supprimer",
      confirmDelete: "Supprimer définitivement cet article ?",
      confirmDeleteFeed: "Supprimer ce flux RSS ?",
      collectDone: "Collecte RSS terminée avec succès.",
      savedMsg: "Modifications enregistrées et publiées.",
      lastCollect: "Dernière collecte :"
    },
    ar: {
      loginTitle: "لوحة التحكم والإدارة",
      loginSub: "أخبار النادي الإفريقي — التحرير والمراقبة",
      passwordLabel: "كلمة مرور المدير",
      loginBtn: "تسجيل الدخول",
      backToPublic: "← العودة إلى الموقع العام",
      adminConsole: "لوحة التحرير",
      navDashboard: "لوحة القيادة",
      navArticles: "المقالات والمراقبة",
      navBanners: "المباراة والخبر العاجل",
      navSources: "المصادر وخلاصات RSS",
      navSettings: "الإعدادات",
      viewPublicSite: "معاينة الموقع العام ↗",
      logoutBtn: "تسجيل الخروج",
      newArticleBtn: "+ مقال جديد",
      collectNowBtn: "↻ تشغيل جمع الأخبار",
      kpiTotal: "إجمالي المقالات",
      kpiPublished: "منشورة (للعموم)",
      kpiHidden: "مخفية / مسودة",
      kpiFeatured: "أخبار رئيسية",
      kpiManual: "مقالات التحرير",
      feedsStatusTitle: "حالة الخلاصات المجانية",
      admSearchPh: "ابحث عن مقال أو مصدر...",
      statusAll: "كل الحالات",
      statusPublished: "المنشورة فقط",
      statusHidden: "المخفية فقط",
      statusFeatured: "الأخبار الرئيسية",
      statusManual: "تحرير يدوي",
      statusRumor: "إشاعات",
      topicAll: "كل الأقسام",
      bulkHideRumors: "إخفاء الإشاعات",
      bulkPublishVerified: "نشر الرسمية والموثوقة",
      bulkPublishAll: "نشر الكل",
      publishedBadge: "منشور",
      hiddenBadge: "مخفي",
      featuredBadge: "رئيسي",
      manualBadge: "تحرير",
      btnPublish: "نشر",
      btnHide: "إخفاء",
      btnFeature: "★ رئيسي",
      btnUnfeature: "إزالة الرئيسي",
      btnEdit: "تعديل",
      btnDelete: "حذف",
      confirmDelete: "هل تريد حذف هذا المقال نهائياً؟",
      confirmDeleteFeed: "هل تريد حذف هذه الخلاصة؟",
      collectDone: "تم تحديث الخلاصات بنجاح.",
      savedMsg: "تم حفظ التغييرات وتحديث الموقع.",
      lastCollect: "آخر تجميع:"
    }
  };

  const state = {
    lang: "fr",
    tab: "dashboard",
    token: localStorage.getItem(TOKEN_KEY) || "",
    data: null,
    search: "",
    statusFilter: "all",
    topicFilter: "all",
    langFilter: "all"
  };

  function t(key) {
    return I18N[state.lang][key] || key;
  }

  function escapeHtml(str) {
    return String(str || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function formatDate(iso) {
    if (!iso) return "—";
    try {
      return new Date(iso).toLocaleString(state.lang === "ar" ? "ar-TN" : "fr-TN", {
        day: "2-digit",
        month: "short",
        hour: "2-digit",
        minute: "2-digit"
      });
    } catch {
      return iso;
    }
  }

  function showToast(msg, isError = false) {
    const el = document.getElementById("toast");
    el.textContent = msg;
    el.classList.toggle("is-error", isError);
    el.classList.remove("hidden");
    clearTimeout(state.toastTimer);
    state.toastTimer = setTimeout(() => el.classList.add("hidden"), 4200);
  }

  async function api(path, options = {}) {
    const headers = Object.assign({ "Content-Type": "application/json" }, options.headers || {});
    if (state.token) {
      headers["X-Admin-Token"] = state.token;
    }
    const res = await fetch(path, Object.assign({}, options, { headers }));
    const json = await res.json().catch(() => ({}));
    if (res.status === 401) {
      handleForceLogout();
      throw new Error(json.error || "Session expirée");
    }
    if (!res.ok) {
      throw new Error(json.error || `Erreur HTTP ${res.status}`);
    }
    return json;
  }

  function handleForceLogout() {
    state.token = "";
    localStorage.removeItem(TOKEN_KEY);
    document.getElementById("admin-shell").classList.add("hidden");
    document.getElementById("login-screen").classList.remove("hidden");
  }

  function applyLanguage() {
    document.documentElement.lang = state.lang;
    document.documentElement.dir = state.lang === "ar" ? "rtl" : "ltr";
    document.getElementById("admin-lang-fr").classList.toggle("active", state.lang === "fr");
    document.getElementById("admin-lang-ar").classList.toggle("active", state.lang === "ar");

    document.querySelectorAll("[data-i18n]").forEach((el) => {
      const k = el.getAttribute("data-i18n");
      if (I18N[state.lang][k]) el.textContent = I18N[state.lang][k];
    });
    document.querySelectorAll("[data-i18n-placeholder]").forEach((el) => {
      const k = el.getAttribute("data-i18n-placeholder");
      if (I18N[state.lang][k]) el.setAttribute("placeholder", I18N[state.lang][k]);
    });

    if (state.data) renderAll();
  }

  function renderDashboard() {
    const stats = state.data.stats || {};
    document.getElementById("kpi-total").textContent = stats.total || 0;
    document.getElementById("kpi-published").textContent = stats.published || 0;
    document.getElementById("kpi-hidden").textContent = stats.hidden || 0;
    document.getElementById("kpi-featured").textContent = stats.featured || 0;
    document.getElementById("kpi-manual").textContent = stats.manual || 0;

    document.getElementById("last-collect-info").textContent = state.data.generatedAt
      ? `${t("lastCollect")} ${formatDate(state.data.generatedAt)}`
      : "";

    const feeds = state.data.feeds || [];
    document.getElementById("dashboard-feeds-grid").innerHTML = feeds
      .map((f) => {
        const dotCls = f.enabled === false ? "dot-off" : f.ok ? "dot-ok" : "dot-err";
        return `
          <div class="feed-card">
            <div style="display:flex;justify-content:space-between;align-items:center;">
              <strong><span class="dot ${dotCls}"></span>${escapeHtml(f.id)}</strong>
              <span class="muted-text">${f.keptCount || 0}/${f.fetchedCount || 0}</span>
            </div>
            <div class="muted-text" style="margin-top:4px;">${escapeHtml(f.type)} • ${escapeHtml((f.lang || "").toUpperCase())}</div>
            ${f.error ? `<div style="color:var(--ca-red);font-size:0.76rem;margin-top:4px;">${escapeHtml(f.error)}</div>` : ""}
          </div>
        `;
      })
      .join("");
  }

  function renderArticles() {
    const q = state.search.trim().toLowerCase();
    const items = (state.data.articles || []).filter((a) => {
      if (state.statusFilter === "published" && a.status !== "published") return false;
      if (state.statusFilter === "hidden" && a.status !== "hidden") return false;
      if (state.statusFilter === "featured" && !a.featured) return false;
      if (state.statusFilter === "manual" && !a.isManual) return false;
      if (state.statusFilter === "rumor" && a.verification !== "rumor") return false;
      if (state.topicFilter !== "all" && a.topic !== state.topicFilter) return false;
      if (state.langFilter !== "all" && a.lang !== state.langFilter) return false;
      if (q) {
        const hay = `${a.title} ${a.summary} ${a.sourceName} ${a.sourceNameAr}`.toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });

    document.getElementById("adm-count-label").textContent = `${items.length} / ${(state.data.articles || []).length}`;
    document.getElementById("adm-articles-list").innerHTML = items
      .map((a) => {
        const isPub = a.status === "published";
        return `
          <div class="adm-article-row ${isPub ? "" : "is-hidden-row"}">
            <div class="adm-article-main" dir="${a.lang === "ar" ? "rtl" : "ltr"}">
              <div class="adm-badges">
                <span class="badge ${isPub ? "badge-pub" : "badge-hid"}">${escapeHtml(isPub ? t("publishedBadge") : t("hiddenBadge"))}</span>
                ${a.featured ? `<span class="badge badge-feat">${escapeHtml(t("featuredBadge"))}</span>` : ""}
                ${a.isManual ? `<span class="badge badge-man">${escapeHtml(t("manualBadge"))}</span>` : ""}
                <span class="badge badge-info">${escapeHtml(a.topic)}</span>
                <span class="badge badge-info">${escapeHtml(a.verification)} • ${a.score}/100</span>
                <span class="badge badge-info">${escapeHtml((a.lang || "").toUpperCase())}</span>
              </div>
              <h4>${escapeHtml(a.title)}</h4>
              ${a.summary ? `<p>${escapeHtml(a.summary)}</p>` : ""}
              <div class="muted-text">${escapeHtml(a.sourceName)} • ${escapeHtml(formatDate(a.publishedAt))}</div>
            </div>
            <div class="adm-article-actions">
              <button type="button" class="btn btn-sm ${isPub ? "btn-outline" : "btn-success"}" data-action="toggle-status" data-id="${escapeHtml(a.id)}">
                ${escapeHtml(isPub ? t("btnHide") : t("btnPublish"))}
              </button>
              <button type="button" class="btn btn-sm ${a.featured ? "btn-primary" : "btn-outline"}" data-action="toggle-featured" data-id="${escapeHtml(a.id)}">
                ${escapeHtml(a.featured ? t("btnUnfeature") : t("btnFeature"))}
              </button>
              <button type="button" class="btn btn-sm btn-outline" data-action="edit" data-id="${escapeHtml(a.id)}">${escapeHtml(t("btnEdit"))}</button>
              <button type="button" class="btn btn-sm btn-danger" data-action="delete" data-id="${escapeHtml(a.id)}">${escapeHtml(t("btnDelete"))}</button>
            </div>
          </div>
        `;
      })
      .join("");
  }

  function renderBannersAndSettings() {
    const site = state.data.site || {};
    const mb = site.matchBanner || {};
    const mod = site.moderation || {};

    document.getElementById("cfg-breaking-enabled").checked = Boolean(site.breakingEnabled);
    document.getElementById("cfg-breaking-fr").value = site.breakingFr || "";
    document.getElementById("cfg-breaking-ar").value = site.breakingAr || "";
    document.getElementById("cfg-breaking-url").value = site.breakingUrl || "";

    document.getElementById("cfg-match-enabled").checked = mb.enabled !== false;
    document.getElementById("cfg-match-badge-fr").value = mb.badgeFr || "";
    document.getElementById("cfg-match-badge-ar").value = mb.badgeAr || "";
    document.getElementById("cfg-match-title-fr").value = mb.titleFr || "";
    document.getElementById("cfg-match-title-ar").value = mb.titleAr || "";
    document.getElementById("cfg-match-meta-fr").value = mb.metaFr || "";
    document.getElementById("cfg-match-meta-ar").value = mb.metaAr || "";
    document.getElementById("cfg-match-ticket").value = mb.ticketUrl || "";

    document.getElementById("set-title-fr").value = site.siteTitleFr || "";
    document.getElementById("set-title-ar").value = site.siteTitleAr || "";
    document.getElementById("set-sub-fr").value = site.siteSubtitleFr || "";
    document.getElementById("set-sub-ar").value = site.siteSubtitleAr || "";
    document.getElementById("set-min-score").value = mod.autoPublishMinScore || 0;
    document.getElementById("set-hide-rumors").checked = Boolean(mod.hideRumorsByDefault);
  }

  function renderSourcesAndFeeds() {
    const feeds = state.data.feeds || [];
    document.getElementById("adm-feeds-list").innerHTML = feeds
      .map((f) => {
        const enabled = f.enabled !== false;
        return `
          <div class="adm-feed-row">
            <div>
              <strong>${escapeHtml(f.id)}</strong>
              <span class="badge badge-info">${escapeHtml(f.type)}</span>
              <span class="badge badge-info">${escapeHtml((f.lang || "").toUpperCase())}</span>
              <div class="muted-text">${escapeHtml(f.url)}</div>
            </div>
            <div style="display:flex;gap:6px;align-items:center;">
              <button type="button" class="btn btn-sm ${enabled ? "btn-success" : "btn-outline"}" data-feed-toggle="${escapeHtml(f.id)}" data-enabled="${enabled}">
                ${enabled ? "Actif" : "Inactif"}
              </button>
              <button type="button" class="btn btn-sm btn-danger" data-feed-delete="${escapeHtml(f.id)}">✕</button>
            </div>
          </div>
        `;
      })
      .join("");

    const sources = state.data.sources || [];
    document.getElementById("new-feed-source").innerHTML = sources
      .map((s) => `<option value="${escapeHtml(s.id)}">${escapeHtml(s.name)}</option>`)
      .join("");

    document.getElementById("adm-sources-body").innerHTML = [...sources]
      .sort((a, b) => (b.baseScore || 0) - (a.baseScore || 0))
      .map((s) => `
        <tr>
          <td><strong>${escapeHtml(s.name)}</strong><br><small class="muted-text">${escapeHtml(s.domain)}</small></td>
          <td>${escapeHtml(s.category)}</td>
          <td>${s.F}</td>
          <td>${s.R}</td>
          <td>${s.C}</td>
          <td>${s.D}</td>
          <td>${s.B}</td>
          <td><strong>${s.baseScore}/100</strong></td>
          <td>${s.articleCount || 0}</td>
          <td><button type="button" class="btn btn-sm btn-outline" data-edit-source="${escapeHtml(s.id)}">Modifier</button></td>
        </tr>
      `)
      .join("");
  }

  function renderAll() {
    if (!state.data) return;
    renderDashboard();
    renderArticles();
    renderBannersAndSettings();
    renderSourcesAndFeeds();
  }

  async function loadAdminState() {
    state.data = await api("/api/admin/state");
    document.getElementById("login-screen").classList.add("hidden");
    document.getElementById("admin-shell").classList.remove("hidden");
    renderAll();
  }

  function openArticleModal(article = null) {
    document.getElementById("editor-modal-title").textContent = article ? "Modifier l'article" : "Nouvel article rédactionnel";
    document.getElementById("edit-art-id").value = article ? article.id : "";
    document.getElementById("edit-art-title").value = article ? article.title : "";
    document.getElementById("edit-art-summary").value = article ? (article.summary || "") : "";
    document.getElementById("edit-art-body").value = article ? (article.body || "") : "";
    document.getElementById("edit-art-topic").value = article ? (article.topic || "official") : "official";
    document.getElementById("edit-art-lang").value = article ? (article.lang || "fr") : "fr";
    document.getElementById("edit-art-verif").value = article ? (article.verification || "official") : "official";
    document.getElementById("edit-art-status").value = article ? (article.status || "published") : "published";
    document.getElementById("edit-art-url").value = article ? (article.url || "") : "";
    document.getElementById("edit-art-thumb").value = article ? (article.thumbnail || "") : "";
    document.getElementById("edit-art-featured").checked = article ? Boolean(article.featured) : false;
    document.getElementById("article-editor-modal").classList.remove("hidden");
  }

  function openSourceModal(src) {
    document.getElementById("edit-src-id").value = src.id;
    document.getElementById("edit-src-name").value = src.name || "";
    document.getElementById("edit-src-name-ar").value = src.nameAr || "";
    document.getElementById("edit-src-f").value = src.F;
    document.getElementById("edit-src-r").value = src.R;
    document.getElementById("edit-src-c").value = src.C;
    document.getElementById("edit-src-d").value = src.D;
    document.getElementById("edit-src-b").value = src.B;
    document.getElementById("source-editor-modal").classList.remove("hidden");
  }

  // --- Event Listeners ---
  document.getElementById("login-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const errEl = document.getElementById("login-error");
    errEl.classList.add("hidden");
    try {
      const password = document.getElementById("login-password").value;
      const res = await api("/api/admin/login", {
        method: "POST",
        body: JSON.stringify({ password })
      });
      state.token = res.token;
      localStorage.setItem(TOKEN_KEY, state.token);
      document.getElementById("login-password").value = "";
      await loadAdminState();
    } catch (err) {
      errEl.textContent = err.message;
      errEl.classList.remove("hidden");
    }
  });

  document.getElementById("btn-logout").addEventListener("click", async () => {
    try { await api("/api/admin/logout", { method: "POST" }); } catch {}
    handleForceLogout();
  });

  document.getElementById("admin-lang-fr").addEventListener("click", () => { state.lang = "fr"; applyLanguage(); });
  document.getElementById("admin-lang-ar").addEventListener("click", () => { state.lang = "ar"; applyLanguage(); });

  document.querySelectorAll(".side-nav-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      state.tab = btn.getAttribute("data-tab");
      document.querySelectorAll(".side-nav-btn").forEach((b) => b.classList.toggle("active", b === btn));
      document.querySelectorAll(".admin-tab").forEach((sec) => sec.classList.toggle("active", sec.id === `tab-${state.tab}`));
      document.getElementById("page-title").textContent = btn.textContent;
    });
  });

  document.getElementById("btn-collect-now").addEventListener("click", async (e) => {
    const btn = e.currentTarget;
    btn.disabled = true;
    try {
      state.data = await api("/api/admin/collect", { method: "POST" });
      renderAll();
      showToast(t("collectDone"));
    } catch (err) {
      showToast(err.message, true);
    } finally {
      btn.disabled = false;
    }
  });

  document.getElementById("btn-new-article-top").addEventListener("click", () => openArticleModal(null));

  document.getElementById("adm-search").addEventListener("input", (e) => { state.search = e.target.value; renderArticles(); });
  document.getElementById("adm-status-filter").addEventListener("change", (e) => { state.statusFilter = e.target.value; renderArticles(); });
  document.getElementById("adm-topic-filter").addEventListener("change", (e) => { state.topicFilter = e.target.value; renderArticles(); });
  document.getElementById("adm-lang-filter").addEventListener("change", (e) => { state.langFilter = e.target.value; renderArticles(); });

  document.querySelectorAll("[data-bulk]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      try {
        state.data = await api("/api/admin/articles/bulk", {
          method: "POST",
          body: JSON.stringify({ action: btn.getAttribute("data-bulk") })
        });
        renderAll();
        showToast(t("savedMsg"));
      } catch (err) {
        showToast(err.message, true);
      }
    });
  });

  document.getElementById("adm-articles-list").addEventListener("click", async (e) => {
    const btn = e.target.closest("[data-action]");
    if (!btn) return;
    const id = btn.getAttribute("data-id");
    const action = btn.getAttribute("data-action");
    const art = (state.data.articles || []).find((a) => a.id === id);
    if (!art) return;

    try {
      if (action === "toggle-status") {
        const nextStatus = art.status === "published" ? "hidden" : "published";
        state.data = await api(`/api/admin/articles/${encodeURIComponent(id)}`, {
          method: "PUT",
          body: JSON.stringify({ status: nextStatus })
        });
        renderAll();
        showToast(t("savedMsg"));
      } else if (action === "toggle-featured") {
        state.data = await api(`/api/admin/articles/${encodeURIComponent(id)}`, {
          method: "PUT",
          body: JSON.stringify({ featured: !art.featured })
        });
        renderAll();
        showToast(t("savedMsg"));
      } else if (action === "edit") {
        openArticleModal(art);
      } else if (action === "delete") {
        if (!confirm(t("confirmDelete"))) return;
        state.data = await api(`/api/admin/articles/${encodeURIComponent(id)}`, { method: "DELETE" });
        renderAll();
        showToast(t("savedMsg"));
      }
    } catch (err) {
      showToast(err.message, true);
    }
  });

  document.getElementById("article-editor-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const id = document.getElementById("edit-art-id").value;
    const payload = {
      title: document.getElementById("edit-art-title").value.trim(),
      summary: document.getElementById("edit-art-summary").value.trim(),
      body: document.getElementById("edit-art-body").value.trim(),
      topic: document.getElementById("edit-art-topic").value,
      lang: document.getElementById("edit-art-lang").value,
      verification: document.getElementById("edit-art-verif").value,
      status: document.getElementById("edit-art-status").value,
      url: document.getElementById("edit-art-url").value.trim(),
      thumbnail: document.getElementById("edit-art-thumb").value.trim(),
      featured: document.getElementById("edit-art-featured").checked
    };

    try {
      if (id) {
        state.data = await api(`/api/admin/articles/${encodeURIComponent(id)}`, {
          method: "PUT",
          body: JSON.stringify(payload)
        });
      } else {
        state.data = await api("/api/admin/articles", {
          method: "POST",
          body: JSON.stringify(payload)
        });
      }
      document.getElementById("article-editor-modal").classList.add("hidden");
      renderAll();
      showToast(t("savedMsg"));
    } catch (err) {
      showToast(err.message, true);
    }
  });

  ["editor-close", "editor-cancel"].forEach((cid) => {
    document.getElementById(cid).addEventListener("click", () => {
      document.getElementById("article-editor-modal").classList.add("hidden");
    });
  });

  document.getElementById("banners-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    try {
      state.data = await api("/api/admin/site", {
        method: "PUT",
        body: JSON.stringify({
          breakingEnabled: document.getElementById("cfg-breaking-enabled").checked,
          breakingFr: document.getElementById("cfg-breaking-fr").value.trim(),
          breakingAr: document.getElementById("cfg-breaking-ar").value.trim(),
          breakingUrl: document.getElementById("cfg-breaking-url").value.trim(),
          matchBanner: {
            enabled: document.getElementById("cfg-match-enabled").checked,
            badgeFr: document.getElementById("cfg-match-badge-fr").value.trim(),
            badgeAr: document.getElementById("cfg-match-badge-ar").value.trim(),
            titleFr: document.getElementById("cfg-match-title-fr").value.trim(),
            titleAr: document.getElementById("cfg-match-title-ar").value.trim(),
            metaFr: document.getElementById("cfg-match-meta-fr").value.trim(),
            metaAr: document.getElementById("cfg-match-meta-ar").value.trim(),
            ticketUrl: document.getElementById("cfg-match-ticket").value.trim()
          }
        })
      });
      renderAll();
      showToast(t("savedMsg"));
    } catch (err) {
      showToast(err.message, true);
    }
  });

  document.getElementById("settings-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const newPassword = document.getElementById("set-new-password").value;
    try {
      state.data = await api("/api/admin/site", {
        method: "PUT",
        body: JSON.stringify({
          siteTitleFr: document.getElementById("set-title-fr").value.trim(),
          siteTitleAr: document.getElementById("set-title-ar").value.trim(),
          siteSubtitleFr: document.getElementById("set-sub-fr").value.trim(),
          siteSubtitleAr: document.getElementById("set-sub-ar").value.trim(),
          moderation: {
            autoPublishMinScore: Number(document.getElementById("set-min-score").value || 0),
            hideRumorsByDefault: document.getElementById("set-hide-rumors").checked
          },
          newPassword: newPassword || undefined
        })
      });
      document.getElementById("set-new-password").value = "";
      renderAll();
      showToast(t("savedMsg"));
    } catch (err) {
      showToast(err.message, true);
    }
  });

  document.getElementById("add-feed-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    try {
      state.data = await api("/api/admin/feeds", {
        method: "POST",
        body: JSON.stringify({
          id: document.getElementById("new-feed-id").value.trim(),
          type: document.getElementById("new-feed-type").value,
          lang: document.getElementById("new-feed-lang").value,
          sourceId: document.getElementById("new-feed-source").value,
          url: document.getElementById("new-feed-url").value.trim(),
          filterRequired: true
        })
      });
      document.getElementById("new-feed-id").value = "";
      document.getElementById("new-feed-url").value = "";
      renderAll();
      showToast(t("savedMsg"));
    } catch (err) {
      showToast(err.message, true);
    }
  });

  document.getElementById("adm-feeds-list").addEventListener("click", async (e) => {
    const toggleBtn = e.target.closest("[data-feed-toggle]");
    if (toggleBtn) {
      const id = toggleBtn.getAttribute("data-feed-toggle");
      const current = toggleBtn.getAttribute("data-enabled") === "true";
      try {
        state.data = await api(`/api/admin/feeds/${encodeURIComponent(id)}`, {
          method: "PUT",
          body: JSON.stringify({ enabled: !current })
        });
        renderAll();
        showToast(t("savedMsg"));
      } catch (err) { showToast(err.message, true); }
      return;
    }

    const delBtn = e.target.closest("[data-feed-delete]");
    if (delBtn) {
      if (!confirm(t("confirmDeleteFeed"))) return;
      const id = delBtn.getAttribute("data-feed-delete");
      try {
        state.data = await api(`/api/admin/feeds/${encodeURIComponent(id)}`, { method: "DELETE" });
        renderAll();
        showToast(t("savedMsg"));
      } catch (err) { showToast(err.message, true); }
    }
  });

  document.getElementById("adm-sources-body").addEventListener("click", (e) => {
    const btn = e.target.closest("[data-edit-source]");
    if (!btn) return;
    const src = (state.data.sources || []).find((s) => s.id === btn.getAttribute("data-edit-source"));
    if (src) openSourceModal(src);
  });

  document.getElementById("source-editor-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const id = document.getElementById("edit-src-id").value;
    try {
      state.data = await api(`/api/admin/sources/${encodeURIComponent(id)}`, {
        method: "PUT",
        body: JSON.stringify({
          name: document.getElementById("edit-src-name").value.trim(),
          nameAr: document.getElementById("edit-src-name-ar").value.trim(),
          F: Number(document.getElementById("edit-src-f").value),
          R: Number(document.getElementById("edit-src-r").value),
          C: Number(document.getElementById("edit-src-c").value),
          D: Number(document.getElementById("edit-src-d").value),
          B: Number(document.getElementById("edit-src-b").value)
        })
      });
      document.getElementById("source-editor-modal").classList.add("hidden");
      renderAll();
      showToast(t("savedMsg"));
    } catch (err) {
      showToast(err.message, true);
    }
  });

  ["source-close", "source-cancel"].forEach((cid) => {
    document.getElementById(cid).addEventListener("click", () => {
      document.getElementById("source-editor-modal").classList.add("hidden");
    });
  });

  // Boot
  applyLanguage();
  if (state.token) {
    loadAdminState().catch(() => {});
  }
})();
