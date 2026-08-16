#!/usr/bin/env python3
"""
Per-locale Radio Install ZIP builder for Rotorflight EdgeTX Suite.
Used in GitHub Actions CI (pr/push/release/snapshot workflows) and local
packaging via package.cmd / package.sh.
"""

import argparse
import os
import sys
import shutil
import zipfile
import tempfile
import re
import subprocess

WORKSPACE_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def get_suite_version():
    ver_file = os.path.join(WORKSPACE_ROOT, "src", "rfsuite", "lib", "version.lua")
    if os.path.isfile(ver_file):
        with open(ver_file, "r", encoding="utf-8") as f:
            content = f.read()
        m_maj = re.search(r"M\.MAJOR\s*=\s*(\d+)", content)
        m_min = re.search(r"M\.MINOR\s*=\s*(\d+)", content)
        m_pat = re.search(r"M\.PATCH\s*=\s*(\d+)", content)
        if m_maj and m_min and m_pat:
            return f"{m_maj.group(1)}.{m_min.group(1)}.{m_pat.group(1)}"
    return "0.1.0"


def get_available_languages():
    i18n_dir = os.path.join(WORKSPACE_ROOT, "src", "rfsuite", "i18n")
    langs = []
    if os.path.isdir(i18n_dir):
        for f in os.listdir(i18n_dir):
            if f.endswith(".lua") and f != "init.lua":
                langs.append(f[:-4])
    return langs if langs else ["en"]


