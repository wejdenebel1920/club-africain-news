(function () {
  const I18N = {
    fr: {
      breakingLabel: "FLASH INFO",
      adminLink: "Administration",
      adminFooterLink: "Console d'administration",
      topicAll: "À la Une",
      topicCaf: "Ligue des Champions CAF",
      topicLigue1: "Ligue 1 & Coupes",
      topicSquad: "Effectif & Infirmerie",
      topicMercato: "Mercato",
      topicOfficial: "Officiel & Vidéos",
      ticketCta: "Billetterie officielle ↗",
      featuredTitle: "À la Une",
      latestNewsTitle: "Toute l'actualité football",
      searchPlaceholder: "Rechercher un joueur, un match, une actu...",
      langAll: "Toutes les langues (FR + AR)",
      langFrOnly: "Français uniquement",
      langArOnly: "العربية فقط",
      sortFeatured: "Pertinence & À la Une",
      sortDate: "Plus récents d'abord",
      loadMore: "Charger plus d'articles",
      videosTitle: "Vidéos Officielles CA",
      videosDesc: "Dernières publications de la chaîne officielle du club.",
      officialHubTitle: "Canaux Officiels & Stats",
      officialHubDesc: "Accès direct aux pages officielles du Club Africain et aux résultats en direct.",
      footerNote: "Club Africain News — Portail d'actualités football (FR / عربي).",
      featuredBadge: "À la Une",
      readArticle: "Lire l'article",
      openSource: "Lire sur la source ↗",
      updatedAt: "Mis à jour :",
      articlesUnit: "articles",
      noResults: "Aucune actualité ne correspond à votre recherche.",
      verif: {
        official: "Officiel",
        verified: "Vérifié",
        press: "Presse",
        rumor: "À confirmer"
      },
      topics: {
        caf: "CAF CL",
        ligue1: "Ligue 1 / Coupes",
        squad: "Effectif",
        mercato: "Mercato",
        official: "Officiel"
      }
    },
    ar: {
      breakingLabel: "خبر عاجل",
      adminLink: "الإدارة",
      adminFooterLink: "لوحة التحكم والإدارة",
      topicAll: "الرئيسية",
      topicCaf: "دوري أبطال إفريقيا",
      topicLigue1: "البطولة والكأس",
      topicSquad: "الرصيد البشري والإصابات",
      topicMercato: "الميركاتو",
      topicOfficial: "رسمي وفيديوهات",
      ticketCta: "بوابة التذاكر الرسمية ↗",
      featuredTitle: "أبرز الأخبار",
      latestNewsTitle: "كل أخبار كرة القدم",
      searchPlaceholder: "ابحث عن لاعب، مباراة، خبر...",
      langAll: "كل اللغات (عربي + فرنسي)",
      langFrOnly: "الفرنسية فقط",
      langArOnly: "العربية فقط",
      sortFeatured: "الأهم والأبرز",
      sortDate: "الأحدث أولاً",
      loadMore: "تحميل المزيد من الأخبار",
      videosTitle: "فيديوهات النادي الرسمية",
      videosDesc: "أحدث منشورات القناة الرسمية للنادي الإفريقي.",
      officialHubTitle: "القنوات الرسمية والإحصائيات",
      officialHubDesc: "روابط مباشرة للصفحات الرسمية للنادي ونتائج المباريات.",
      footerNote: "أخبار النادي الإفريقي — بوابة أخبار كرة القدم (عربي / FR).",
      featuredBadge: "خبر رئيسي",
      readArticle: "قراءة المقال",
      openSource: "قراءة من المصدر ↗",
      updatedAt: "آخر تحديث:",
      articlesUnit: "خبر",
      noResults: "لا توجد أخبار مطابقة لبحثك.",
      verif: {
        official: "رسمي",
        verified: "موثوق",
        press: "صحافة",
        rumor: "قيد التأكيد"
      },
      topics: {
        caf: "أبطال إفريقيا",
        ligue1: "البطولة والكأس",
        squad: "الفريق",
        mercato: "ميركاتو",
        official: "رسمي"
      }
    }
  };

  const PAGE_SIZE = 24;

  const state = {
    uiLang: "fr",
    topic: "all",
    articleLang: "all",
    sortBy: "featured",
    query: "",
    limit: PAGE_SIZE,
    data: window.__CA_NEWS_DATA__ || { articles: [], officialLinks: [], site: {}, generatedAt: "" }
  };

  function t(key) {
    return I18N[state.uiLang][key] || key;
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
      const d = new Date(iso);
      return d.toLocaleString(state.uiLang === "ar" ? "ar-TN" : "fr-TN", {
        day: "2-digit",
        month: "short",
        hour: "2-digit",
        minute: "2-digit"
      });
    } catch {
      return iso;
    }
  }

  function applyLanguage() {
    document.documentElement.lang = state.uiLang;
    document.documentElement.dir = state.uiLang === "ar" ? "rtl" : "ltr";
    document.getElementById("btn-lang-fr").classList.toggle("active", state.uiLang === "fr");
    document.getElementById("btn-lang-ar").classList.toggle("active", state.uiLang === "ar");

    document.querySelectorAll("[data-i18n]").forEach((el) => {
      const key = el.getAttribute("data-i18n");
      if (I18N[state.uiLang][key]) {
        el.textContent = I18N[state.uiLang][key];
      }
    });

    document.querySelectorAll("[data-i18n-placeholder]").forEach((el) => {
      const key = el.getAttribute("data-i18n-placeholder");
      if (I18N[state.uiLang][key]) {
        el.setAttribute("placeholder", I18N[state.uiLang][key]);
      }
    });

    renderAll();
  }

  function renderSiteChrome() {
    const site = state.data.site || {};
    const isAr = state.uiLang === "ar";

    const title = isAr ? (site.siteTitleAr || "أخبار النادي الإفريقي") : (site.siteTitleFr || "Club Africain News");
    const subtitle = isAr
      ? (site.siteSubtitleAr || "بوابة أخبار كرة القدم لجماهير النادي الإفريقي")
      : (site.siteSubtitleFr || "Le portail d'actualités football des supporters clubistes");

    document.getElementById("site-title").textContent = title;
    document.getElementById("site-subtitle").textContent = subtitle;

    // Breaking news bar
    const breakingBar = document.getElementById("breaking-bar");
    const breakingText = isAr ? (site.breakingAr || site.breakingFr) : (site.breakingFr || site.breakingAr);
    if (site.breakingEnabled && breakingText) {
      breakingBar.classList.remove("hidden");
      const textEl = document.getElementById("breaking-text");
      if (site.breakingUrl) {
        textEl.innerHTML = `<a href="${escapeHtml(site.breakingUrl)}" target="_blank" rel="noopener">${escapeHtml(breakingText)}</a>`;
      } else {
        textEl.textContent = breakingText;
      }
    } else {
      breakingBar.classList.add("hidden");
    }

    // Match banner
    const mb = site.matchBanner || {};
    const bannerEl = document.getElementById("match-banner");
    if (mb.enabled !== false && (mb.titleFr || mb.titleAr)) {
      bannerEl.classList.remove("hidden");
      document.getElementById("match-badge").textContent = isAr ? (mb.badgeAr || mb.badgeFr || "") : (mb.badgeFr || mb.badgeAr || "");
      document.getElementById("match-title").textContent = isAr ? (mb.titleAr || mb.titleFr || "") : (mb.titleFr || mb.titleAr || "");
      document.getElementById("match-meta").textContent = isAr ? (mb.metaAr || mb.metaFr || "") : (mb.metaFr || mb.metaAr || "");
      const ticketBtn = document.getElementById("match-ticket-btn");
      if (mb.ticketUrl) {
        ticketBtn.href = mb.ticketUrl;
        ticketBtn.classList.remove("hidden");
      } else {
        ticketBtn.classList.add("hidden");
      }
    } else {
      bannerEl.classList.add("hidden");
    }

    document.getElementById("last-updated-label").textContent = state.data.generatedAt
      ? `${t("updatedAt")} ${formatDate(state.data.generatedAt)}`
      : "";
  }

  function renderArticleTitleAction(article) {
    if (article.body && article.body.trim().length > 0) {
      return `<button type="button" class="open-reader-btn" data-id="${escapeHtml(article.id)}">${escapeHtml(article.title)}</button>`;
    }
    if (article.url) {
      return `<a href="${escapeHtml(article.url)}" target="_blank" rel="noopener">${escapeHtml(article.title)}</a>`;
    }
    return `<span>${escapeHtml(article.title)}</span>`;
  }

  function renderFeatured() {
    const sec = document.getElementById("featured-section");
    const grid = document.getElementById("featured-grid");
    const articles = state.data.articles || [];

    const showFeatured = state.topic === "all" && !state.query.trim() && state.articleLang === "all";
    if (!showFeatured || !articles.length) {
      sec.classList.add("hidden");
      return;
    }

    const pinned = articles.filter((a) => a.featured);
    const pool = pinned.length ? pinned : articles.filter((a) => a.verification === "official" || a.verification === "verified");
    const top = (pool.length >= 3 ? pool : articles).slice(0, 3);

    if (!top.length) {
      sec.classList.add("hidden");
      return;
    }

    sec.classList.remove("hidden");
    const hero = top[0];
    const side = top.slice(1, 3);
    const heroSrc = state.uiLang === "ar" ? (hero.sourceNameAr || hero.sourceName) : hero.sourceName;
    const heroVerif = I18N[state.uiLang].verif[hero.verification] || hero.verification;

    const heroImg = hero.thumbnail
      ? `<img class="hero-card-bg" src="${escapeHtml(hero.thumbnail)}" alt="" />`
      : "";

    const sideHtml = side
      .map((a) => {
        const verif = I18N[state.uiLang].verif[a.verification] || a.verification;
        const topic = I18N[state.uiLang].topics[a.topic] || a.topic;
        const src = state.uiLang === "ar" ? (a.sourceNameAr || a.sourceName) : a.sourceName;
        return `
          <article class="sub-hero-card" dir="${a.lang === "ar" ? "rtl" : "ltr"}">
            <div>
              <div class="article-meta">
                ${a.featured ? `<span class="badge badge-featured">${escapeHtml(t("featuredBadge"))}</span>` : ""}
                <span class="badge badge-${escapeHtml(a.verification)}">${escapeHtml(verif)}</span>
                <span class="badge badge-topic">${escapeHtml(topic)}</span>
              </div>
              <h3>${renderArticleTitleAction(a)}</h3>
            </div>
            <div class="article-footer">
              <span class="source-chip">${escapeHtml(src)}</span>
              <span>${escapeHtml(formatDate(a.publishedAt))}</span>
            </div>
          </article>
        `;
      })
      .join("");

    grid.innerHTML = `
      <article class="hero-card" dir="${hero.lang === "ar" ? "rtl" : "ltr"}">
        ${heroImg}
        <div class="hero-card-inner">
          <div class="article-meta">
            <span class="badge badge-featured">${escapeHtml(t("featuredBadge"))}</span>
            <span class="badge badge-${escapeHtml(hero.verification)}">${escapeHtml(heroVerif)}</span>
            <span class="badge badge-lang">${escapeHtml((hero.lang || "").toUpperCase())}</span>
          </div>
          <h3>${renderArticleTitleAction(hero)}</h3>
          ${hero.summary ? `<p class="hero-summary">${escapeHtml(hero.summary)}</p>` : ""}
          <div class="hero-meta">
            <span>${escapeHtml(heroSrc)}</span>
            <span>• ${escapeHtml(formatDate(hero.publishedAt))}</span>
          </div>
        </div>
      </article>
      <div class="featured-stack">${sideHtml}</div>
    `;
  }

  function renderFeed() {
    const listEl = document.getElementById("articles-list");
    const q = state.query.trim().toLowerCase();

    let items = (state.data.articles || []).filter((a) => {
      if (state.topic !== "all" && a.topic !== state.topic) return false;
      if (state.articleLang !== "all" && a.lang !== state.articleLang) return false;
      if (q) {
        const hay = `${a.title} ${a.summary} ${a.body || ""} ${a.sourceName} ${a.sourceNameAr}`.toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });

    items.sort((a, b) => {
      if (state.sortBy === "date") {
        return new Date(b.publishedAt) - new Date(a.publishedAt);
      }
      if (Boolean(b.featured) !== Boolean(a.featured)) return b.featured ? 1 : -1;
      const dateDiff = new Date(b.publishedAt) - new Date(a.publishedAt);
      if (Math.abs(dateDiff) > 3600 * 1000 * 12) return dateDiff;
      return (b.score || 0) - (a.score || 0);
    });

    document.getElementById("results-count").textContent = `${items.length} ${t("articlesUnit")}`;

    if (!items.length) {
      listEl.innerHTML = `<div class="side-card"><p>${escapeHtml(t("noResults"))}</p></div>`;
      document.getElementById("load-more-wrap").classList.add("hidden");
      return;
    }

    const visible = items.slice(0, state.limit);
    const loadMoreWrap = document.getElementById("load-more-wrap");
    if (items.length > visible.length) {
      loadMoreWrap.classList.remove("hidden");
    } else {
      loadMoreWrap.classList.add("hidden");
    }

    listEl.innerHTML = visible
      .map((a) => {
        const verifLabel = I18N[state.uiLang].verif[a.verification] || a.verification;
        const topicLabel = I18N[state.uiLang].topics[a.topic] || a.topic;
        const srcName = state.uiLang === "ar" ? (a.sourceNameAr || a.sourceName) : a.sourceName;

        const thumbHtml = a.thumbnail
          ? `<div class="article-thumb-wrap"><img class="article-thumb" src="${escapeHtml(a.thumbnail)}" alt="${escapeHtml(a.title)}" loading="lazy" /></div>`
          : "";

        const actionBtn = a.body && a.body.trim().length > 0
          ? `<button type="button" class="read-more-link open-reader-btn" data-id="${escapeHtml(a.id)}">${escapeHtml(t("readArticle"))} →</button>`
          : (a.url ? `<a class="read-more-link" href="${escapeHtml(a.url)}" target="_blank" rel="noopener">${escapeHtml(t("openSource"))}</a>` : "");

        return `
          <article class="article-card ${a.featured ? "is-featured" : ""}" dir="${a.lang === "ar" ? "rtl" : "ltr"}">
            <div class="article-inner">
              ${thumbHtml}
              <div class="article-body">
                <div class="article-meta">
                  ${a.featured ? `<span class="badge badge-featured">${escapeHtml(t("featuredBadge"))}</span>` : ""}
                  <span class="badge badge-${escapeHtml(a.verification)}">${escapeHtml(verifLabel)}</span>
                  <span class="badge badge-topic">${escapeHtml(topicLabel)}</span>
                  <span class="badge badge-lang">${escapeHtml((a.lang || "").toUpperCase())}</span>
                </div>
                <h3>${renderArticleTitleAction(a)}</h3>
                ${a.summary ? `<p class="article-summary">${escapeHtml(a.summary)}</p>` : ""}
                <div class="article-footer">
                  <div>
                    <span class="source-chip">${escapeHtml(srcName)}</span>
                    <span>• ${escapeHtml(formatDate(a.publishedAt))}</span>
                  </div>
                  ${actionBtn}
                </div>
              </div>
            </div>
          </article>
        `;
      })
      .join("");
  }

  function renderSidebar() {
    const videos = (state.data.articles || []).filter((a) => a.isVideo && a.thumbnail).slice(0, 4);
    document.getElementById("videos-list").innerHTML = videos.length
      ? videos
          .map((v) => `
            <a class="video-item" href="${escapeHtml(v.url)}" target="_blank" rel="noopener" dir="${v.lang === "ar" ? "rtl" : "ltr"}">
              <img src="${escapeHtml(v.thumbnail)}" alt="${escapeHtml(v.title)}" loading="lazy" />
              <span class="video-item-title">${escapeHtml(v.title)}</span>
            </a>
          `)
          .join("")
      : `<p class="side-desc">—</p>`;

    const links = state.data.officialLinks || [];
    document.getElementById("official-links-list").innerHTML = links
      .map((s) => {
        const label = state.uiLang === "ar" ? (s.nameAr || s.name) : s.name;
        return `
          <a class="official-link" href="${escapeHtml(s.url)}" target="_blank" rel="noopener">
            <span>${escapeHtml(label)}</span>
            <span>↗</span>
          </a>
        `;
      })
      .join("");
  }

  function openReaderModal(articleId) {
    const article = (state.data.articles || []).find((a) => a.id === articleId);
    if (!article) return;

    const verifLabel = I18N[state.uiLang].verif[article.verification] || article.verification;
    const topicLabel = I18N[state.uiLang].topics[article.topic] || article.topic;
    const srcName = state.uiLang === "ar" ? (article.sourceNameAr || article.sourceName) : article.sourceName;

    document.getElementById("modal-content").innerHTML = `
      <div dir="${article.lang === "ar" ? "rtl" : "ltr"}">
        <div class="article-meta">
          <span class="badge badge-${escapeHtml(article.verification)}">${escapeHtml(verifLabel)}</span>
          <span class="badge badge-topic">${escapeHtml(topicLabel)}</span>
        </div>
        <h2 id="modal-title" style="margin: 8px 0 6px;">${escapeHtml(article.title)}</h2>
        <div style="font-size: 0.84rem; color: var(--muted); margin-bottom: 10px;">
          <strong>${escapeHtml(srcName)}</strong> • ${escapeHtml(formatDate(article.publishedAt))}
        </div>
        ${article.thumbnail ? `<img class="modal-thumb" src="${escapeHtml(article.thumbnail)}" alt="${escapeHtml(article.title)}" />` : ""}
        ${article.summary ? `<p style="font-weight: 600; color: var(--ink);">${escapeHtml(article.summary)}</p>` : ""}
        ${article.body ? `<div class="modal-body-text">${escapeHtml(article.body)}</div>` : ""}
        ${article.url ? `<a class="ticket-btn" style="display:inline-block;margin-top:8px;" href="${escapeHtml(article.url)}" target="_blank" rel="noopener">${escapeHtml(t("openSource"))}</a>` : ""}
      </div>
    `;
    document.getElementById("article-modal").classList.remove("hidden");
  }

  function renderAll() {
    renderSiteChrome();
    renderFeatured();
    renderFeed();
    renderSidebar();
  }

  async function tryLoadFromApi() {
    if (window.location.protocol === "file:") return;
    try {
      const res = await fetch("/api/public/news");
      if (res.ok) {
        state.data = await res.json();
        renderAll();
      }
    } catch {
      // Fallback already loaded via data/news.js
    }
  }

  // Event listeners
  document.getElementById("btn-lang-fr").addEventListener("click", () => {
    state.uiLang = "fr";
    applyLanguage();
  });
  document.getElementById("btn-lang-ar").addEventListener("click", () => {
    state.uiLang = "ar";
    applyLanguage();
  });

  document.querySelectorAll("#topic-nav .nav-pill").forEach((pill) => {
    pill.addEventListener("click", () => {
      state.topic = pill.getAttribute("data-topic");
      state.limit = PAGE_SIZE;
      document.querySelectorAll("#topic-nav .nav-pill").forEach((p) => p.classList.toggle("active", p === pill));
      renderFeatured();
      renderFeed();
    });
  });

  document.getElementById("search-input").addEventListener("input", (e) => {
    state.query = e.target.value;
    state.limit = PAGE_SIZE;
    renderFeatured();
    renderFeed();
  });
  document.getElementById("article-lang-filter").addEventListener("change", (e) => {
    state.articleLang = e.target.value;
    state.limit = PAGE_SIZE;
    renderFeatured();
    renderFeed();
  });
  document.getElementById("sort-filter").addEventListener("change", (e) => {
    state.sortBy = e.target.value;
    renderFeed();
  });
  document.getElementById("btn-load-more").addEventListener("click", () => {
    state.limit += PAGE_SIZE;
    renderFeed();
  });

  document.addEventListener("click", (e) => {
    const btn = e.target.closest(".open-reader-btn");
    if (btn) {
      openReaderModal(btn.getAttribute("data-id"));
    }
  });

  document.getElementById("modal-close").addEventListener("click", () => {
    document.getElementById("article-modal").classList.add("hidden");
  });
  document.getElementById("article-modal").addEventListener("click", (e) => {
    if (e.target.id === "article-modal") {
      document.getElementById("article-modal").classList.add("hidden");
    }
  });

  applyLanguage();
  tryLoadFromApi();
})();
