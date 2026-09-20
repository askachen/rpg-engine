"""Explicit execution layers; every collected test belongs to exactly one layer."""
import pytest


def pytest_configure(config):
    for name in ('static', 'rules', 'ui', 'media', 'fast'):
        config.addinivalue_line('markers', f'{name}: Story Garden verification layer')


def pytest_collection_modifyitems(items):
    for item in items:
        name = item.nodeid.lower()
        if any(file in name for file in ('test_video.py', 'test_gallery.py', 'test_story_visual.py', 'test_settings.py')):
            layer = 'media'
        elif any(token in name for token in ('mouse', 'real_ui', 'playback_modes', 'custom_theme', 'test_isolation.py')):
            layer = 'ui'
        elif ('godot' in item.fixturenames or any(token in name for token in ('native', '_rules', 'test_cli.py', 'share_cli', 's6_runtime', 's6_scenarios', 's6_explore'))):
            layer = 'rules'
        else:
            layer = 'static'
        item.add_marker(getattr(pytest.mark, layer))
        if layer in ('static', 'rules'):
            item.add_marker(pytest.mark.fast)
