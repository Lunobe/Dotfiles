#!/usr/bin/env python3
"""
OBS MKV → MP4 Auto-Remuxer — скрипт для OBS Studio (Linux)
===========================================================
При остановке записи или сохранении реплей-буфера автоматически
конвертирует .mkv в .mp4 через ffmpeg (-c copy, без перекодировки)
и удаляет исходный .mkv.

Установка:
  1. Убедитесь что ffmpeg установлен: ffmpeg -version
  2. В OBS: Инструменты → Скрипты → [+] → выбрать этот файл
"""

import obspython as obs
import subprocess
import threading
import logging
from pathlib import Path

# ─── Глобальные переменные (заполняются из настроек OBS) ──────────────────────
g_enabled: bool = True
g_output_dir: str = ""          # пусто = рядом с исходником
g_log_path: str = str(Path.home() / ".obs_mkv_remuxer.log")

# ─── Логирование ──────────────────────────────────────────────────────────────
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


# ─── Ремукс ───────────────────────────────────────────────────────────────────
def _remux_and_delete(mkv_path_str: str):
    """Запускается в отдельном потоке для каждого файла."""
    mkv = Path(mkv_path_str)

    if not mkv.exists():
        log_warn(f"Файл не найден: {mkv}")
        return

    if mkv.suffix.lower() != ".mkv":
        log(f"Файл не MKV ({mkv.suffix}) — пропускаем ремукс.")
        return

    # Определяем куда сохранить MP4
    if g_output_dir:
        out_dir = Path(g_output_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        mp4 = out_dir / mkv.with_suffix(".mp4").name
    else:
        mp4 = mkv.with_suffix(".mp4")

    log(f"Начинаю ремукс: {mkv.name} → {mp4}")

    try:
        result = subprocess.run(
            ["ffmpeg", "-i", str(mkv), "-c", "copy", str(mp4)],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            log_warn(f"ffmpeg завершился с ошибкой:\n{result.stderr[-2000:]}")
            return
    except FileNotFoundError:
        log_warn("ffmpeg не найден! Установите: sudo pacman -S ffmpeg  (или apt/dnf)")
        return
    except Exception as e:
        log_warn(f"Ошибка при запуске ffmpeg: {e}")
        return

    # Проверяем что MP4 получился нормальным
    try:
        mp4_size = mp4.stat().st_size
    except FileNotFoundError:
        log_warn("MP4 не появился после ремукса — MKV не удаляем.")
        return

    if mp4_size < 1024:
        log_warn(f"MP4 подозрительно мал ({mp4_size} байт) — MKV не удаляем.")
        return

    mkv_size = mkv.stat().st_size
    try:
        mkv.unlink()
        freed = mkv_size / (1024 ** 2)
        log(f"✓ Готово. Удалён {mkv.name} (освобождено {freed:.1f} МБ)")
    except Exception as e:
        log_warn(f"Не удалось удалить {mkv.name}: {e}")


def _start_remux_thread(path: str):
    if not g_enabled:
        log("Ремукс отключён в настройках — пропускаем.")
        return
    t = threading.Thread(target=_remux_and_delete, args=(path,), daemon=True)
    t.start()


# ─── OBS события ──────────────────────────────────────────────────────────────
def _on_event(event):
    if event == obs.OBS_FRONTEND_EVENT_RECORDING_STOPPED:
        path = obs.obs_frontend_get_last_recording()
        if path:
            log(f"Запись остановлена: {path}")
            _start_remux_thread(path)

    elif event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED:
        path = obs.obs_frontend_get_last_replay()
        if path:
            log(f"Реплей сохранён: {path}")
            _start_remux_thread(path)


# ─── OBS Script API ───────────────────────────────────────────────────────────

def script_description():
    return (
        "<b>OBS MKV → MP4 Auto-Remuxer</b><br>"
        "При остановке записи или сохранении реплея конвертирует .mkv в .mp4 "
        "через <code>ffmpeg -c copy</code> (без потери качества) и удаляет исходный .mkv.<br>"
        "<small>Требует: <b>ffmpeg</b> в PATH</small>"
    )


def script_defaults(settings):
    obs.obs_data_set_default_bool(settings, "enabled", True)
    obs.obs_data_set_default_string(settings, "output_dir", "")


def script_properties():
    props = obs.obs_properties_create()

    obs.obs_properties_add_bool(props, "enabled", "Включить авто-ремукс MKV → MP4")

    obs.obs_properties_add_path(
        props, "output_dir",
        "Папка для сохранения MP4 (пусто = рядом с MKV)",
        obs.OBS_PATH_DIRECTORY, "", str(Path.home())
    )

    obs.obs_properties_add_text(
        props, "log_info",
        f"Лог: {g_log_path}",
        obs.OBS_TEXT_INFO
    )

    return props


def script_update(settings):
    global g_enabled, g_output_dir

    g_enabled    = obs.obs_data_get_bool(settings, "enabled")
    g_output_dir = obs.obs_data_get_string(settings, "output_dir").strip()

    status = "включён" if g_enabled else "отключён"
    dest   = g_output_dir if g_output_dir else "рядом с MKV"
    log(f"Авто-ремукс {status}. Вывод: {dest}")


def script_load(settings):
    obs.obs_frontend_add_event_callback(_on_event)
    log("OBS MKV → MP4 Auto-Remuxer загружен.")
    script_update(settings)


def script_unload():
    obs.obs_frontend_remove_event_callback(_on_event)
    log("OBS MKV → MP4 Auto-Remuxer выгружен.")