def get_theme_metadata(theme_dir, source_name):
    init_file = os.path.join(theme_dir, "init.lua")
    if not os.path.isfile(init_file):
        return None
    with open(init_file, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
    name_m = re.search(r'name\s*=\s*"([^"]+)"', content)
    if not name_m:
        return None
    config_m = re.search(r'configure\s*=\s*"([^"]+)"', content)
    stand_m = re.search(r"standalone\s*=\s*(true|false)", content)
    return {
        "name": name_m.group(1),
        "source": source_name,
        "folder": os.path.basename(theme_dir),
        "configure": config_m.group(1) if config_m else None,
        "standalone": stand_m.group(1) == "true" if stand_m else False
    }


def generate_theme_index(target_core_dir, target_user_dir):
    entries = []
    sys_themes = os.path.join(target_core_dir, "widgets", "dashboard", "themes")
    if os.path.isdir(sys_themes):
        for d in os.listdir(sys_themes):
            full_d = os.path.join(sys_themes, d)
            if os.path.isdir(full_d):
                meta = get_theme_metadata(full_d, "system")
                if meta:
                    entries.append(meta)

    user_themes = os.path.join(target_user_dir, "dashboard")
    if os.path.isdir(user_themes):
        for d in os.listdir(user_themes):
            full_d = os.path.join(user_themes, d)
            if os.path.isdir(full_d):
                meta = get_theme_metadata(full_d, "user")
                if meta:
                    entries.append(meta)

    out_file = os.path.join(target_core_dir, "app", "pages", "settings", "dashboard", "theme_index.lua")
    os.makedirs(os.path.dirname(out_file), exist_ok=True)
    lines = ["return {"]
    for e in entries:
        safe_name = e["name"].replace("\\", "\\\\").replace('"', '\\"')
        safe_folder = e["folder"].replace("\\", "\\\\").replace('"', '\\"')
        cfg_val = f'"{e["configure"]}"' if e["configure"] else "nil"
        stand_val = "true" if e["standalone"] else "false"
        lines.append(f'  {{ name = "{safe_name}", source = "{e["source"]}", folder = "{safe_folder}", configure = {cfg_val}, standalone = {stand_val} }},')
    lines.append("}\n")
    with open(out_file, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def copy_audio_pack(lang, src_audio, dst_audio):
    src_pack = os.path.join(src_audio, lang, "default")
    if not os.path.isdir(src_pack):
        src_pack = os.path.join(src_audio, lang)
    if not os.path.isdir(src_pack):
        return
    for sub in ["adj", "app", "evt", "stat", "gov"]:
        src_sub = os.path.join(src_pack, sub)
        if os.path.isdir(src_sub):
            dst_sub = os.path.join(dst_audio, sub)
            shutil.copytree(src_sub, dst_sub, dirs_exist_ok=True)


def build_package_for_language(lang, version, output_dir, artifact_name=None):
    temp_dir = tempfile.mkdtemp(prefix="rfsuite_build_")
    try:
        src_root = os.path.join(WORKSPACE_ROOT, "src")
        src_core = os.path.join(src_root, "rfsuite")
        src_widgets = os.path.join(src_root, "widgets", "rfsuite")
        src_user = os.path.join(src_root, "rfsuite.user")
        src_audio = os.path.join(src_core, "audio")

        staging_tools = os.path.join(temp_dir, "SCRIPTS", "TOOLS")
        staging_core = os.path.join(staging_tools, "rfsuite-core")
        staging_widgets = os.path.join(temp_dir, "WIDGETS", "rfsuite")
        staging_sounds = os.path.join(temp_dir, "SOUNDS", "rf")
        staging_user = os.path.join(staging_tools, "rfsuite.user")

        os.makedirs(staging_core, exist_ok=True)
        os.makedirs(staging_widgets, exist_ok=True)
        os.makedirs(staging_sounds, exist_ok=True)
        os.makedirs(staging_user, exist_ok=True)

        # Copy core files excluding audio and i18n
        for item in os.listdir(src_core):
            if item in ["audio", "i18n"]:
                continue
            s = os.path.join(src_core, item)
            d = os.path.join(staging_core, item)
            if os.path.isdir(s):
                shutil.copytree(s, d, dirs_exist_ok=True)
            else:
                shutil.copy2(s, d)

        # Copy init.lua for i18n
        os.makedirs(os.path.join(staging_core, "i18n"), exist_ok=True)
        shutil.copy2(os.path.join(src_core, "i18n", "init.lua"), os.path.join(staging_core, "i18n", "init.lua"))

        # Copy tool entrypoint
        shutil.copy2(os.path.join(src_root, "main.lua"), os.path.join(staging_tools, "rfsuite.lua"))

        # Copy user default config
        if os.path.isdir(src_user):
            shutil.copytree(src_user, staging_user, dirs_exist_ok=True)

        # Copy widgets
        if os.path.isdir(src_widgets):
            shutil.copytree(src_widgets, staging_widgets, dirs_exist_ok=True)

        # Copy sounds
        if os.path.isdir(src_audio):
            copy_audio_pack("en", src_audio, os.path.join(staging_sounds, "en"))
            copy_audio_pack("de", src_audio, os.path.join(staging_sounds, "de"))
            for wav in ["beep.wav", "multibeep.wav", "warn.wav", "alarm.wav"]:
                w_path = os.path.join(src_audio, wav)
                if os.path.isfile(w_path):
                    shutil.copy2(w_path, staging_sounds)

        # Generate theme index
        generate_theme_index(staging_core, staging_user)

        # Precompile and resolve i18n
        py_precompile = os.path.join(WORKSPACE_ROOT, ".vscode", "scripts", "precompile_i18n.py")
        py_resolve = os.path.join(WORKSPACE_ROOT, ".vscode", "scripts", "resolve_i18n_tags.py")
        lang_file = os.path.join(src_core, "i18n", f"{lang}.lua")

        if os.path.isfile(py_precompile) and os.path.isfile(py_resolve) and os.path.isfile(lang_file):
            subprocess.run([sys.executable, py_precompile, "--root", staging_tools], check=True)
            subprocess.run([sys.executable, py_precompile, "--root", staging_widgets], check=True)
            subprocess.run([sys.executable, py_resolve, "--json", lang_file, "--root", staging_tools], check=True)
            subprocess.run([sys.executable, py_resolve, "--json", lang_file, "--root", staging_widgets], check=True)

        # Create output ZIP
        os.makedirs(output_dir, exist_ok=True)
        zip_filename = artifact_name or f"rfsuite-radio-install-v{version}_{lang}.zip"
        zip_path = os.path.join(output_dir, zip_filename)
        if os.path.isfile(zip_path):
            os.remove(zip_path)

        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for root, _, files in os.walk(temp_dir):
                for f in files:
                    if f.endswith(".luac"):
                        continue
                    full_p = os.path.join(root, f)
                    rel_p = os.path.relpath(full_p, temp_dir)
                    zf.write(full_p, rel_p)

        print(f"[package] Created {zip_path}")
        return zip_path

    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


def parse_args():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--lang", required=True, help="Locale to package (e.g. en, de)")
    p.add_argument("--artifact-version", default=None, help="Version string baked into the default zip filename (defaults to version.lua)")
    p.add_argument("--artifact-name", default=None, help="Output zip filename (defaults to rfsuite-radio-install-v<version>_<lang>.zip)")
    p.add_argument("--output-dir", default="dist", help="Directory to write the finished zip into (default: dist)")
    return p.parse_args()


def main():
    args = parse_args()
    lang = args.lang
    version = args.artifact_version or get_suite_version()
    output_dir = os.path.abspath(args.output_dir)

    available = get_available_languages()
    if lang not in available:
        print(f"[package] WARNING: '{lang}' not found under src/rfsuite/i18n (available: {', '.join(available)}); continuing anyway.")

    print(f"Building RFSuite Radio ZIP package for version v{version}, locale '{lang}'")
    build_package_for_language(lang, version, output_dir, artifact_name=args.artifact_name)


if __name__ == "__main__":
    main()
