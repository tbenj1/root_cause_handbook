(function () {
  "use strict";

  var progressRoot;
  var progressBar;
  var frameRequested = false;

  function ensureProgressIndicator() {
    progressRoot = document.querySelector(".rch-reading-progress");

    if (!progressRoot) {
      progressRoot = document.createElement("div");
      progressRoot.className = "rch-reading-progress";
      progressRoot.setAttribute("aria-hidden", "true");

      progressBar = document.createElement("div");
      progressBar.className = "rch-reading-progress__bar";
      progressRoot.appendChild(progressBar);
      document.body.appendChild(progressRoot);
    } else {
      progressBar = progressRoot.querySelector(".rch-reading-progress__bar");
    }
  }

  function updateProgress() {
    frameRequested = false;

    if (!progressBar) {
      return;
    }

    var documentHeight = document.documentElement.scrollHeight - window.innerHeight;
    var progress = documentHeight > 0 ? window.scrollY / documentHeight : 0;
    var boundedProgress = Math.min(1, Math.max(0, progress));

    progressBar.style.width = (boundedProgress * 100).toFixed(2) + "%";
  }

  function requestProgressUpdate() {
    if (frameRequested) {
      return;
    }

    frameRequested = true;
    window.requestAnimationFrame(updateProgress);
  }

  function initializePageEnhancements() {
    ensureProgressIndicator();
    requestProgressUpdate();
  }

  window.addEventListener("scroll", requestProgressUpdate, { passive: true });
  window.addEventListener("resize", requestProgressUpdate);
  window.addEventListener("load", initializePageEnhancements);

  if (typeof document$ !== "undefined") {
    document$.subscribe(initializePageEnhancements);
  } else if (document.readyState !== "loading") {
    initializePageEnhancements();
  } else {
    document.addEventListener("DOMContentLoaded", initializePageEnhancements);
  }
})();
