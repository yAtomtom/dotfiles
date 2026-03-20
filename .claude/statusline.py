#!/usr/bin/env python3
"""Braille-dot statusline for Claude Code.

Segments: repo:branch, model, tokens/context, rate limits, duration, diff
Wraps to multiple lines based on terminal width.
"""
import json, sys, subprocess, os, re, shutil

data = json.load(sys.stdin)

# --- Constants ---
BRAILLE = ' ⣀⣄⣤⣦⣶⣷⣿'
R = '\033[0m'
DIM = '\033[2m'
GREEN = '\033[32m'
RED = '\033[31m'
SEP = f' {DIM}│{R} '
ANSI_RE = re.compile(r'\033\[[0-9;]*m')


# --- Pure functions ---

def visible_len(s):
    return len(ANSI_RE.sub('', s))


def wrap_segments(segments, width):
    """Group segments into lines that fit within terminal width."""
    sep_width = visible_len(SEP)
    lines = []
    current_line = []
    current_width = 0

    for seg in segments:
        seg_width = visible_len(seg)
        needed = seg_width + (sep_width if current_line else 0)
        if current_line and current_width + needed > width:
            lines.append(current_line)
            current_line = [seg]
            current_width = seg_width
        else:
            current_line.append(seg)
            current_width += needed

    if current_line:
        lines.append(current_line)
    return lines


def gradient(pct):
    if pct < 50:
        r = int(pct * 5.1)
        return f'\033[38;2;{r};200;80m'
    else:
        g = int(200 - (pct - 50) * 4)
        return f'\033[38;2;255;{max(g, 0)};60m'


def braille_bar(pct, width=8):
    pct = min(max(pct, 0), 100)
    level = pct / 100
    bar = ''
    for i in range(width):
        seg_start = i / width
        seg_end = (i + 1) / width
        if level >= seg_end:
            bar += BRAILLE[7]
        elif level <= seg_start:
            bar += BRAILLE[0]
        else:
            frac = (level - seg_start) / (seg_end - seg_start)
            bar += BRAILLE[min(int(frac * 7), 7)]
    return bar


def fmt_bar(label, pct):
    return f'{DIM}{label}{R} {gradient(pct)}{braille_bar(pct)}{R} {round(pct)}%'


def fmt_tokens(n):
    if n >= 1_000_000:
        return f'{n / 1_000_000:.1f}M'
    if n >= 1_000:
        return f'{n / 1_000:.0f}k'
    return str(n)


def fmt_duration(ms):
    s = ms / 1000
    if s < 60:
        return f'{int(s)}s'
    m = int(s // 60)
    if m < 60:
        return f'{m}m'
    h = m // 60
    rm = m % 60
    return f'{h}h{rm}m'


def parse_git_status(output):
    """Parse `git status --porcelain -b` output.

    Returns dict with branch, dirty, ahead, behind or None on parse failure.
    """
    lines = output.strip().split('\n')
    if not lines or not lines[0].startswith('## '):
        return None
    header = lines[0][3:]
    # detached HEAD: "HEAD (no branch)" or "HEAD (no branch)...something"
    detached = header.startswith('HEAD (no branch)') or header == 'HEAD'
    branch_part = header.split('...')[0]
    ahead, behind = 0, 0
    if not detached:
        m = re.search(r'\[ahead (\d+)', header)
        if m:
            ahead = int(m.group(1))
        m = re.search(r'behind (\d+)', header)
        if m:
            behind = int(m.group(1))
    dirty = len(lines) > 1
    return {'branch': branch_part, 'dirty': dirty, 'ahead': ahead, 'behind': behind,
            'detached': detached}


# --- Side-effect functions ---

def get_git_info(cwd):
    try:
        r = subprocess.run(
            ['git', 'status', '--porcelain', '-b', '--untracked-files=no'],
            capture_output=True, text=True, timeout=1, cwd=cwd
        )
        if r.returncode != 0:
            return None
        info = parse_git_status(r.stdout)
        if info and info['detached']:
            # Show short SHA instead of "HEAD (no branch)"
            sha = subprocess.run(
                ['git', 'rev-parse', '--short', 'HEAD'],
                capture_output=True, text=True, timeout=1, cwd=cwd
            )
            if sha.returncode == 0:
                info['branch'] = sha.stdout.strip()
        return info
    except Exception:
        return None


def get_terminal_width():
    try:
        return shutil.get_terminal_size().columns
    except Exception:
        return 120


# --- Build segments ---

parts = []

# 1. repo:branch
cwd = data.get('workspace', {}).get('current_dir') or data.get('cwd')
project_dir = data.get('workspace', {}).get('project_dir')
git = get_git_info(cwd) if cwd else None

if git and project_dir:
    repo = os.path.basename(project_dir)
    seg = f'{repo}:{git["branch"]}'
    if git['dirty']:
        seg += ' *'
    if git['ahead']:
        seg += f'\u2191{git["ahead"]}'
    if git['behind']:
        seg += f'\u2193{git["behind"]}'
    parts.append(seg)

# 2. model
parts.append(data.get('model', {}).get('display_name', 'Claude'))

# 3. tokens / context
ctx_win = data.get('context_window', {})
total_in = ctx_win.get('total_input_tokens')
total_out = ctx_win.get('total_output_tokens')
win_size = ctx_win.get('context_window_size')
used_pct = ctx_win.get('used_percentage')

if win_size:
    tok = fmt_tokens((total_in or 0) + (total_out or 0))
    cap = fmt_tokens(win_size)
    parts.append(f'{DIM}tok{R} {tok}/{cap} {fmt_bar("ctx", used_pct or 0)}')
elif used_pct is not None:
    parts.append(fmt_bar('ctx', used_pct))

# 4. rate limits
rl = data.get('rate_limits', {})
parts.append(fmt_bar('5h', rl.get('five_hour', {}).get('used_percentage') or 0))
parts.append(fmt_bar('7d', rl.get('seven_day', {}).get('used_percentage') or 0))

# 5. session duration (from stdin cost — no I/O)
cost = data.get('cost', {})
dur = cost.get('total_duration_ms')
if dur is not None:
    parts.append(f'{DIM}dur{R} {fmt_duration(dur)}')

# 6. diff stats (from stdin cost — no I/O, tracked session cumulative)
added = cost.get('total_lines_added')
removed = cost.get('total_lines_removed')
if added is not None or removed is not None:
    diff_parts = []
    if added and added > 0:
        diff_parts.append(f'{GREEN}+{added}{R}')
    if removed and removed > 0:
        diff_parts.append(f'{RED}-{removed}{R}')
    if diff_parts:
        parts.append(' '.join(diff_parts))

# --- Output with line wrapping ---

cols = get_terminal_width()
lines = wrap_segments(parts, cols)
output = '\n'.join(SEP.join(line) for line in lines)
print(output, end='')
