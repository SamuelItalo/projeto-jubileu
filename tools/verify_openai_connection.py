#!/usr/bin/env python3
"""Verifica a autenticação com a OpenAI sem expor a chave de API."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path


def read_env_value(env_file: Path, name: str) -> str | None:
    """Lê uma variável simples de um arquivo .env, sem imprimir seu valor."""
    if not env_file.is_file():
        return None

    for raw_line in env_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        variable, value = line.split("=", 1)
        if variable.strip() == name:
            return value.strip().strip('"').strip("'") or None
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--env-file",
        type=Path,
        default=Path(".env"),
        help="arquivo de ambiente a usar caso OPENAI_API_KEY não esteja no ambiente",
    )
    args = parser.parse_args()

    api_key = os.getenv("OPENAI_API_KEY") or read_env_value(args.env_file, "OPENAI_API_KEY")
    if not api_key:
        print("FALHA: OPENAI_API_KEY está ausente ou vazia.", file=sys.stderr)
        return 1

    request = urllib.request.Request(
        "https://api.openai.com/v1/models",
        headers={"Authorization": f"Bearer {api_key}"},
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        print(f"FALHA: a API respondeu HTTP {error.code}.", file=sys.stderr)
        return 1
    except urllib.error.URLError as error:
        print(f"FALHA: não foi possível alcançar a API ({error.reason}).", file=sys.stderr)
        return 1

    print(
        "CONECTADO: autenticação aceita "
        f"(HTTP {response.status}; {len(payload.get('data', []))} modelos acessíveis)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
