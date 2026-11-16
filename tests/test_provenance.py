"""Check provenance without requiring Praat or media."""
import importlib.util
from pathlib import Path
import pytest

spec = importlib.util.spec_from_file_location('provenance', Path(__file__).resolve().parents[1]/'scripts/write_provenance.py')
provenance = importlib.util.module_from_spec(spec)
spec.loader.exec_module(provenance)


def test_records_actual_version_and_script_settings(tmp_path, monkeypatch):
    script = tmp_path/'extract.praat'
    script.write_text('To Pitch: 0.001, 60, 600\nTo Intensity: 75, 0.001, "yes"\n')
    binary = tmp_path/'praat'
    binary.write_bytes(b'fake executable')
    output = tmp_path/'result.csv'
    monkeypatch.setattr(provenance.subprocess, 'check_output', lambda *a, **k: 'Praat 6.4.60\n')
    monkeypatch.setattr(provenance, 'git', lambda repo, *args: 'abc123' if args[0]=='rev-parse' else '')
    report = provenance.start(tmp_path, binary, script, output)
    assert report['status']=='running'
    assert report['praat_version']=='Praat 6.4.60'
    assert report['praat_commands']['To Pitch']=='0.001, 60, 600'
    assert report['parole_commit']=='abc123' and report['working_tree_dirty'] is False
    with pytest.raises(ValueError, match='missing or empty'):
        provenance.complete(report, script, output)
    output.write_text('pitch\n220\n')
    done = provenance.complete(report, script, output)
    assert done['status']=='complete' and done['output_sha256']==provenance.digest(output)
    script.write_text('To Pitch: 0.01, 75, 500\n')
    with pytest.raises(ValueError, match='changed during processing'):
        provenance.complete(report, script, output)


def test_git_unavailable_is_explicit(tmp_path):
    assert provenance.git(tmp_path, 'rev-parse', 'HEAD') is None
