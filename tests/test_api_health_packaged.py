"""Flutter sidecar health + packaged env install guards."""
from __future__ import annotations

import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def client(monkeypatch, tmp_path):
    monkeypatch.setenv("EASEL_PACKAGED", "1")
    monkeypatch.setenv("EASEL_MODELS_DIR", str(tmp_path / "models"))
    monkeypatch.setenv("EASEL_VENDOR_ROOT", str(tmp_path / "vendor"))
    (tmp_path / "vendor").mkdir()
    import web.app as web

    web._ENV_TOOLS_CACHE.update({"ts": 0.0, "data": None})
    with TestClient(web.app, base_url="http://127.0.0.1:7860",
                    client=("127.0.0.1", 51234)) as c:
        yield c, web


def test_api_health_reports_packaged(client):
    c, _ = client
    resp = c.get("/api/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body["ok"] is True
    assert body["packaged"] is True
    assert body["modelsDir"].endswith("models")
    assert body["whisperModel"].endswith("whisper-large-v3")


def test_packaged_install_blocks_ffmpeg(client):
    c, web = client
    # Bypass recipe-id probe cache with known ids
    web._INSTALL_IDS_CACHE.update({"ts": 1e18, "ids": frozenset({"ffmpeg", "model"})})
    resp = c.post("/api/env/install", json={"id": "ffmpeg"})
    assert resp.status_code == 409
    assert "内置" in resp.json()["detail"]
