
(async function () {
  const $ = (sel) => document.querySelector(sel);
  const resultsEl = $("#results");
  const qEl = $("#q");
  const cityEl = $("#city");
  const stateEl = $("#state");
  const maxRateEl = $("#maxRate");
  const inHomeEl = $("#inHome");
  const virtualEl = $("#virtual");
  const groupsEl = $("#groups");
  const clearBtn = $("#clearBtn");

  let trainers = [];
  try {
    const res = await fetch("/data/trainers.json", { cache: "no-store" });
    trainers = await res.json();
  } catch (e) {
    resultsEl.innerHTML = `<div class="text-red-400">Error loading trainers.json</div>`;
    return;
  }

  function render(list) {
    if (!list.length) {
      resultsEl.innerHTML = `<div class="text-zinc-400 text-sm">No matches yet — try fewer filters.</div>`;
      return;
    }
    resultsEl.innerHTML = `
      <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
        ${list.map(card).join("")}
      </div>
    `;
  }

  function card(t) {
    const chips = [
      ...(t.specialties || []),
      ...(t.certifications || [])
    ].slice(0, 4);
    return `
      <article class="rounded-2xl border border-zinc-800 bg-zinc-900/40 p-4">
        <div class="text-lg font-bold">${escapeHTML(t.name)}</div>
        <div class="text-zinc-300 text-sm">${escapeHTML(t.headline || "")}</div>
        <div class="mt-2 text-zinc-400 text-sm">${escapeHTML(t.city)}, ${escapeHTML(t.state)}</div>
        <div class="mt-2 text-amber-400 font-semibold">$${t.rate_per_hour}/hr</div>
        <div class="mt-3 flex flex-wrap gap-2">
          ${chips.map(c => `<span class="px-2 py-1 rounded-lg border border-zinc-800 text-xs text-zinc-300">${escapeHTML(c)}</span>`).join("")}
        </div>
        <div class="mt-3 text-xs text-zinc-400">
          ${t.in_home ? "🏠 In‑home" : ""} ${t.virtual ? "💻 Virtual" : ""} ${t.groups ? "👥 Groups" : ""}
        </div>
        <p class="mt-3 text-sm text-zinc-300">${escapeHTML(t.bio || "")}</p>
        <div class="mt-4">
          ${t.contact?.email ? `<a class="text-amber-400 hover:underline text-sm" href="mailto:${encodeURIComponent(t.contact.email)}">Contact</a>` : ""}
        </div>
      </article>
    `;
  }

  function escapeHTML(str) {
    return String(str || "").replace(/[&<>'"]/g, s => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      "'": "&#39;",
      '"': "&quot;"
    }[s]));
  }

  function applyFilters() {
    const q = qEl.value.trim().toLowerCase();
    const city = cityEl.value.trim().toLowerCase();
    const state = stateEl.value.trim().toLowerCase();
    const maxRate = Number(maxRateEl.value || 0);
    const reqInHome = inHomeEl.checked;
    const reqVirtual = virtualEl.checked;
    const reqGroups = groupsEl.checked;

    const out = trainers.filter(t => {
      const hay = [
        t.name, t.headline, ...(t.specialties || []), ...(t.certifications || [])
      ].join(" ").toLowerCase();
      if (q && !hay.includes(q)) return false;
      if (city && String(t.city || "").toLowerCase() !== city) return false;
      if (state && String(t.state || "").toLowerCase() !== state) return false;
      if (maxRate && Number(t.rate_per_hour || 0) > maxRate) return false;
      if (reqInHome && !t.in_home) return false;
      if (reqVirtual && !t.virtual) return false;
      if (reqGroups && !t.groups) return false;
      return true;
    });

    render(out);
  }

  [qEl, cityEl, stateEl, maxRateEl, inHomeEl, virtualEl, groupsEl].forEach(el => {
    el.addEventListener("input", applyFilters);
    el.addEventListener("change", applyFilters);
  });

  $("#clearBtn").addEventListener("click", () => {
    qEl.value = ""; cityEl.value = ""; stateEl.value = ""; maxRateEl.value = "";
    inHomeEl.checked = false; virtualEl.checked = false; groupsEl.checked = false;
    applyFilters();
  });

  render(trainers);
})();