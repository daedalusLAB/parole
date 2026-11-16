"""Record the executable, source and settings used by a PAROLE run (stdlib only)."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest() if hasattr(hashlib, 'file_digest') else _digest(stream)


def _digest(stream):
    result = hashlib.sha256()
    for block in iter(lambda: stream.read(1024 * 1024), b''):
        result.update(block)
    return result.hexdigest()


def git(repo, *args):
    try:
        return subprocess.check_output(['git', '-C', str(repo), *args], stderr=subprocess.DEVNULL, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def stamp():
    return datetime.now(timezone.utc).isoformat()


def start(repo, praat, script, output):
    version = subprocess.check_output([str(praat), '--version'], stderr=subprocess.STDOUT, text=True).strip()
    commands = dict(re.findall(r'^\s*(To [^:\n]+):\s*([^\n]+)', script.read_text(), flags=re.MULTILINE))
    if 'To Pitch' not in commands:
        raise ValueError('Extraction script has no To Pitch command')
    dirty = git(repo, 'status', '--porcelain')
    return dict(schema_version=1, status='running', started_at_utc=stamp(),
                praat_version=version, praat_binary_sha256=digest(praat),
                parole_commit=git(repo, 'rev-parse', 'HEAD'),
                working_tree_dirty=None if dirty is None else bool(dirty),
                extraction_script_sha256=digest(script), praat_commands=commands,
                output_file=output.name)


def complete(report, script, output):
    if report['status'] != 'running':
        raise ValueError('Provenance was not initialized for this run')
    if digest(script) != report['extraction_script_sha256']:
        raise ValueError('Extraction script changed during processing')
    if not output.is_file() or output.stat().st_size == 0:
        raise ValueError('Result is missing or empty')
    return dict(report, status='complete', completed_at_utc=stamp(), output_sha256=digest(output))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=['start', 'complete'])
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--praat', type=Path, required=True)
    parser.add_argument('--script', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    path = args.output.with_name(args.output.name + '.provenance.json')
    if args.phase == 'start':
        report = start(args.repo, args.praat, args.script, args.output)
    else:
        report = complete(json.loads(path.read_text()), args.script, args.output)
    temporary = path.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
    os.replace(temporary, path)
    print(f"Provenance: {report['praat_version']}; commit={report['parole_commit']}; status={report['status']}")


if __name__ == '__main__':
    main()
