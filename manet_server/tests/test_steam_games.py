"""Steam games are recognized only inside libraries Steam knows about."""
import os

from src.services import steam_games


def make_library(root, app_id, install_dir):
    steamapps = root / "steamapps"
    (steamapps / "common" / install_dir).mkdir(parents=True)
    (steamapps / f"appmanifest_{app_id}.acf").write_text(
        f'"AppState"\n{{\n\t"appid"\t\t"{app_id}"\n\t"installdir"\t\t"{install_dir}"\n}}\n')
    return steamapps


def make_steam(tmp_path, extra_libraries=()):
    steam_root = tmp_path / "Steam"
    steamapps = make_library(steam_root, "663670", "Killer Queen Black")
    paths = [str(steam_root)] + [str(p) for p in extra_libraries]
    entries = "".join(f'\t"{i}"\n\t{{\n\t\t"path"\t\t"{p.replace(os.sep, os.sep * 2)}"\n\t}}\n'
                      for i, p in enumerate(paths))
    (steamapps / "libraryfolders.vdf").write_text(f'"libraryfolders"\n{{\n{entries}}}\n')
    steam = steam_root / "steam.exe"
    steam.write_text("")
    return str(steam), steamapps


def test_exe_in_steam_library(tmp_path):
    steam, steamapps = make_steam(tmp_path)
    exe = steamapps / "common" / "Killer Queen Black" / "Killer Queen Black.exe"
    app = steam_games.find_app(str(exe), steam)
    assert app.app_id == "663670"
    assert app.folder == str(steamapps / "common" / "Killer Queen Black")


def test_exe_in_a_subfolder_of_the_install(tmp_path):
    steam, steamapps = make_steam(tmp_path)
    exe = steamapps / "common" / "Killer Queen Black" / "bin" / "game.exe"
    assert steam_games.find_app(str(exe), steam).app_id == "663670"


def test_second_library_from_libraryfolders(tmp_path):
    other = tmp_path / "D" / "SteamLibrary"
    make_library(other, "1037190", "Shipped")
    steam, _ = make_steam(tmp_path, [other])
    exe = other / "steamapps" / "common" / "Shipped" / "Shipped.exe"
    assert steam_games.find_app(str(exe), steam).app_id == "1037190"


def test_copied_steamapps_folder_is_not_steam(tmp_path):
    # A game folder copied out of Steam keeps its manifest but isn't a library.
    steam, _ = make_steam(tmp_path)
    copy = make_library(tmp_path / "Games" / "Knight Squad 2", "1048660", "Knight Squad 2")
    exe = copy / "common" / "Knight Squad 2" / "KnightSquad2.exe"
    assert steam_games.find_app(str(exe), steam) is None


def test_steam_link(tmp_path):
    steam, steamapps = make_steam(tmp_path)
    app = steam_games.find_app("steam://rungameid/663670", steam)
    assert app.folder == str(steamapps / "common" / "Killer Queen Black")
    assert steam_games.find_app("steam://run/663670", steam).app_id == "663670"


def test_other_games_and_no_steam(tmp_path, monkeypatch):
    steam, steamapps = make_steam(tmp_path)
    assert steam_games.find_app(str(tmp_path / "Games" / "Nidhogg.exe"), steam) is None
    assert steam_games.find_app("steam://rungameid/999", steam) is None
    monkeypatch.setattr(steam_games, "steam_exe", lambda: None)
    exe = steamapps / "common" / "Killer Queen Black" / "Killer Queen Black.exe"
    assert steam_games.find_app(str(exe)) is None
