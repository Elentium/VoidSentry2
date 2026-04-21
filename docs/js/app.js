function renderBenchmarks() {
	const root = document.getElementById("benchmarks-root");
	if (!root) return;

	const data = window.VS2_BENCHMARKS;
	if (!data || typeof data !== "object") {
		root.innerHTML = "<p class=\"muted\">No benchmark data (<code>VS2_BENCHMARKS</code> missing).</p>";
		return;
	}

	const sections = Object.keys(data);
	let html = "";
	for (const section of sections) {
		const tests = data[section];
		if (!tests || typeof tests !== "object") continue;

		html += "<div class=\"benchmark-section card\">";
		html += "<h3 class=\"benchmark-section-title\">" + escapeHtml(section) + "</h3>";
		html += "<div class=\"benchmark-table-wrap\"><table class=\"benchmark-table\"><thead><tr>";
		html += "<th>Test</th><th class=\"num\">Avg (µs)</th>";
		html += "</tr></thead><tbody>";

		const names = Object.keys(tests);
		for (const name of names) {
			const v = tests[name];
			const num = typeof v === "number" && !Number.isNaN(v) ? v.toFixed(2) : escapeHtml(String(v));
			html += "<tr><td>" + escapeHtml(name) + "</td><td class=\"num\">" + num + "</td></tr>";
		}
		html += "</tbody></table></div></div>";
	}
	root.innerHTML = html || "<p class=\"muted\">Benchmark map is empty.</p>";
}

function escapeHtml(s) {
	return String(s)
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;")
		.replace(/\"/g, "&quot;");
}

function initCodeCopyButtons() {
	const copyIcon =
		'<svg class="code-block__copy-icon" viewBox="0 0 24 24" width="16" height="16" fill="currentColor" aria-hidden="true">' +
		'<path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/>' +
		"</svg>";

	document.querySelectorAll(".code-block").forEach(function (block) {
		if (block.querySelector(".code-block__copy")) return;
		const code = block.querySelector("pre code");
		if (!code) return;

		block.classList.add("code-block--has-copy");

		const btn = document.createElement("button");
		btn.type = "button";
		btn.className = "code-block__copy";
		btn.setAttribute("aria-label", "Copy code");
		btn.innerHTML = copyIcon + '<span class="code-block__copy-label">Copy</span>';

		function setCopiedState(done) {
			const label = btn.querySelector(".code-block__copy-label");
			btn.classList.toggle("code-block__copy--done", done);
			if (label) label.textContent = done ? "Copied!" : "Copy";
		}

		function copyText(text) {
			if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
				return navigator.clipboard.writeText(text);
			}
			return new Promise(function (resolve, reject) {
				const ta = document.createElement("textarea");
				ta.value = text;
				ta.setAttribute("readonly", "");
				ta.style.position = "fixed";
				ta.style.left = "-9999px";
				document.body.appendChild(ta);
				ta.select();
				try {
					if (document.execCommand("copy")) resolve();
					else reject(new Error("copy failed"));
				} catch (e) {
					reject(e);
				} finally {
					document.body.removeChild(ta);
				}
			});
		}

		btn.addEventListener("click", function () {
			const text = code.textContent || "";
			copyText(text)
				.then(function () {
					setCopiedState(true);
					window.setTimeout(function () {
						setCopiedState(false);
					}, 2000);
				})
				.catch(function () {});
		});

		block.appendChild(btn);
	});
}

function initNav() {
	const navButtons = document.querySelectorAll(".nav-btn");
	const pages = document.querySelectorAll(".page");

	function goToPage(targetPage, opts) {
		if (!targetPage) return;
		const scrollTop = !opts || opts.scrollTop !== false;
		navButtons.forEach(function (btn) {
			btn.classList.toggle("active", btn.getAttribute("data-page") === targetPage);
		});
		pages.forEach(function (page) {
			page.classList.toggle("active", page.id === targetPage);
		});
		if (scrollTop) {
			window.scrollTo(0, 0);
		}
		if (targetPage === "benchmarks") {
			renderBenchmarks();
		}
	}

	function onNavActivate(button) {
		const targetPage = button.getAttribute("data-page");
		goToPage(targetPage);
	}

	/**
	 * SPA pages are display:none until .active; plain #hash navigation cannot reveal
	 * the target. Find the owning .page, switch to it, then scroll the element in.
	 * Cross-page switches must defer scrolling until after layout (otherwise scroll
	 * lands at y=0 or the wrong offset). Same-page links use smooth scroll only.
	 */
	function prefersReducedMotion() {
		return window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
	}

	function updateHistoryHash(id) {
		if (window.history && typeof window.history.replaceState === "function") {
			window.history.replaceState(null, "", "#" + id);
		}
	}

	function scrollToHashTarget(el) {
		const behavior = prefersReducedMotion() ? "auto" : "smooth";
		el.scrollIntoView({ block: "start", behavior: behavior, inline: "nearest" });
	}

	function navigateToHash(rawHash) {
		const id = String(rawHash || "").replace(/^#/, "");
		if (!id) return;
		let el = document.getElementById(id);
		if (!el) return;
		const pageSection = el.closest(".page");
		const targetPageId = pageSection && pageSection.id ? pageSection.id : "";
		const activePage = document.querySelector(".page.active");
		const currentPageId = activePage && activePage.id ? activePage.id : "";
		const switchingPage = targetPageId && targetPageId !== currentPageId;

		function applyScrollAndHash() {
			el = document.getElementById(id);
			if (!el) return;
			scrollToHashTarget(el);
			updateHistoryHash(id);
		}

		if (switchingPage) {
			goToPage(targetPageId, { scrollTop: false });
			// .page.active uses a 0.3s fade-in; scrolling before layout/animation finishes jumps to y≈0.
			window.setTimeout(applyScrollAndHash, 320);
		} else {
			window.requestAnimationFrame(function () {
				window.requestAnimationFrame(applyScrollAndHash);
			});
		}
	}

	navButtons.forEach(function (button) {
		button.addEventListener("click", function () {
			onNavActivate(button);
		});
	});

	document.querySelectorAll(".page-nav__btn").forEach(function (button) {
		button.addEventListener("click", function () {
			onNavActivate(button);
		});
	});

	document.addEventListener("click", function (e) {
		const a = e.target && e.target.closest && e.target.closest('a[href^="#"]');
		if (!a || !a.getAttribute) return;
		const href = a.getAttribute("href");
		if (!href || href === "#") return;
		if (href.charAt(0) !== "#") return;
		const id = href.slice(1);
		if (!id || !document.getElementById(id)) return;
		e.preventDefault();
		navigateToHash(href);
	});

	if (window.location.hash && window.location.hash.length > 1) {
		window.setTimeout(function () {
			navigateToHash(window.location.hash);
		}, 0);
	}
}

document.addEventListener("DOMContentLoaded", function () {
	initNav();
	if (typeof hljs !== "undefined" && typeof hljs.highlightAll === "function") {
		hljs.highlightAll();
	}
	initCodeCopyButtons();
	if (document.getElementById("benchmarks") && document.getElementById("benchmarks").classList.contains("active")) {
		renderBenchmarks();
	}
});