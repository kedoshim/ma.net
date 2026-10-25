from src.core.game_library import normalize_game, phone_game_url


def _game(**extra):
    return normalize_game({"name": "Some Game", "path": "C:/games/some.exe", **extra})


def test_the_button_shows_only_when_the_host_set_a_page():
    # A Jackbox name alone isn't enough: the host turns it on in the editor.
    assert phone_game_url(_game(name="The Jackbox Party Pack 7")) is None
    assert phone_game_url(_game(phoneUrl="https://jackbox.tv")) == "https://jackbox.tv"
    assert phone_game_url(None) is None


def test_a_set_page_wins_and_must_be_a_web_page():
    assert phone_game_url(_game(phoneUrl=" https://example.com/play ")) == "https://example.com/play"
    assert _game(phoneUrl="javascript:alert(1)")["phoneUrl"] == ""


def test_web_controller_files_are_revalidated():
    import asyncio
    from types import SimpleNamespace

    from src.routes.register_routes import revalidate_web_files

    def check(path, headers=None):
        response = SimpleNamespace(headers=dict(headers or {}))
        asyncio.run(revalidate_web_files(SimpleNamespace(path=path), response))
        return response.headers.get("Cache-Control")

    assert check("/main.dart.js") == "no-cache"
    assert check("/") == "no-cache"
    assert check("/api/games") is None
    assert check("/cover.png", {"Cache-Control": "max-age=300"}) == "max-age=300"
