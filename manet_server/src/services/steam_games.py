"""
Recognizes games installed by Steam, so MaNet can start them the way Steam
expects.

Some Steam games refuse to run when their exe is opened directly (Killer
Queen Black says it can't verify the copy); others close and ask Steam to
start them again (Shipped). A game counts as Steam's only when its folder is
inside a library Steam knows about and a manifest names it: copies of
`steamapps` folders made outside Steam keep their manifests but are not in
Steam's library list, and are started like any other exe.
"""
import logging
import os
import re
from dataclasses import dataclass

LOG = logging.getLogger(__name__)

_URI = re.compile(r"^steam://(?:rungameid|run)/(\d+)", re.IGNORECASE)
_VDF_PATH = re.compile(r'"path"\s+"([^"]+)"')
_VDF_APPID = re.compile(r'"appid"\s+"(\d+)"')
_VDF_INSTALLDIR = re.compile(r'"installdir"\s+"([^"]+)"')


@dataclass(frozen=True)
class SteamApp:
    app_id: str
    folder: str  # where the game is installed; its processes run from here
    steam_exe: str


def _read(path: str) -> str:
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def _vdf_unescape(value: str) -> str:
    return value.replace("\\\\", "\\")


def steam_exe() -> str | None:
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as key:
            path = winreg.QueryValueEx(key, "SteamExe")[0]
    except OSError:
        return None
    path = os.path.normpath(path)
    return path if os.path.isfile(path) else None


def library_dirs(steam: str) -> list[str]:
    """The `steamapps` folders of every Steam library."""
    root = os.path.dirname(steam)
    found = [os.path.join(root, "steamapps")]
    vdf = _read(os.path.join(root, "steamapps", "libraryfolders.vdf"))
    for path in _VDF_PATH.findall(vdf):
        found.append(os.path.join(_vdf_unescape(path), "steamapps"))
    unique = {}
    for path in found:
        unique.setdefault(os.path.normcase(os.path.normpath(path)), os.path.normpath(path))
    return [p for p in unique.values() if os.path.isdir(p)]


def _manifests(steamapps: str):
    """(app_id, installdir) of each game installed in one library."""
    try:
        names = os.listdir(steamapps)
    except OSError:
        return
    for name in names:
        if not (name.startswith("appmanifest_") and name.endswith(".acf")):
            continue
        text = _read(os.path.join(steamapps, name))
        app_id, install_dir = _VDF_APPID.search(text), _VDF_INSTALLDIR.search(text)
        if app_id and install_dir:
            yield app_id.group(1), _vdf_unescape(install_dir.group(1))


def find_app(path: str, steam: str | None = None) -> SteamApp | None:
    """The Steam game a library entry points at: an exe inside a Steam
    library, or a steam://rungameid/<id> link. None for anything else."""
    steam = steam or steam_exe()
    if not steam or not path:
        return None
    uri = _URI.match(path.strip())
    exe = None if uri else os.path.normcase(os.path.abspath(path))
    for steamapps in library_dirs(steam):
        common = os.path.join(steamapps, "common")
        for app_id, install_dir in _manifests(steamapps):
            folder = os.path.join(common, install_dir)
            if uri:
                if app_id == uri.group(1):
                    return SteamApp(app_id, folder, steam)
            elif exe.startswith(os.path.normcase(folder) + os.sep):
                return SteamApp(app_id, folder, steam)
    return None
