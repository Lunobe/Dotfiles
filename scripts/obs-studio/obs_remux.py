#!/usr/bin/env python3
"""
OBS MKV → MP4 Auto-Remuxer — script for OBS Studio (Linux)
===========================================================
When recording stops or replay buffer is saved, automatically
converts .mkv to .mp4 via ffmpeg (-c copy, no re-encoding)
and deletes the original .mkv.

Installation:
  1. Make sure ffmpeg is installed: ffmpeg -version
  2. In OBS: Tools → Scripts → [+] → select this file
"""

import obspython as obs
import subprocess
import threading
import logging
from pathlib import Path

# ─── Global variables (populated from OBS settings) ───────────────────────────
g_enabled: bool = True
g_output_dir: str = ""          # empty = same directory as source
g_log_path: str = str(Path.home() / ".obs_mkv_remuxer.log")

# ─── Logging ──────────────────────────────────────────────────────────────────
logger = logging.getLogger("obs_mkv_remuxer")
logger.setLevel(logging.DEBUG)

def _setup_logger():
    logger.handlers.clear()
    fh = logging.FileHandler(g_log_path, encoding="utf-8")
    fh.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(message)s",
                                      datefmt="%Y-%m-%d %H:%M:%S"))
    logger.addHandler(fh)

_setup_logger()

def log(msg: str):
    obs.script_log(obs.LOG_INFO, msg)
    logger.info(msg)

def log_warn(msg: str):
    obs.script_log(obs.LOG_WARNING, msg)
    logger.warning(msg)


# ─── Remux ────────────────────────────────────────────────────────────────────
def _remux_and_delete(mkv_path_str: str):
    """Runs in a separate thread for each file."""
    mkv = Path(mkv_path_str)

    if not mkv.exists():
        log_warn(f"File not found: {mkv}")
        return

    if mkv.suffix.lower() != ".mkv":
        log(f"File is not MKV ({mkv.suffix}) — skipping remux.")
        return

    # Determine where to save the MP4
    if g_output_dir:
        out_dir = Path(g_output_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        mp4 = out_dir / mkv.with_suffix(".mp4").name
    else:
        mp4 = mkv.with_suffix(".mp4")

    log(f"Starting remux: {mkv.name} → {mp4}")

    try:
        result = subprocess.run(
            ["ffmpeg", "-i", str(mkv), "-c", "copy", str(mp4)],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            log_warn(f"ffmpeg exited with an error:\n{result.stderr[-2000:]}")
            return
    except FileNotFoundError:
        log_warn("ffmpeg not found! Install it: sudo pacman -S ffmpeg  (or apt/dnf)")
        return
    except Exception as e:
        log_warn(f"Error running ffmpeg: {e}")
        return

    # Verify the MP4 was created successfully
    try:
        mp4_size = mp4.stat().st_size
    except FileNotFoundError:
        log_warn("MP4 did not appear after remux — keeping MKV.")
        return

    if mp4_size < 1024:
        log_warn(f"MP4 is suspiciously small ({mp4_size} bytes) — keeping MKV.")
        return

    mkv_size = mkv.stat().st_size
    try:
        mkv.unlink()
        freed = mkv_size / (1024 ** 2)
        log(f"✓ Done. Deleted {mkv.name} (freed {freed:.1f} MB)")
    except Exception as e:
        log_warn(f"Could not delete {mkv.name}: {e}")


def _start_remux_thread(path: str):
    if not g_enabled:
        log("Remux is disabled in settings — skipping.")
        return
    t = threading.Thread(target=_remux_and_delete, args=(path,), daemon=True)
    t.start()


# ─── OBS events ───────────────────────────────────────────────────────────────
def _on_event(event):
    if event == obs.OBS_FRONTEND_EVENT_RECORDING_STOPPED:
        path = obs.obs_frontend_get_last_recording()
        if path:
            log(f"Recording stopped: {path}")
            _start_remux_thread(path)

    elif event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED:
        path = obs.obs_frontend_get_last_replay()
        if path:
            log(f"Replay saved: {path}")
            _start_remux_thread(path)


# ─── OBS Script API ───────────────────────────────────────────────────────────

def script_description():
    return (
        "<b>OBS MKV → MP4 Auto-Remuxer</b><br>"
        "When recording stops or replay is saved, converts .mkv to .mp4 "
        "via <code>ffmpeg -c copy</code> (lossless) and deletes the original .mkv.<br>"
        "<small>Requires: <b>ffmpeg</b> in PATH</small>"
    )


def script_defaults(settings):
    obs.obs_data_set_default_bool(settings, "enabled", True)
    obs.obs_data_set_default_string(settings, "output_dir", "")


def script_properties():
    props = obs.obs_properties_create()

    obs.obs_properties_add_bool(props, "enabled", "Enable auto-remux MKV → MP4")

    obs.obs_properties_add_path(
        props, "output_dir",
        "Output folder for MP4 (empty = same as MKV)",
        obs.OBS_PATH_DIRECTORY, "", str(Path.home())
    )

    obs.obs_properties_add_text(
        props, "log_info",
        f"Log: {g_log_path}",
        obs.OBS_TEXT_INFO
    )

    return props


def script_update(settings):
    global g_enabled, g_output_dir

    g_enabled    = obs.obs_data_get_bool(settings, "enabled")
    g_output_dir = obs.obs_data_get_string(settings, "output_dir").strip()

    status = "enabled" if g_enabled else "disabled"
    dest   = g_output_dir if g_output_dir else "same directory as MKV"
    log(f"Auto-remux {status}. Output: {dest}")


def script_load(settings):
    obs.obs_frontend_add_event_callback(_on_event)
    log("OBS MKV → MP4 Auto-Remuxer loaded.")
    script_update(settings)


def script_unload():
    obs.obs_frontend_remove_event_callback(_on_event)
    log("OBS MKV → MP4 Auto-Remuxer unloaded.")
