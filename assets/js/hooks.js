// LiveView Hooks
import { PasswordToggle } from "./password_toggle";
import { AuthVideo, RhythmVideo, QuillVideo } from "./video_hooks";
import { ConfirmDelete, PageReload } from "./ui_interaction_hooks";
import { Flash, AutoScrollToSlots, AutoFocus, ScrollReset } from "./utility_hooks";
import { RecaptchaV3Hook } from "./hooks/recaptcha_v3_hook";
import { ClipboardCopy } from "./clipboard_hook";
import { AutoUpload } from "./hooks/auto_upload";
import { EmbedPreview } from "./hooks/embed_preview";

const Hooks = {};

// Password toggle hook for auth forms
Hooks.PasswordToggle = PasswordToggle;

// Video management hooks
Hooks.AuthVideo = AuthVideo;
Hooks.RhythmVideo = RhythmVideo;
Hooks.QuillVideo = QuillVideo;

// UI interaction hooks
Hooks.ConfirmDelete = ConfirmDelete;
Hooks.PageReload = PageReload;

// Utility hooks
Hooks.Flash = Flash;
Hooks.AutoScrollToSlots = AutoScrollToSlots;
Hooks.AutoFocus = AutoFocus;
Hooks.ScrollReset = ScrollReset;

// reCAPTCHA hook
Hooks.RecaptchaV3 = RecaptchaV3Hook;

// Clipboard hook
Hooks.ClipboardCopy = ClipboardCopy;

// Generic auto-upload hook for all file uploads
Hooks.AutoUpload = AutoUpload;

// Embed preview hook for dashboard
Hooks.EmbedPreview = EmbedPreview;

export default Hooks;