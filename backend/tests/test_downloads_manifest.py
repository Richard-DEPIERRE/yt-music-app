def test_manifest_request_defaults():
    from ytmusic_api.models.downloads import ManifestRequest

    req = ManifestRequest(videoIds=["a", "b"])
    assert req.codec == "aac"
    assert req.quality == "high"
    assert req.videoIds == ["a", "b"]
