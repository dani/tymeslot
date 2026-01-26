/**
 * Tymeslot Booking Widget
 * 
 * Provides multiple embedding modes for Tymeslot booking pages:
 * - Inline: Embeds directly into a div
 * - Popup: Opens in a modal overlay
 * - Floating: Fixed button that opens popup
 * 
 * Usage:
 * 1. Inline: <div id="tymeslot-booking" data-username="sarah"></div>
 * 2. Popup: <button onclick="TymeslotBooking.open('sarah')">Book</button>
 * 3. Floating: TymeslotBooking.initFloating('sarah')
 */

(function() {
  'use strict';

  /**
   * Global Error Handling
   */
  const failSafe = (msg) => {
    console.error('Tymeslot Error:', msg);
    const containers = document.querySelectorAll('#tymeslot-booking, [data-tymeslot-inline]');
    containers.forEach(c => {
      if (typeof TymeslotBooking !== 'undefined' && TymeslotBooking.showError) {
        TymeslotBooking.showError(c);
      } else {
        c.innerHTML = '<div style="padding:20px;color:#991b1b;background:#fef2f2;border:1px solid #fecaca;border-radius:8px;font-family:sans-serif;"><strong>Booking system unavailable.</strong></div>';
      }
    });
  };

  window.addEventListener('error', function(e) {
    if (e.filename && e.filename.indexOf('embed.js') !== -1) {
      failSafe(e.message);
    }
  });

  // Configuration
  const CONFIG = {
    // Get base URL from script tag or current domain
    getBaseUrl: function() {
      // 1. Try modern currentScript API
      if (document.currentScript) {
        return new URL(document.currentScript.src).origin;
      }
      // 2. Fallback to searching script tags
      const script = document.querySelector('script[src*="embed.js"]');
      if (script) {
        const src = script.getAttribute('src');
        const url = new URL(src, window.location.href);
        return url.origin;
      }
      return window.location.origin;
    }
  };

  const BASE_URL = CONFIG.getBaseUrl();

  /**
   * Global message listener for iframe resizing
   */
  window.addEventListener('message', function(e) {
    if (e.origin !== BASE_URL) return;
    if (e.data.type === 'tymeslot-resize' && e.data.height) {
      const iframes = document.querySelectorAll('iframe[title="Booking Widget"]');
      iframes.forEach(iframe => {
        if (iframe.contentWindow === e.source) {
          iframe.style.height = e.data.height + 'px';
          if (iframe.parentNode) {
            iframe.parentNode.style.minHeight = e.data.height + 'px';
          }
        }
      });
    }
  });

  /**
   * Create an iframe for embedding
   */
  function createBookingIframe(username, options = {}) {
    const iframe = document.createElement('iframe');
    const url = `${BASE_URL}/${username}`;
    
    // Build URL with customization params - STRICT ALLOWLIST
    const params = new URLSearchParams();
    const ALLOWED_PARAMS = ['theme', 'primaryColor', 'locale'];
    
    ALLOWED_PARAMS.forEach(key => {
      const val = options[key];
      if (!val) return;

      if (key === 'theme' && /^\d+$/.test(val)) {
        params.append('theme', val);
      } else if (key === 'primaryColor' && /^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/.test(val)) {
        params.append('primary-color', val);
      } else if (key === 'locale' && /^[a-z]{2}(-[a-zA-Z0-9]+)?$/.test(val)) {
        params.append('locale', val);
      }
    });
    
    const fullUrl = params.toString() ? `${url}?${params.toString()}` : url;
    
    iframe.src = fullUrl;
    iframe.style.cssText = `
      width: 100%;
      border: none;
      min-height: 700px;
      background: transparent;
      transition: opacity 0.3s ease;
      opacity: 0;
    `;
    iframe.setAttribute('scrolling', 'auto');
    iframe.setAttribute('allow', 'payment');
    iframe.setAttribute('title', 'Booking Widget');

    // Create wrapper for loading state
    const wrapper = document.createElement('div');
    wrapper.style.position = 'relative';
    wrapper.style.width = '100%';
    wrapper.style.minHeight = '700px';

    const loader = document.createElement('div');
    loader.className = 'tymeslot-loader';
    loader.style.cssText = `
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      display: flex;
      flex-direction: column;
      align-items: center;
      font-family: sans-serif;
      color: #64748b;
    `;
    
    const spinner = document.createElement('div');
    spinner.style.cssText = 'width: 40px; height: 40px; border: 3px solid #f3f3f3; border-top: 3px solid #14B8A6; border-radius: 50%; animation: tymeslot-spin 1s linear infinite;';
    
    const loadingText = document.createElement('span');
    loadingText.style.cssText = 'margin-top: 12px; font-size: 14px;';
    loadingText.textContent = 'Loading booking page...';
    
    const style = document.createElement('style');
    style.textContent = '@keyframes tymeslot-spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }';
    
    loader.appendChild(spinner);
    loader.appendChild(loadingText);
    loader.appendChild(style);
    wrapper.appendChild(loader);

    // Add loading timeout
    let retryCount = 0;
    const maxRetries = 2;
    const TIMEOUT_MS = 15000;

    const handleTimeout = () => {
      if (wrapper.parentNode && !iframe.dataset.loaded) {
        if (retryCount < maxRetries) {
          retryCount++;
          const currentUrl = new URL(iframe.src);
          currentUrl.searchParams.set('_retry', retryCount);
          iframe.src = currentUrl.toString();
          setTimeout(handleTimeout, TIMEOUT_MS);
        } else {
          showError(wrapper, loader);
          if (iframe.parentNode) iframe.remove();
        }
      }
    };

    const timeout = setTimeout(handleTimeout, TIMEOUT_MS);

    iframe.onload = () => {
      iframe.dataset.loaded = 'true';
      iframe.style.opacity = '1';
      if (loader.parentNode) loader.remove();
      clearTimeout(timeout);
    };
    
    wrapper.appendChild(iframe);
    return wrapper;
  }

  /**
   * Show error message in container
   */
  function showError(container, elementToReplace) {
    const error = document.createElement('div');
    error.style.cssText = 'padding: 24px; color: #991b1b; background: #fef2f2; border: 2px solid #fecaca; border-radius: 12px; text-align: center; font-family: sans-serif;';
    
    const title = document.createElement('strong');
    title.textContent = 'Booking widget is taking too long to load.';
    
    const subtext = document.createElement('p');
    subtext.style.cssText = 'margin-top: 8px; font-size: 14px; color: #b91c1c;';
    subtext.textContent = 'Please check your connection or refresh the page.';
    
    error.appendChild(title);
    error.appendChild(document.createElement('br'));
    error.appendChild(subtext);
    
    if (elementToReplace && elementToReplace.parentNode === container) {
      container.replaceChild(error, elementToReplace);
    } else {
      container.innerHTML = '';
      container.appendChild(error);
    }
  }

  /**
   * Create modal overlay
   */
  function createModal() {
    const modal = document.createElement('div');
    modal.id = 'tymeslot-modal';
    modal.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: rgba(0, 0, 0, 0.75);
      z-index: 999999;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
      opacity: 0;
      transition: opacity 0.3s ease;
    `;
    
    const container = document.createElement('div');
    container.style.cssText = `
      position: relative;
      width: 100%;
      max-width: 1000px;
      height: 90vh;
      max-height: 900px;
      background: white;
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
      transform: scale(0.95);
      transition: transform 0.3s ease;
    `;
    
    const closeButton = document.createElement('button');
    closeButton.innerHTML = '×';
    closeButton.style.cssText = `
      position: absolute;
      top: 16px;
      right: 16px;
      width: 40px;
      height: 40px;
      border: none;
      background: rgba(0, 0, 0, 0.1);
      color: #333;
      font-size: 32px;
      line-height: 1;
      border-radius: 50%;
      cursor: pointer;
      z-index: 10;
      transition: all 0.2s ease;
      display: flex;
      align-items: center;
      justify-content: center;
    `;
    closeButton.setAttribute('aria-label', 'Close booking widget');
    
    closeButton.onmouseover = function() {
      this.style.background = 'rgba(0, 0, 0, 0.2)';
      this.style.transform = 'scale(1.1)';
    };
    closeButton.onmouseout = function() {
      this.style.background = 'rgba(0, 0, 0, 0.1)';
      this.style.transform = 'scale(1)';
    };
    
    closeButton.onclick = function() {
      TymeslotBooking.close();
    };
    
    modal.onclick = function(e) {
      if (e.target === modal) {
        TymeslotBooking.close();
      }
    };
    
    container.appendChild(closeButton);
    modal.appendChild(container);
    
    // Animate in
    setTimeout(() => {
      modal.style.opacity = '1';
      container.style.transform = 'scale(1)';
    }, 10);
    
    return { modal, container };
  }

  /**
   * Create floating button
   */
  function createFloatingButton(username, options = {}) {
    const button = document.createElement('button');
    button.id = 'tymeslot-floating-button';
    button.setAttribute('aria-label', 'Book a meeting');
    
    const buttonColor = options.buttonColor || '#14B8A6'; // turquoise-600
    
    button.style.cssText = `
      position: fixed;
      bottom: 24px;
      right: 24px;
      width: 64px;
      height: 64px;
      border-radius: 50%;
      background: ${buttonColor};
      color: white;
      border: none;
      cursor: pointer;
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.3);
      z-index: 999998;
      transition: all 0.3s ease;
      display: flex;
      align-items: center;
      justify-content: center;
    `;
    
    button.innerHTML = `
      <svg width="32" height="32" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
      </svg>
    `;
    
    button.onmouseover = function() {
      this.style.transform = 'scale(1.1)';
      this.style.boxShadow = '0 15px 35px rgba(0, 0, 0, 0.4)';
    };
    
    button.onmouseout = function() {
      this.style.transform = 'scale(1)';
      this.style.boxShadow = '0 10px 25px rgba(0, 0, 0, 0.3)';
    };
    
    button.onclick = function() {
      TymeslotBooking.open(username, options);
    };
    
    return button;
  }

  /**
   * Initialize inline embeds on page load
   */
  function initInlineEmbeds() {
    const containers = document.querySelectorAll('#tymeslot-booking, [data-tymeslot-inline]');
    
    containers.forEach(container => {
      const username = container.getAttribute('data-username') || 
                      container.getAttribute('data-tymeslot-inline');
      
      if (!username) {
        console.error('Tymeslot: No username provided for inline embed');
        return;
      }
      
      const options = {
        theme: container.getAttribute('data-theme'),
        primaryColor: container.getAttribute('data-primary-color'),
        locale: container.getAttribute('data-locale')
      };
      
      const iframe = createBookingIframe(username, options);
      container.innerHTML = '';
      container.appendChild(iframe);
    });
  }

  /**
   * Public API
   */
  window.TymeslotBooking = {
    /**
     * Display error in a container
     */
    showError: function(selectorOrElement) {
      let container = selectorOrElement;
      if (typeof selectorOrElement === 'string') {
        container = document.querySelector(selectorOrElement);
      }
      if (container) {
        showError(container);
      }
    },

    /**
     * Open booking in a modal
     */
    open: function(username, options = {}) {
      // Remove existing modal if any
      this.close();
      
      const { modal, container } = createModal();
      const wrapper = createBookingIframe(username, options);
      const iframe = wrapper.querySelector('iframe');
      
      if (iframe) {
        iframe.style.width = '100%';
        iframe.style.height = '100%';
        iframe.style.minHeight = '0';
        
        wrapper.style.height = '100%';
        wrapper.style.minHeight = '0';
        
        container.appendChild(wrapper);
      }
      
      document.body.appendChild(modal);
      document.body.style.overflow = 'hidden';
      
      // Handle escape key
      const escapeHandler = (e) => {
        if (e.key === 'Escape') {
          this.close();
        }
      };
      document.addEventListener('keydown', escapeHandler);
      modal.escapeHandler = escapeHandler;
    },
    
    /**
     * Close the modal
     */
    close: function() {
      const modal = document.getElementById('tymeslot-modal');
      if (modal) {
        const container = modal.querySelector('div');
        modal.style.opacity = '0';
        if (container) {
          container.style.transform = 'scale(0.95)';
        }
        
        setTimeout(() => {
          if (modal.escapeHandler) {
            document.removeEventListener('keydown', modal.escapeHandler);
          }
          modal.remove();
          document.body.style.overflow = '';
        }, 300);
      }
    },
    
    /**
     * Initialize floating button
     */
    initFloating: function(username, options = {}) {
      // Remove existing button if any
      const existing = document.getElementById('tymeslot-floating-button');
      if (existing) existing.remove();
      
      const button = createFloatingButton(username, options);
      document.body.appendChild(button);
    },
    
    /**
     * Programmatically embed inline
     */
    embed: function(selector, username, options = {}) {
      const container = document.querySelector(selector);
      if (!container) {
        console.error('Tymeslot: Container not found:', selector);
        return;
      }
      
      const iframe = createBookingIframe(username, options);
      container.innerHTML = '';
      container.appendChild(iframe);
    }
  };

  /**
   * Initialize when DOM is ready
   */
  const init = () => {
    try {
      initInlineEmbeds();
    } catch (e) {
      failSafe(e.message);
    }
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
