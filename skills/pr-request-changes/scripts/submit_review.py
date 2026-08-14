#!/usr/bin/env python3
"""GitHub PR に REQUEST_CHANGES review を inline comments 付きで投稿する。

単発の inline comment (POST /pulls/{n}/comments) では PR の reviewDecision が
CHANGES_REQUESTED にならないため、必ず POST /pulls/{n}/reviews に束ねて送る。

使い方:
  python3 submit_review.py \\
    --repo owner/repo \\
    --pr 110 \\
    --commit-id <SHA> \\
    --body-file /tmp/rc-body.md \\
    --comments-file /tmp/rc-comments.json \\
    [--event REQUEST_CHANGES]

comments-file の JSON 形式:
  [
    {"path": "src/foo.ts", "line": 42, "side": "RIGHT", "body": "..."},
    ...
  ]

成功時、review の id / state / html_url を stdout に出力。失敗時は非 0 終了。
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--repo", required=True, help="owner/repo (例: octocat/hello-world)")
    p.add_argument("--pr", required=True, type=int, help="PR 番号")
    p.add_argument("--commit-id", required=True, help="PR HEAD SHA")
    p.add_argument("--body-file", required=True, help="overall body の markdown ファイル path")
    p.add_argument("--comments-file", required=True, help="inline comments の JSON 配列ファイル path")
    p.add_argument(
        "--event",
        default="REQUEST_CHANGES",
        choices=["REQUEST_CHANGES", "COMMENT", "APPROVE"],
        help="review event。本 skill では REQUEST_CHANGES が default",
    )
    args = p.parse_args()

    body_path = Path(args.body_file)
    comments_path = Path(args.comments_file)
    if not body_path.is_file():
        print(f"ERR: body-file not found: {body_path}", file=sys.stderr)
        return 2
    if not comments_path.is_file():
        print(f"ERR: comments-file not found: {comments_path}", file=sys.stderr)
        return 2

    body = body_path.read_text(encoding="utf-8")
    try:
        comments = json.loads(comments_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"ERR: comments-file is not valid JSON: {e}", file=sys.stderr)
        return 2
    if not isinstance(comments, list):
        print("ERR: comments-file must be a JSON array", file=sys.stderr)
        return 2

    # 各 comment の最小バリデーション
    for i, c in enumerate(comments):
        if not isinstance(c, dict):
            print(f"ERR: comments[{i}] is not an object", file=sys.stderr)
            return 2
        for k in ("path", "line", "body"):
            if k not in c:
                print(f"ERR: comments[{i}] missing required key: {k}", file=sys.stderr)
                return 2
        if not isinstance(c["line"], int):
            print(f"ERR: comments[{i}].line must be integer (file 内絶対行)", file=sys.stderr)
            return 2
        c.setdefault("side", "RIGHT")

    payload = {
        "commit_id": args.commit_id,
        "event": args.event,
        "body": body,
        "comments": comments,
    }

    # gh api --input は stdin で JSON を受ける
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False)
        tmp_path = f.name

    cmd = [
        "gh",
        "api",
        "-X",
        "POST",
        f"repos/{args.repo}/pulls/{args.pr}/reviews",
        "--input",
        tmp_path,
        "--jq",
        '{id, state, html_url, submitted_at}',
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    finally:
        Path(tmp_path).unlink(missing_ok=True)

    if result.returncode != 0:
        print(f"ERR: gh api failed (exit {result.returncode})", file=sys.stderr)
        print(result.stderr, file=sys.stderr)
        return result.returncode

    print(result.stdout.strip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
