"""Bounded CI checks; GPU timing and full acceptance matrix are explicit tool runs."""
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from platform_check import run


def test_platform_matrix_mouse():
    _,report=run('matrix',headless=True,quick=True)
    assert len(report['cases'])==8
    assert all(case['ok'] for case in report['cases'])
    assert not report['performance_verified']


def test_platform_native_resource_lifecycle():
    _,report=run('stress',headless=True,cycles=10)
    assert report['fixture']['extra_events']==1000
    assert report['final']['nodes']==report['baseline']['nodes']
    assert report['final']['orphans']==report['baseline']['orphans']
    assert not report['performance_verified']
