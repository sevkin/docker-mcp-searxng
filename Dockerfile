# Extends the pinned upstream image and patches the settings template that the
# entrypoint copies to /etc/searxng/settings.yml on first start. Patching the
# template (instead of mounting a static settings file) keeps SearXNG's own
# startup logic, including generation of a random server.secret_key.
FROM searxng/searxng:2026.5.31-7159b8aed

# Engine availability varies over time and by network. This set was verified
# from this host on 2026-10-30; adjust the lists and rebuild if results dry up.
RUN /usr/local/searxng/.venv/bin/python - <<'PY'
import yaml

path = "/usr/local/searxng/searx/settings.yml"
with open(path, encoding="utf-8") as f:
    settings = yaml.safe_load(f)

# mcp-searxng consumes results as JSON.
settings["search"]["formats"] = ["html", "json"]

enable = {"bing", "seznam", "mwmbl", "wiby"}
disable = {"google", "brave", "duckduckgo", "startpage"}

for engine in settings.get("engines", []):
    name = engine.get("name")
    if name in enable:
        engine["disabled"] = False
    elif name in disable:
        engine["disabled"] = True

with open(path, "w", encoding="utf-8") as f:
    yaml.safe_dump(settings, f, sort_keys=False, allow_unicode=True)
PY
