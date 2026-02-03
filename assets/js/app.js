// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Hooks from "./hooks"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Detect user timezone
function getUserTimezone() {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || "Europe/Kyiv"
  } catch (e) {
    return "Europe/Kyiv" // Fallback to Ukraine/Kyiv
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  params: {
    _csrf_token: csrfToken,
    timezone: getUserTimezone()
  },
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// Targeted suppression of the LiveView disconnect toast during intentional
// full-page navigations for OAuth (Google/GitHub). This avoids showing
// "Attempting to reconnect" while leaving the page, without masking real
// disconnects during normal usage.
document.addEventListener("click", (e) => {
  const link = e.target && e.target.closest
    ? e.target.closest("a[data-tymeslot-suppress-lv-disconnect]")
    : null;

  if (!link) return;

  // Keep the window small: if the socket is still disconnected after this,
  // the toast will still show.
  window.__tymeslot_suppress_lv_disconnect_until = Date.now() + 2500;
}, true);

// Reset form on event
window.addEventListener("phx:reset-form", (e) => {
  const form = document.getElementById(e.detail.id);
  if (form) form.reset();
});

// Handle copy-to-clipboard events from LiveView
window.addEventListener("phx:copy-to-clipboard", (e) => {
  const text = e.detail.text;
  if (navigator.clipboard) {
    navigator.clipboard.writeText(text).then(() => {
      console.log('Copied to clipboard');
    }).catch(err => {
      console.error('Failed to copy:', err);
    });
  }
});

// Handle client-side copy events
window.addEventListener("tymeslot:clip-copy", (e) => {
  const message = e.detail.message || "Copied to clipboard!";
  const kind = e.detail.kind || "info";
  
  // Use a simple client-side toast for zero-roundtrip feedback
  const container = document.getElementById("flash-group") || document.body;
  const toast = document.createElement("div");
  
  // Style matching core_components/flash.ex
  const isError = kind === "error" || message.toLowerCase().includes("fail") || message.toLowerCase().includes("unavailable");
  
  toast.className = `fixed top-4 right-4 z-[10060] w-80 sm:w-96 rounded-2xl p-5 shadow-2xl border-2 transition-all duration-500 transform translate-y-4 opacity-0 scale-95 cursor-pointer ${
    isError 
      ? "bg-red-50 border-red-100 text-red-900 shadow-red-500/10" 
      : "bg-white border-turquoise-100 text-slate-900 shadow-turquoise-500/10"
  }`;
  
  toast.innerHTML = `
    <div class="relative z-10 flex items-start gap-4">
      <div class="flex-shrink-0 w-10 h-10 rounded-xl flex items-center justify-center shadow-sm border ${
        isError ? "bg-white border-red-100 text-red-500" : "bg-turquoise-50 border-turquoise-100 text-turquoise-600"
      }">
        <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="${
            isError 
              ? "M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" 
              : "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
          }" />
        </svg>
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-sm font-bold leading-relaxed">${message}</p>
      </div>
    </div>
  `;

  container.appendChild(toast);

  // Animate in
  setTimeout(() => {
    toast.classList.remove("translate-y-4", "opacity-0", "scale-95");
    toast.classList.add("translate-y-0", "opacity-100", "scale-100");
  }, 20);

  // Auto-remove helper
  const removeToast = () => {
    toast.classList.add("opacity-0", "translate-y-4", "scale-95");
    toast.classList.remove("opacity-100", "translate-y-0", "scale-100");
    setTimeout(() => toast.remove(), 500);
  };

  toast.addEventListener("click", removeToast);
  setTimeout(removeToast, 5000);
});

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

